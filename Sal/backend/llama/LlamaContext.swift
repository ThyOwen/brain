//
//  LlamaContext.swift
//  Brain
//
//  Created by Owen O'Malley on 6/19/24.
//

import Foundation
import llama

enum LlamaError : Error {
    case contextError, modelError, fileSystemError, failToEvaulate, decodeError
}

public final actor LlamaContext {
    public var model: OpaquePointer
    public var context: OpaquePointer
    private var batch: llama_batch
    private var tokensList: [llama_token] = []

    /// This variable is used to store temporarily invalid cchars
    private var temporaryInvalidCChars: [CChar] = []
    
    var numLen: Int32 = 1024
    var numCur: Int32 = 0
    public var isDone : Bool = false

    var numDecode: Int32 = 0
    
    public init(with modelPath: borrowing String) throws {
        llama_backend_init()
        let model_params = llama_model_default_params()
        
        let model = llama_load_model_from_file(modelPath, model_params)
        
        guard let model else {
            throw LlamaError.modelError
        }
        
        let n_threads = max(1, min(8, ProcessInfo.processInfo.processorCount - 2))

        var ctx_params = llama_context_default_params()
        ctx_params.seed  = 1234
        ctx_params.n_ctx = 2048
        ctx_params.n_threads       = UInt32(n_threads)
        ctx_params.n_threads_batch = UInt32(n_threads)
        ctx_params.flash_attn = true 

        let context = llama_new_context_with_model(model, ctx_params)
        guard let context else {
            throw LlamaError.contextError
        }
        
        self.context = context
        self.model = model
        self.batch = llama_batch_init(512, 0, 1)
    }
    
    deinit {
        llama_batch_free(batch)
        llama_free(context)
        llama_free_model(model)
        llama_backend_free()
    }

    public func modelInfo() -> String {
        let result = UnsafeMutablePointer<Int8>.allocate(capacity: 256)
        result.initialize(repeating: Int8(0), count: 256)
        defer {
            result.deallocate()
        }

        // TODO: this is probably very stupid way to get the string from C

        let nChars = llama_model_desc(model, result, 256)
        let bufferPointer = UnsafeBufferPointer(start: result, count: Int(nChars))

        return String(cString: bufferPointer.baseAddress!)
        
        /*
        var SwiftString = ""
        for char in bufferPointer {
            SwiftString.append(Character(UnicodeScalar(UInt8(char))))
        }

        return SwiftString
        */
    }

    public func getNumTokens() -> Int32 {
        return batch.n_tokens
    }

    func completionInit(text: borrowing String) throws {

        self.isDone = false
        
        tokensList = tokenize(text: text, add_bos: true)
        temporaryInvalidCChars = []

        let n_ctx = llama_n_ctx(context)
        let n_kv_req = tokensList.count + (Int(numLen) - tokensList.count)

        print("\n numLen = \(numLen), n_ctx = \(n_ctx), n_kv_req = \(n_kv_req)")

        if n_kv_req > n_ctx {
            print("error: n_kv_req > n_ctx, the required KV cache size is not big enough")
        }

        Self.llamaBatchClear(&batch)

        for i1 in 0..<tokensList.count {
            let i = Int(i1)
            Self.llamaBatchAdd(batch: &batch,
                               id: tokensList[i],
                               pos: Int32(i),
                               seqIDs: [0],
                               logits: false)
        }
        batch.logits[Int(batch.n_tokens) - 1] = 1 // true

        guard llama_decode(context, batch) == 0 else {
            throw LlamaError.decodeError
        }

        self.numCur = batch.n_tokens
    }

    func completionLoop() throws -> (String, Int32) {
        var new_token_id: llama_token = 0

        let n_vocab = llama_n_vocab(model)
        let logits = llama_get_logits_ith(context, batch.n_tokens - 1)

        var candidates = Array<llama_token_data>()
        candidates.reserveCapacity(Int(n_vocab))

        for token_id in 0..<n_vocab {
            candidates.append(llama_token_data(id: token_id, logit: logits![Int(token_id)], p: 0.0))
        }
        candidates.withUnsafeMutableBufferPointer { buffer in
            var candidates_p = llama_token_data_array(data: buffer.baseAddress, size: buffer.count, sorted: false)

            new_token_id = llama_sample_token(context, &candidates_p)
        }

        if llama_token_is_eog(model, new_token_id) || numCur == numLen {
            print("\n")
            self.isDone = true
            let new_token_str = String(cString: temporaryInvalidCChars + [0])
            temporaryInvalidCChars.removeAll()
            return (new_token_str, new_token_id)
        }

        let new_token_cchars = tokenToPiece(token: new_token_id)
        temporaryInvalidCChars.append(contentsOf: new_token_cchars)
        let new_token_str: String
        if let string = String(validatingUTF8: temporaryInvalidCChars + [0]) {
            temporaryInvalidCChars.removeAll()
            new_token_str = string
        } else if (0 ..< temporaryInvalidCChars.count).contains(where: {$0 != 0 && String(validatingUTF8: Array(temporaryInvalidCChars.suffix($0)) + [0]) != nil}) {
            // in this case, at least the suffix of the temporaryInvalidCChars can be interpreted as UTF8 string
            let string = String(cString: temporaryInvalidCChars + [0])
            temporaryInvalidCChars.removeAll()
            new_token_str = string
        } else {
            new_token_str = ""
        }
        //print(new_token_str)
        // tokensList.append(new_token_id)

        Self.llamaBatchClear(&batch)
        Self.llamaBatchAdd(batch: &batch, id: new_token_id, pos: numCur, seqIDs: [0], logits: true)

        numDecode += 1
        numCur    += 1

        if llama_decode(context, batch) != 0 {
            throw LlamaError.failToEvaulate
        }

        return (new_token_str, new_token_id)
    }
    
    @discardableResult
    func bench(pp: Int, tg: Int, pl: Int, nr: Int = 1) -> String {
        var pp_avg: Double = 0
        var tg_avg: Double = 0

        var pp_std: Double = 0
        var tg_std: Double = 0

        for _ in 0..<nr {
            // bench prompt processing

            Self.llamaBatchClear(&batch)

            let n_tokens = pp

            for i in 0..<n_tokens {
                Self.llamaBatchAdd(batch: &batch, id: 0, pos: Int32(i), seqIDs: [0], logits: false)
            }
            batch.logits[Int(batch.n_tokens) - 1] = 1 // true

            llama_kv_cache_clear(context)

            let t_pp_start = ggml_time_us()

            if llama_decode(context, batch) != 0 {
                print("llama_decode() failed during prompt")
            }
            llama_synchronize(context)

            let t_pp_end = ggml_time_us()

            // bench text generation

            llama_kv_cache_clear(context)

            let t_tg_start = ggml_time_us()

            for i in 0..<tg {
                Self.llamaBatchClear(&batch)

                for j in 0..<pl {
                    Self.llamaBatchAdd(batch: &batch, id: 0, pos: Int32(i), seqIDs: [Int32(j)], logits: true)
                }

                if llama_decode(context, batch) != 0 {
                    print("llama_decode() failed during text generation")
                }
                llama_synchronize(context)
            }

            let t_tg_end = ggml_time_us()

            llama_kv_cache_clear(context)

            let t_pp = Double(t_pp_end - t_pp_start) / 1000000.0
            let t_tg = Double(t_tg_end - t_tg_start) / 1000000.0

            let speed_pp = Double(pp)    / t_pp
            let speed_tg = Double(pl*tg) / t_tg

            pp_avg += speed_pp
            tg_avg += speed_tg

            pp_std += speed_pp * speed_pp
            tg_std += speed_tg * speed_tg

            //print("pp \(speed_pp) t/s, tg \(speed_tg) t/s")
        }

        pp_avg /= Double(nr)
        tg_avg /= Double(nr)

        if nr > 1 {
            pp_std = sqrt(pp_std / Double(nr - 1) - pp_avg * pp_avg * Double(nr) / Double(nr - 1))
            tg_std = sqrt(tg_std / Double(nr - 1) - tg_avg * tg_avg * Double(nr) / Double(nr - 1))
        } else {
            pp_std = 0
            tg_std = 0
        }

        let model_desc     = self.modelInfo();
        let model_size     = String(format: "%.2f GiB", Double(llama_model_size(model)) / 1024.0 / 1024.0 / 1024.0);
        let model_n_params = String(format: "%.2f B", Double(llama_model_n_params(model)) / 1e9);
        let backend        = "Metal";
        let pp_avg_str     = String(format: "%.2f", pp_avg);
        let tg_avg_str     = String(format: "%.2f", tg_avg);
        let pp_std_str     = String(format: "%.2f", pp_std);
        let tg_std_str     = String(format: "%.2f", tg_std);

        var result = ""

        result += String("| model | size | params | backend | test | t/s |\n")
        result += String("| --- | --- | --- | --- | --- | --- |\n")
        result += String("| \(model_desc) | \(model_size) | \(model_n_params) | \(backend) | pp \(pp) | \(pp_avg_str) ± \(pp_std_str) |\n")
        result += String("| \(model_desc) | \(model_size) | \(model_n_params) | \(backend) | tg \(tg) | \(tg_avg_str) ± \(tg_std_str) |\n")

        return result;
    }

    func clear() {
        tokensList.removeAll()
        temporaryInvalidCChars.removeAll()
        llama_kv_cache_clear(context)
    }

    private func tokenize(text: borrowing String, add_bos: Bool) -> [llama_token] {
        let utf8Count = text.utf8.count
        let n_tokens = utf8Count + (add_bos ? 1 : 0) + 1
        let tokens = UnsafeMutablePointer<llama_token>.allocate(capacity: n_tokens)
        let tokenCount = llama_tokenize(model, text, Int32(utf8Count), tokens, Int32(n_tokens), add_bos, false)

        var swiftTokens: [llama_token] = []
        for i in 0..<tokenCount {
            swiftTokens.append(tokens[Int(i)])
        }

        tokens.deallocate()

        return swiftTokens
    }

    /// - note: The result does not contain null-terminator
    private func tokenToPiece(token: borrowing llama_token) -> [CChar] {
        let result = UnsafeMutablePointer<Int8>.allocate(capacity: 8)
        result.initialize(repeating: Int8(0), count: 8)
        defer {
            result.deallocate()
        }
        let nTokens = llama_token_to_piece(model, token, result, 8, false)

        if nTokens < 0 {
            let newResult = UnsafeMutablePointer<Int8>.allocate(capacity: Int(-nTokens))
            newResult.initialize(repeating: Int8(0), count: Int(-nTokens))
            defer {
                newResult.deallocate()
            }
            let nNewTokens = llama_token_to_piece(model, token, newResult, -nTokens, false)
            let bufferPointer = UnsafeBufferPointer(start: newResult, count: Int(nNewTokens))
            return Array(bufferPointer)
        } else {
            let bufferPointer = UnsafeBufferPointer(start: result, count: Int(nTokens))
            return Array(bufferPointer)
        }
    }
    
    private static func llamaBatchClear(_ batch: inout llama_batch) {
        batch.n_tokens = 0
    }

    private static func llamaBatchAdd(batch: inout llama_batch, 
                                      id: llama_token,
                                      pos: llama_pos,
                                      seqIDs: [llama_seq_id],
                                      logits: Bool) {
        batch.token   [Int(batch.n_tokens)] = id
        batch.pos     [Int(batch.n_tokens)] = pos
        batch.n_seq_id[Int(batch.n_tokens)] = Int32(seqIDs.count)
        
        for i in 0..<seqIDs.count {
            if let batchSeq = batch.seq_id[Int(batch.n_tokens)] {
                batchSeq[Int(i)] = seqIDs[i]
            } else {
                print("found some nil")
            }
        }
        batch.logits  [Int(batch.n_tokens)] = logits ? 1 : 0

        batch.n_tokens += 1
    }

}
