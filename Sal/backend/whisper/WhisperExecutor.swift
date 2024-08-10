//
//  WhisperRuntime.swift
//  Brain
//
//  Created by Owen O'Malley on 4/11/24.
//

import Foundation
import Observation
import Accelerate
import WhisperKit

import struct SwiftUI.AppStorage
import enum CoreML.MLComputeUnits

public struct WhisperSettings {
    @AppStorage("selectedAudioInput") public var selectedAudioInput: String = "No Audio Input"
    @AppStorage("selectedModel") public var selectedModel: String = "distil-large-v3_turbo_600MB"
    @AppStorage("selectedLanguage") public var selectedLanguage: String = "english"

    @AppStorage("enableEagerDecoding") public var enableEagerDecoding: Bool = false
    @AppStorage("enableTimestamps") public var enableTimestamps: Bool = true
    @AppStorage("enableSpecialCharacters") public var enableSpecialCharacters: Bool = false
    @AppStorage("useVAD") public var useVAD: Bool = true


    @AppStorage("temperatureStart") public var temperatureStart: Double = 0
    @AppStorage("fallbackCount") public var fallbackCount: Double = 5
    @AppStorage("compressionCheckWindow") public var compressionCheckWindow: Double = 20
    @AppStorage("sampleLength") public var sampleLength: Double = 224
    @AppStorage("silenceThreshold") public var silenceThreshold: Double = 0.3
    @AppStorage("tokenConfirmationsNeeded") public var tokenConfirmationsNeeded: Double = 2
}

@Observable public final class Whisper {
    public var whisperKit: WhisperKit? = nil
    #if os(macOS)
    public var audioDevices: [AudioDevice]? = nil
    #endif
    public var isRecording: Bool = false
    public var isTranscribing: Bool = false
    public var currentText: String = ""
    public var currentChunks: [Int: (chunkText: [String], fallbacks: Int)] = [:]
    public let modelStorage: String = "huggingface/models/argmaxinc/whisperkit-coreml"

    // MARK: Model management

    public let repoName: String = "argmaxinc/whisperkit-coreml"
    public var modelState: ModelState = .unloaded
    public var localModels: [String] = []
    public var localModelPath: String = ""
    public var availableModels: [String] = []
    public var availableLanguages: [String] = []
    public var disabledModels: [String] = WhisperKit.recommendedModels().disabled
    
    // MARK: Standard properties
    
    public var loadingProgressValue: Float = 0.0
    public var specializationProgressRatio: Float = 0.7
    public var firstTokenTime: TimeInterval = 0
    public var pipelineStart: TimeInterval = 0
    public var effectiveRealTimeFactor: TimeInterval = 0
    public var effectiveSpeedFactor: TimeInterval = 0
    public var totalInferenceTime: TimeInterval = 0
    public var tokensPerSecond: TimeInterval = 0
    public var currentLag: TimeInterval = 0
    public var currentFallbacks: Int = 0
    public var currentEncodingLoops: Int = 0
    public var currentDecodingLoops: Int = 0
    public var lastBufferSize: Int = 0
    public var lastConfirmedSegmentEndSeconds: Float = 0
    public var requiredSegmentsForConfirmation: Int = 4
    public var bufferEnergy: [Float] = []
    public var bufferSeconds: Double = 0
    public var confirmedSegments: [TranscriptionSegment] = []
    public var unconfirmedSegments: [TranscriptionSegment] = []
    public var unconfirmedText: [String] = []
    
    public var isStreamMode : Bool = true

    public var appSettings : WhisperSettings = .init()
    // MARK: Eager mode properties

    public var eagerResults: [TranscriptionResult?] = []
    public var prevResult: TranscriptionResult?
    public var lastAgreedSeconds: Float = 0.0
    public var prevWords: [WordTiming] = []
    public var lastAgreedWords: [WordTiming] = []
    public var confirmedWords: [WordTiming] = []
    public var confirmedText: String = ""
    public var hypothesisWords: [WordTiming] = []
    public var hypothesisText: String = ""
    
    
    public var lastBufferEnergy : Float {
        get { self.bufferEnergy.last ?? 0.0 }
    }

    // MARK: - Logic
    
    private var transcriptionTask: Task<Void, Never>? = nil
    private var transcribeFileTask: Task<Void, Never>? = nil
    
    // MARK: - Countdown
    
    public var numBuffersNotMeetThreshold : Int = 0
    
    private var messageBoard : MessageBoardManager
    
    public init(messageBoard : MessageBoardManager) {
        self.messageBoard = messageBoard
    }
    
    private func getComputeOptions() -> ModelComputeOptions {
        return ModelComputeOptions(audioEncoderCompute: MLComputeUnits.cpuAndNeuralEngine, textDecoderCompute: MLComputeUnits.cpuAndNeuralEngine)
    }
#if os(macOS)
    public func getAudioDevicesMacOS() {
        self.audioDevices = AudioProcessor.getAudioDevices()
        if let audioDevices = self.audioDevices,
           !audioDevices.isEmpty,
           self.appSettings.selectedAudioInput == "No Audio Input",
           let device = audioDevices.first
        {
            self.appSettings.selectedAudioInput = device.name
        }
    }
#endif
    public func resetState() {
        transcribeFileTask?.cancel()
        isRecording = false
        isTranscribing = false
        whisperKit?.audioProcessor.stopRecording()
        currentText = ""
        currentChunks = [:]

        pipelineStart = Double.greatestFiniteMagnitude
        firstTokenTime = Double.greatestFiniteMagnitude
        effectiveRealTimeFactor = 0
        effectiveSpeedFactor = 0
        totalInferenceTime = 0
        tokensPerSecond = 0
        currentLag = 0
        currentFallbacks = 0
        currentEncodingLoops = 0
        currentDecodingLoops = 0
        lastBufferSize = 0
        lastConfirmedSegmentEndSeconds = 0
        requiredSegmentsForConfirmation = 2
        bufferEnergy = []
        bufferSeconds = 0
        confirmedSegments = []
        unconfirmedSegments = []

        eagerResults = []
        prevResult = nil
        lastAgreedSeconds = 0.0
        prevWords = []
        lastAgreedWords = []
        confirmedWords = []
        confirmedText = ""
        hypothesisWords = []
        hypothesisText = ""
        
        numBuffersNotMeetThreshold = 0
    }
    
    public func fetchModels() {
        self.availableModels = [self.appSettings.selectedModel]

        // First check what's already downloaded
        if let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let modelPath = documents.appendingPathComponent(modelStorage).path

            // Check if the directory exists
            if FileManager.default.fileExists(atPath: modelPath) {
                localModelPath = modelPath
                do {
                    let downloadedModels = try FileManager.default.contentsOfDirectory(atPath: modelPath)
                    for model in downloadedModels where !localModels.contains(model) {
                        localModels.append(model)
                    }
                } catch {
                    self.messageBoard.postTemporaryMessage("Error enumerating files at \(modelPath): \(error.localizedDescription)")
                }
            }
        }

        localModels = WhisperKit.formatModelFiles(self.localModels)
        for model in localModels {
            if !availableModels.contains(model),
               !disabledModels.contains(model)
            {
                availableModels.append(model)
            }
        }

        //print("Found locally: \(localModels)")
        //print("Previously selected model: \(self.appSettings.selectedModel)")

        Task {
            let remoteModels = try await WhisperKit.fetchAvailableModels(from: self.repoName)
            for model in remoteModels {
                if !availableModels.contains(model),
                   !disabledModels.contains(model)
                {
                    availableModels.append(model)
                }
            }
        }
    }

    public func loadModel(redownload: Bool = false) async throws {
        print("Selected Model: \(UserDefaults.standard.string(forKey: "selectedModel") ?? "nil")")
        
        print("""
            Computing Options:
            - Mel Spectrogram:  \(getComputeOptions().melCompute.description)
            - Audio Encoder:    \(getComputeOptions().audioEncoderCompute.description)
            - Text Decoder:     \(getComputeOptions().textDecoderCompute.description)
            - Prefill Data:     \(getComputeOptions().prefillCompute.description)
        """)
        
        let model = self.appSettings.selectedModel
        
        await MainActor.run {
            self.whisperKit = nil
        }
        //Task {
            self.messageBoard.postMessage("whisper model is loading")
            self.whisperKit = try await WhisperKit(
                computeOptions: self.getComputeOptions(),
                verbose: true,
                logLevel: .none,
                prewarm: false,
                load: false,
                download: false
            )
            guard let whisperKit = whisperKit else {
                return
            }

            var folder: URL?

            print(model)
            // Check if the model is available locally
            if localModels.contains(model) && !redownload {

                folder = URL(fileURLWithPath: localModelPath).appendingPathComponent(model)
            } else {
                // Download the model
                //self.messageBoard.postMessage("downloading whisper model")
                self.modelState = .downloading
                folder = try await WhisperKit.download(variant: model, from: self.repoName, progressCallback: { progress in
                    DispatchQueue.main.async {
                        self.loadingProgressValue = Float(progress.fractionCompleted) * self.specializationProgressRatio
                        self.modelState = .downloading
                    }
                })
            }

            await MainActor.run {
                loadingProgressValue = specializationProgressRatio
                modelState = .downloaded
            }

            if let modelFolder = folder {
                whisperKit.modelFolder = modelFolder

                await MainActor.run {
                    // Set the loading progress to 90% of the way after prewarm
                    loadingProgressValue = specializationProgressRatio
                    modelState = .prewarming
                }

                let progressBarTask = Task {
                    await self.updateProgressBar(targetProgress: 0.9, maxTime: 240)
                }

                // Prewarm models
                do {
                    try await whisperKit.prewarmModels()
                    progressBarTask.cancel()
                } catch {
                    self.messageBoard.postTemporaryMessage("Error prewarming models | \(error.localizedDescription)")
                    progressBarTask.cancel()
                    if !redownload {
                        try await loadModel(redownload: true)
                        return
                    } else {
                        // Redownloading failed, error out
                        modelState = .unloaded
                        return
                    }
                }

                await MainActor.run {
                    // Set the loading progress to 90% of the way after prewarm
                    loadingProgressValue = specializationProgressRatio + 0.9 * (1 - specializationProgressRatio)
                    modelState = .loading
                }

                try await whisperKit.loadModels()

                await MainActor.run {
                    if !self.localModels.contains(model) {
                        self.localModels.append(model)
                    }

                    self.availableLanguages = Constants.languages.map { $0.key }.sorted()
                    self.loadingProgressValue = 1.0
                    self.modelState = whisperKit.modelState
                }
                self.messageBoard.postMessage("whisper is now \(self.modelState.description)")
        }
    }

    public func deleteModel() {
        if localModels.contains(self.appSettings.selectedModel) {
            let modelFolder = URL(fileURLWithPath: localModelPath).appendingPathComponent(self.appSettings.selectedModel)

            do {
                try FileManager.default.removeItem(at: modelFolder)

                if let index = localModels.firstIndex(of: self.appSettings.selectedModel) {
                    localModels.remove(at: index)
                }

                modelState = .unloaded
            } catch {
                self.messageBoard.postTemporaryMessage("Error deleting model: \(error)")
            }
        }
    }

    public func updateProgressBar(targetProgress: borrowing Float, maxTime: borrowing TimeInterval) async {
        let initialProgress = self.loadingProgressValue
        let decayConstant = -log(1 - targetProgress) / Float(maxTime)

        let startTime = Date()

        while true {
            let elapsedTime = Date().timeIntervalSince(startTime)

            // Break down the calculation
            let decayFactor = exp(-decayConstant * Float(elapsedTime))
            let progressIncrement = (1 - initialProgress) * (1 - decayFactor)
            let currentProgress = initialProgress + progressIncrement

            await MainActor.run {
                loadingProgressValue = currentProgress
            }
            
            self.messageBoard.postMessage("Model Progress | \((currentProgress * 1000).rounded() / 10)%")

            if currentProgress >= targetProgress {
                break
            }
            
            
            do {
                try await Task.sleep(nanoseconds: 100_000_000)
            } catch {
                break
            }
        }
    }

    public func transcribeFile(path: String) {
        resetState()
        whisperKit?.audioProcessor = AudioProcessor()
        self.transcribeFileTask = Task {
            do {
                try await transcribeCurrentFile(path: path)
            } catch {
                print("File selection error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Transcribe Logic

    public func transcribeCurrentFile(path: String) async throws {
        let audioFileBuffer = try AudioProcessor.loadAudio(fromPath: path)
        let audioFileSamples = AudioProcessor.convertBufferToArray(buffer: audioFileBuffer)
        let transcription = try await transcribeAudioSamples(audioFileSamples)

        await MainActor.run {
            currentText = ""
            guard let segments = transcription?.segments else {
                return
            }

            self.tokensPerSecond = transcription?.timings.tokensPerSecond ?? 0
            self.effectiveRealTimeFactor = transcription?.timings.realTimeFactor ?? 0
            self.effectiveSpeedFactor = transcription?.timings.speedFactor ?? 0
            self.currentEncodingLoops = Int(transcription?.timings.totalEncodingRuns ?? 0)
            self.firstTokenTime = transcription?.timings.firstTokenTime ?? 0
            self.pipelineStart = transcription?.timings.pipelineStart ?? 0
            self.currentLag = transcription?.timings.decodingLoop ?? 0

            self.confirmedSegments = segments
        }
    }

    public func transcribeCurrentBuffer() async throws {
        guard let whisperKit = self.whisperKit else { return }

        // Retrieve the current audio buffer from the audio processor
        let currentBuffer = whisperKit.audioProcessor.audioSamples

        // Calculate the size and duration of the next buffer segment
        let nextBufferSize = currentBuffer.count - lastBufferSize
        let nextBufferSeconds = Float(nextBufferSize) / Float(WhisperKit.sampleRate)

        // Only run the transcribe if the next buffer has at least 1 second of audio
        guard nextBufferSeconds > 1 else {
            await MainActor.run {
                if currentText == "" {
                    currentText = "Waiting for speech..."
                }
            }
            try await Task.sleep(nanoseconds: 100_000_000) // sleep for 100ms for next buffer
            return
        }

        if self.appSettings.useVAD {
            let voiceDetected = AudioProcessor.isVoiceDetected(
                in: whisperKit.audioProcessor.relativeEnergy,
                nextBufferInSeconds: nextBufferSeconds,
                silenceThreshold: Float(self.appSettings.silenceThreshold)
            )
            // Only run the transcribe if the next buffer has voice
            guard voiceDetected else {
                self.numBuffersNotMeetThreshold += 1
                await MainActor.run {
                    if currentText == "" {
                        currentText = "Waiting for speech..."
                    }
                }

                // TODO: Implement silence buffer purging
//                if nextBufferSeconds > 30 {
//                    // This is a completely silent segment of 30s, so we can purge the audio and confirm anything pending
//                    lastConfirmedSegmentEndSeconds = 0
//                    whisperKit.audioProcessor.purgeAudioSamples(keepingLast: 2 * WhisperKit.sampleRate) // keep last 2s to include VAD overlap
//                    currentBuffer = whisperKit.audioProcessor.audioSamples
//                    lastBufferSize = 0
//                    confirmedSegments.append(contentsOf: unconfirmedSegments)
//                    unconfirmedSegments = []
//                }

                // Sleep for 100ms and check the next buffer
                try await Task.sleep(nanoseconds: 100_000_000)
                return
            }
        }

        // Store this for next iterations VAD
        self.numBuffersNotMeetThreshold = 0
        self.lastBufferSize = currentBuffer.count

        if self.appSettings.enableEagerDecoding && self.isStreamMode {
            // Run realtime transcribe using word timestamps for segmentation
            let transcription = try await transcribeEagerMode(Array(currentBuffer))
            await MainActor.run {
                self.tokensPerSecond = transcription?.timings.tokensPerSecond ?? 0
                self.firstTokenTime = transcription?.timings.firstTokenTime ?? 0
                self.pipelineStart = transcription?.timings.pipelineStart ?? 0
                self.currentLag = transcription?.timings.decodingLoop ?? 0
                self.currentEncodingLoops = Int(transcription?.timings.totalEncodingRuns ?? 0)

                let totalAudio = Double(currentBuffer.count) / Double(WhisperKit.sampleRate)
                self.totalInferenceTime = transcription?.timings.fullPipeline ?? 0
                self.effectiveRealTimeFactor = Double(totalInferenceTime) / totalAudio
                self.effectiveSpeedFactor = totalAudio / Double(totalInferenceTime)
            }
        } else {
            // Run realtime transcribe using timestamp tokens directly
            let transcription = try await transcribeAudioSamples(Array(currentBuffer))

            // We need to run this next part on the main thread
            await MainActor.run {
                currentText = ""
                guard let segments = transcription?.segments else {
                    return
                }

                self.tokensPerSecond = transcription?.timings.tokensPerSecond ?? 0
                self.firstTokenTime = transcription?.timings.firstTokenTime ?? 0
                self.pipelineStart = transcription?.timings.pipelineStart ?? 0
                self.currentLag = transcription?.timings.decodingLoop ?? 0
                self.currentEncodingLoops += Int(transcription?.timings.totalEncodingRuns ?? 0)

                let totalAudio = Double(currentBuffer.count) / Double(WhisperKit.sampleRate)
                self.totalInferenceTime += transcription?.timings.fullPipeline ?? 0
                self.effectiveRealTimeFactor = Double(totalInferenceTime) / totalAudio
                self.effectiveSpeedFactor = totalAudio / Double(totalInferenceTime)

                // Logic for moving segments to confirmedSegments
                if segments.count > requiredSegmentsForConfirmation {
                    // Calculate the number of segments to confirm
                    let numberOfSegmentsToConfirm = segments.count - requiredSegmentsForConfirmation

                    // Confirm the required number of segments
                    let confirmedSegmentsArray = Array(segments.prefix(numberOfSegmentsToConfirm))
                    let remainingSegments = Array(segments.suffix(requiredSegmentsForConfirmation))

                    // Update lastConfirmedSegmentEnd based on the last confirmed segment
                    if let lastConfirmedSegment = confirmedSegmentsArray.last, lastConfirmedSegment.end > lastConfirmedSegmentEndSeconds {
                        lastConfirmedSegmentEndSeconds = lastConfirmedSegment.end

                        // Add confirmed segments to the confirmedSegments array
                        if !self.confirmedSegments.contains(confirmedSegmentsArray) {
                            self.confirmedSegments.append(contentsOf: confirmedSegmentsArray)
                        }
                    }

                    // Update transcriptions to reflect the remaining segments
                    self.unconfirmedSegments = remainingSegments
                } else {
                    // Handle the case where segments are fewer or equal to required
                    self.unconfirmedSegments = segments
                }
            }
        }
    }


    // MARK: Streaming Logic

    
    //MARK: - Recording
    public func realtimeRecord(emptyBufferLimit numBuffersBeforeEnd : Int) async throws {
        self.resetState()

        try await self.startRecording(true) {
            while self.numBuffersNotMeetThreshold < numBuffersBeforeEnd {
                try await self.transcribeCurrentBuffer()
                if self.numBuffersNotMeetThreshold % 5 == 0 {
                    print(self.numBuffersNotMeetThreshold)
                }
            }
        }
        
        self.stopRecording(true)
    }
    
    //MARK: - Recording
    public func realtimeLoop() {
        self.transcriptionTask = Task {
            while isRecording && isTranscribing {
                do {
                    try await transcribeCurrentBuffer()
                } catch {
                    print("Error: \(error.localizedDescription)")
                    break
                }
            }
        }
    }
    
    public func toggleRecording(shouldLoop: Bool) async throws {
        isRecording.toggle()

        if isRecording {
            resetState()
            try await startRecording(shouldLoop) {
                self.realtimeLoop()
            }
        } else {
            stopRecording(shouldLoop)
        }
    }

    public func startRecording(_ loop: Bool, realtimeLoop : () async throws -> Void ) async throws {
        if let audioProcessor = whisperKit?.audioProcessor {
            //Task(priority: .userInitiated) {
                guard await AudioProcessor.requestRecordPermission() else {
                    print("Microphone access was not granted.")
                    return
                }

                var deviceId: DeviceID?
                #if os(macOS)
                if self.appSettings.selectedAudioInput != "No Audio Input",
                   let devices = self.audioDevices,
                   let device = devices.first(where: { $0.name == self.appSettings.selectedAudioInput })
                {
                    deviceId = device.id
                }

                // There is no built-in microphone
                if deviceId == nil {
                    throw WhisperError.microphoneUnavailable()
                }
                #endif

                try? audioProcessor.startRecordingLive(inputDeviceID: deviceId) { _ in
                    DispatchQueue.main.async { [self] in
                        bufferEnergy = whisperKit?.audioProcessor.relativeEnergy ?? []
                        bufferSeconds = Double(whisperKit?.audioProcessor.audioSamples.count ?? 0) / Double(WhisperKit.sampleRate)
                    }
                }

                // Delay the timer start by 1 second
                isRecording = true
                isTranscribing = true
                
                if loop {
                    try await realtimeLoop()
                }
            //}
        }
    }

    public func stopRecording(_ loop: Bool) {
        isRecording = false
        isTranscribing = false
        transcriptionTask?.cancel()
        if let audioProcessor = whisperKit?.audioProcessor {
            audioProcessor.stopRecording()
        }

        // If not looping, transcribe the full buffer
        if !loop {
            Task {
                do {
                    try await transcribeCurrentBuffer()
                } catch {
                    print("Error: \(error.localizedDescription)")
                }
            }
        }
    }

    //MARK: - Transcribing Audio Buffers
    
    private func transcribeEagerMode(_ samples: consuming [Float]) async throws -> TranscriptionResult? {
        guard let whisperKit = whisperKit else { return nil }

        guard whisperKit.textDecoder.supportsWordTimestamps else {
            confirmedText = "Eager mode requires word timestamps, which are not supported by the current model: \(self.appSettings.selectedModel)."
            return nil
        }

        let languageCode = Constants.languages[self.appSettings.selectedLanguage, default: Constants.defaultLanguageCode]
        let task: DecodingTask = .transcribe

        let options = DecodingOptions(
            verbose: true,
            task: task,
            language: languageCode,
            temperature: Float(self.appSettings.temperatureStart),
            temperatureFallbackCount: Int(self.appSettings.fallbackCount),
            sampleLength: Int(self.appSettings.sampleLength),
            usePrefillPrompt: true,
            usePrefillCache: true,
            skipSpecialTokens: !self.appSettings.enableSpecialCharacters,
            withoutTimestamps: !self.appSettings.enableTimestamps,
            wordTimestamps: true, // required for eager mode
            firstTokenLogProbThreshold: -1.5 // higher threshold to prevent fallbacks from running to often
        )

        // Early stopping checks
        let decodingCallback: ((TranscriptionProgress) -> Bool?) = { progress in
            DispatchQueue.main.async {
                let fallbacks = Int(progress.timings.totalDecodingFallbacks)
                if progress.text.count < self.currentText.count {
                    if fallbacks == self.currentFallbacks {
                        //                        self.unconfirmedText.append(currentText)
                    } else {
                        print("Fallback occured: \(fallbacks)")
                    }
                }
                self.currentText = progress.text
                self.currentFallbacks = fallbacks
                self.currentDecodingLoops += 1
            }
            // Check early stopping
            let currentTokens = progress.tokens
            let checkWindow = Int(self.appSettings.compressionCheckWindow)
            if currentTokens.count > checkWindow {
                let checkTokens: [Int] = currentTokens.suffix(checkWindow)
                let compressionRatio = compressionRatio(of: checkTokens)
                if compressionRatio > options.compressionRatioThreshold! {
                    Logging.debug("Early stopping due to compression threshold")
                    return false
                }
            }
            if progress.avgLogprob! < options.logProbThreshold! {
                Logging.debug("Early stopping due to logprob threshold")
                return false
            }

            return nil
        }

        Logging.info("[EagerMode] \(lastAgreedSeconds)-\(Double(samples.count) / 16000.0) seconds")

        let streamingAudio = samples
        var streamOptions = options
        streamOptions.clipTimestamps = [lastAgreedSeconds]
        let lastAgreedTokens = lastAgreedWords.flatMap { $0.tokens }
        streamOptions.prefixTokens = lastAgreedTokens
        do {
            let transcription: TranscriptionResult? = try await whisperKit.transcribe(audioArray: streamingAudio, decodeOptions: streamOptions, callback: decodingCallback).first
            await MainActor.run {
                var skipAppend = false
                if let result = transcription {
                    hypothesisWords = result.allWords.filter { $0.start >= lastAgreedSeconds }

                    if let prevResult = prevResult {
                        prevWords = prevResult.allWords.filter { $0.start >= lastAgreedSeconds }
                        let commonPrefix = findLongestCommonPrefix(prevWords, hypothesisWords)
                        Logging.info("[EagerMode] Prev \"\((prevWords.map { $0.word }).joined())\"")
                        Logging.info("[EagerMode] Next \"\((self.hypothesisWords.map { $0.word }).joined())\"")
                        Logging.info("[EagerMode] Found common prefix \"\((commonPrefix.map { $0.word }).joined())\"")

                        if commonPrefix.count >= Int(self.appSettings.tokenConfirmationsNeeded) {
                            lastAgreedWords = commonPrefix.suffix(Int(self.appSettings.tokenConfirmationsNeeded))
                            lastAgreedSeconds = lastAgreedWords.first!.start
                            Logging.info("[EagerMode] Found new last agreed word \"\(lastAgreedWords.first!.word)\" at \(lastAgreedSeconds) seconds")

                            confirmedWords.append(contentsOf: commonPrefix.prefix(commonPrefix.count - Int(self.appSettings.tokenConfirmationsNeeded)))
                            let currentWords = confirmedWords.map { $0.word }.joined()
                        } else {
                            Logging.info("[EagerMode] Using same last agreed time \(lastAgreedSeconds)")
                            skipAppend = true
                        }
                    }
                    prevResult = result
                }

                if !skipAppend {
                    eagerResults.append(transcription)
                }
            }
        } catch {
            Logging.error("[EagerMode] Error: \(error)")
        }

        await MainActor.run {
            let finalWords = confirmedWords.map { $0.word }.joined()
            confirmedText = finalWords

            // Accept the final hypothesis because it is the last of the available audio
            let lastHypothesis = lastAgreedWords + findLongestDifferentSuffix(prevWords, hypothesisWords)
            hypothesisText = lastHypothesis.map { $0.word }.joined()
        }

        let mergedResult = mergeTranscriptionResults(eagerResults, confirmedWords: confirmedWords)

        return mergedResult
    }
    
    private func transcribeAudioSamples(_ samples: consuming [Float]) async throws -> TranscriptionResult? {
        guard let whisperKit = whisperKit else { return nil }

        let languageCode = Constants.languages[self.appSettings.selectedLanguage, default: Constants.defaultLanguageCode]
        let task: DecodingTask = .transcribe
        let seekClip: [Float] = []

        let options = DecodingOptions(
            verbose: true,
            task: task,
            language: languageCode,
            temperature: Float(self.appSettings.temperatureStart),
            temperatureFallbackCount: Int(self.appSettings.fallbackCount),
            sampleLength: Int(self.appSettings.sampleLength),
            usePrefillPrompt: true,
            usePrefillCache: true,
            skipSpecialTokens: !self.appSettings.enableSpecialCharacters,
            withoutTimestamps: !self.appSettings.enableTimestamps,
            clipTimestamps: seekClip,
            chunkingStrategy: ChunkingStrategy.none
        )

        // Early stopping checks
        let decodingCallback: ((TranscriptionProgress) -> Bool?) = { (progress: TranscriptionProgress) in
            DispatchQueue.main.async {
                let fallbacks = Int(progress.timings.totalDecodingFallbacks)
                let chunkId = progress.windowId

                // First check if this is a new window for the same chunk, append if so
                var updatedChunk = (chunkText: [progress.text], fallbacks: fallbacks)
                if var currentChunk = self.currentChunks[chunkId], let previousChunkText = currentChunk.chunkText.last {
                    if progress.text.count >= previousChunkText.count {
                        // This is the same window of an existing chunk, so we just update the last value
                        currentChunk.chunkText[currentChunk.chunkText.endIndex - 1] = progress.text
                        updatedChunk = currentChunk
                    } else {
                        // This is either a new window or a fallback (only in streaming mode)
                        if fallbacks == currentChunk.fallbacks && self.isStreamMode {
                            // New window (since fallbacks havent changed)
                            updatedChunk.chunkText = currentChunk.chunkText + [progress.text]
                        } else {
                            // Fallback, overwrite the previous bad text
                            updatedChunk.chunkText[currentChunk.chunkText.endIndex - 1] = progress.text
                            updatedChunk.fallbacks = fallbacks
                            print("Fallback occured: \(fallbacks)")
                        }
                    }
                }

                // Set the new text for the chunk
                self.currentChunks[chunkId] = updatedChunk
                let joinedChunks = self.currentChunks.sorted { $0.key < $1.key }.flatMap { $0.value.chunkText }.joined(separator: "\n")

                self.currentText = joinedChunks
                self.currentFallbacks = fallbacks
                self.currentDecodingLoops += 1
            }

            // Check early stopping
            let currentTokens = progress.tokens
            let checkWindow = Int(self.appSettings.compressionCheckWindow)
            if currentTokens.count > checkWindow {
                let checkTokens: [Int] = currentTokens.suffix(checkWindow)
                let compressionRatio = compressionRatio(of: checkTokens)
                if compressionRatio > options.compressionRatioThreshold! {
                    Logging.debug("Early stopping due to compression threshold")
                    return false
                }
            }
            if progress.avgLogprob! < options.logProbThreshold! {
                Logging.debug("Early stopping due to logprob threshold")
                return false
            }
            return nil
        }

        let transcriptionResults: [TranscriptionResult] = try await whisperKit.transcribe(
            audioArray: samples,
            decodeOptions: options,
            callback: decodingCallback
        )

        let mergedResults = mergeTranscriptionResults(transcriptionResults)

        return mergedResults
    }

    
}


