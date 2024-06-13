//
//  WhisperRuntime.swift
//  Brain
//
//  Created by Owen O'Malley on 4/11/24.
//

import Foundation
import Observation
import Accelerate

import CoreML
import WhisperKit

import struct SwiftUI.AppStorage

public struct WhisperSettings {
    @AppStorage("selectedAudioInput") public var selectedAudioInput: String = "No Audio Input"
    @AppStorage("selectedModel") public var selectedModel: String = "distil-large-v3_turbo_600MB"
    @AppStorage("selectedTab") public var selectedTab: String = "Transcribe"
    @AppStorage("selectedTask") public var selectedTask: String = "transcribe"
    @AppStorage("selectedLanguage") public var selectedLanguage: String = "english"
    @AppStorage("repoName") public var repoName: String = "argmaxinc/whisperkit-coreml"
    @AppStorage("enableTimestamps") public var enableTimestamps: Bool = true
    @AppStorage("enablePromptPrefill") public var enablePromptPrefill: Bool = true
    @AppStorage("enableCachePrefill") public var enableCachePrefill: Bool = true
    @AppStorage("enableSpecialCharacters") public var enableSpecialCharacters: Bool = false
    @AppStorage("enableEagerDecoding") public var enableEagerDecoding: Bool = false
    @AppStorage("enableDecoderPreview") public var enableDecoderPreview: Bool = true
    @AppStorage("temperatureStart") public var temperatureStart: Double = 0
    @AppStorage("fallbackCount") public var fallbackCount: Double = 5
    @AppStorage("compressionCheckWindow") public var compressionCheckWindow: Double = 20
    @AppStorage("sampleLength") public var sampleLength: Double = 224
    @AppStorage("silenceThreshold") public var silenceThreshold: Double = 0.3
    @AppStorage("useVAD") public var useVAD: Bool = true
    @AppStorage("tokenConfirmationsNeeded") public var tokenConfirmationsNeeded: Double = 2
    @AppStorage("autoSendDelay") public var numBufferBeforeSend : Int = 2
    @AppStorage("chunkingStrategy") public var chunkingStrategy: ChunkingStrategy = .none
    @AppStorage("encoderComputeUnits") public var encoderComputeUnits: MLComputeUnits = .cpuAndNeuralEngine
    @AppStorage("decoderComputeUnits") public var decoderComputeUnits: MLComputeUnits = .cpuAndNeuralEngine
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

    public var modelState: ModelState = .unloaded
    public var localModels: [String] = []
    public var localModelPath: String = ""
    public var availableModels: [String] = []
    public var availableLanguages: [String] = []
    public var disabledModels: [String] = WhisperKit.recommendedModels().disabled
    
    // MARK: Standard properties
    
    public var loadingProgressValue: Float = 0.0
    public var specializationProgressRatio: Float = 0.7
    public var isFilePickerPresented = false
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
    private var visualizeTask: Task<Void, Never>? = nil
    
    public static let fftInResolution : Int = 64
    public static let fftOutResolution : Int = 32
    public static let fftSetup : vDSP_DFT_Setup = vDSP_DFT_zop_CreateSetup(nil, UInt(64), vDSP_DFT_Direction.FORWARD)!
    public var fftMagnitudes : ContiguousArray<Float> = .init(repeating: 0.001, count: 32)
    
    public static let zerosBuffer : ContiguousArray<Float> = .init(repeating: 0.0, count: 64)
    
    // MARK: - Countdown
    
    public var numBuffersMeetThreshold : Int = 0
    
    private var messageBoard : MessageBoard
    
    public init(messageBoard : MessageBoard) {
        self.messageBoard = messageBoard
    }
    
    private func getComputeOptions() -> ModelComputeOptions {
        return ModelComputeOptions(audioEncoderCompute: self.appSettings.encoderComputeUnits, textDecoderCompute: self.appSettings.decoderComputeUnits)
    }
    
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
    }
    
    public func fetchModels() {
        availableModels = [self.appSettings.selectedModel]

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

        localModels = WhisperKit.formatModelFiles(localModels)
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
            let remoteModels = try await WhisperKit.fetchAvailableModels(from: self.appSettings.repoName)
            for model in remoteModels {
                if !availableModels.contains(model),
                   !disabledModels.contains(model)
                {
                    availableModels.append(model)
                }
            }
        }
    }

    public func loadModel(_ model: String, redownload: Bool = false) {
        print("Selected Model: \(UserDefaults.standard.string(forKey: "selectedModel") ?? "nil")")
        print("""
            Computing Options:
            - Mel Spectrogram:  \(getComputeOptions().melCompute.description)
            - Audio Encoder:    \(getComputeOptions().audioEncoderCompute.description)
            - Text Decoder:     \(getComputeOptions().textDecoderCompute.description)
            - Prefill Data:     \(getComputeOptions().prefillCompute.description)
        """)

        whisperKit = nil
        Task {
            whisperKit = try await WhisperKit(
                computeOptions: getComputeOptions(),
                verbose: true,
                logLevel: .debug,
                prewarm: false,
                load: false,
                download: false
            )
            guard let whisperKit = whisperKit else {
                return
            }

            var folder: URL?

            // Check if the model is available locally
            if localModels.contains(model) && !redownload {
                // Get local model folder URL from localModels
                // TODO: Make this configurable in the UI
                folder = URL(fileURLWithPath: localModelPath).appendingPathComponent(model)
            } else {
                // Download the model
                folder = try await WhisperKit.download(variant: model, from: self.appSettings.repoName, progressCallback: { progress in
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
                    self.messageBoard.postTemporaryMessage("Error prewarming models, retrying: \(error.localizedDescription)")
                    progressBarTask.cancel()
                    if !redownload {
                        loadModel(model, redownload: true)
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
                    if !localModels.contains(model) {
                        localModels.append(model)
                    }

                    availableLanguages = Constants.languages.map { $0.key }.sorted()
                    loadingProgressValue = 1.0
                    modelState = whisperKit.modelState
                }
            }
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

    public func updateProgressBar(targetProgress: Float, maxTime: TimeInterval) async {
        let initialProgress = loadingProgressValue
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

    public func selectFile() {
        isFilePickerPresented = true
    }

    public func handleFilePicker(result: Result<[URL], Error>) {
        switch result {
            case let .success(urls):
                guard let selectedFileURL = urls.first else { return }
                if selectedFileURL.startAccessingSecurityScopedResource() {
                    do {
                        // Access the document data from the file URL
                        let audioFileData = try Data(contentsOf: selectedFileURL)

                        // Create a unique file name to avoid overwriting any existing files
                        let uniqueFileName = UUID().uuidString + "." + selectedFileURL.pathExtension

                        // Construct the temporary file URL in the app's temp directory
                        let tempDirectoryURL = FileManager.default.temporaryDirectory
                        let localFileURL = tempDirectoryURL.appendingPathComponent(uniqueFileName)

                        // Write the data to the temp directory
                        try audioFileData.write(to: localFileURL)

                        self.messageBoard.postTemporaryMessage("File saved to temporary directory | \(localFileURL)")

                        transcribeFile(path: selectedFileURL.path)
                    } catch {
                        self.messageBoard.postTemporaryMessage("File selection error | \(error.localizedDescription)")
                    }
                }
            case let .failure(error):
                print("File selection error | \(error.localizedDescription)")
        }
    }

    public func transcribeFile(path: String) {
        resetState()
        whisperKit?.audioProcessor = AudioProcessor()
        self.transcribeFileTask = Task {
            do {
                try await transcribeCurrentFile(path: path)
            } catch {
                self.messageBoard.postTemporaryMessage("File selection error | \(error.localizedDescription)")
            }
        }
    }

    public func toggleRecording(shouldLoop: Bool) {
        isRecording.toggle()

        if isRecording {
            resetState()
            startRecording(shouldLoop)
        } else {
            stopRecording(shouldLoop)
        }
    }

    public func startRecording(_ loop: Bool) {
        if let audioProcessor = whisperKit?.audioProcessor {
            Task(priority: .userInitiated) {
                guard await AudioProcessor.requestRecordPermission() else {
                    self.messageBoard.postTemporaryMessage("Microphone access was not granted.")
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
                    DispatchQueue.main.async {
                        self.bufferEnergy = self.whisperKit?.audioProcessor.relativeEnergy ?? []
                        self.bufferSeconds = Double(self.whisperKit?.audioProcessor.audioSamples.count ?? 0) / Double(WhisperKit.sampleRate)
                    }
                }

                // Delay the timer start by 1 second
                isRecording = true
                isTranscribing = true
                if loop {
                    realtimeLoop()
                }
            }
        }
    }

    public func stopRecording(_ loop: Bool) {
        isRecording = false
        stopRealtimeTranscription()
        if let audioProcessor = whisperKit?.audioProcessor {
            audioProcessor.stopRecording()
        }

        // If not looping, transcribe the full buffer
        if !loop {
            Task {
                do {
                    try await transcribeCurrentBuffer()
                } catch {
                    self.messageBoard.postTemporaryMessage("Error | \(error.localizedDescription)")
                }
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

    private func transcribeAudioSamples(_ samples: consuming [Float]) async throws -> TranscriptionResult? {
        guard let whisperKit = whisperKit else { return nil }

        let languageCode = Constants.languages[self.appSettings.selectedLanguage, default: Constants.defaultLanguageCode]
        let task: DecodingTask = self.appSettings.selectedTask == "transcribe" ? .transcribe : .translate
        let seekClip: [Float] = []

        let options = DecodingOptions(
            verbose: true,
            task: task,
            language: languageCode,
            temperature: Float(self.appSettings.temperatureStart),
            temperatureFallbackCount: Int(self.appSettings.fallbackCount),
            sampleLength: Int(self.appSettings.sampleLength),
            usePrefillPrompt: self.appSettings.enablePromptPrefill,
            usePrefillCache: self.appSettings.enableCachePrefill,
            skipSpecialTokens: !self.appSettings.enableSpecialCharacters,
            withoutTimestamps: !self.appSettings.enableTimestamps,
            clipTimestamps: seekClip,
            chunkingStrategy: self.appSettings.chunkingStrategy
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
                            self.messageBoard.postTemporaryMessage("Fallback occured: \(fallbacks)")
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

    // MARK: Streaming Logic

    public func realtimeLoop() {
        self.transcriptionTask = Task {
            while isRecording && isTranscribing {
                do {
                    try await transcribeCurrentBuffer()
                } catch {
                    self.messageBoard.postTemporaryMessage("Error | \(error.localizedDescription)")
                    break
                }
            }
        }
        self.visualizeTask = Task {
            while isRecording && isTranscribing {
                do {
                    try await visualizeCurrentBuffer()
                } catch {
                    self.messageBoard.postTemporaryMessage("Error | \(error.localizedDescription)")
                    break
                }
            }
        }
    }

    public func stopRealtimeTranscription() {
        isTranscribing = false
        transcriptionTask?.cancel()
    }

    private func transcribeCurrentBuffer() async throws {
        guard let whisperKit = whisperKit else { return }

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
        lastBufferSize = currentBuffer.count

        if self.appSettings.enableEagerDecoding && isStreamMode {
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

    private func transcribeEagerMode(_ samples: consuming [Float]) async throws -> TranscriptionResult? {
        guard let whisperKit = whisperKit else { return nil }

        guard whisperKit.textDecoder.supportsWordTimestamps else {
            confirmedText = "Eager mode requires word timestamps, which are not supported by the current model: \(self.appSettings.selectedModel)."
            return nil
        }

        let languageCode = Constants.languages[self.appSettings.selectedLanguage, default: Constants.defaultLanguageCode]
        let task: DecodingTask = self.appSettings.selectedTask == "transcribe" ? .transcribe : .translate
        
        //print(self.appSettings.selectedLanguage)
        //print(languageCode)

        let options = DecodingOptions(
            verbose: true,
            task: task,
            language: languageCode,
            temperature: Float(self.appSettings.temperatureStart),
            temperatureFallbackCount: Int(self.appSettings.fallbackCount),
            sampleLength: Int(self.appSettings.sampleLength),
            usePrefillPrompt: self.appSettings.enablePromptPrefill,
            usePrefillCache: self.appSettings.enableCachePrefill,
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
                        self.messageBoard.postTemporaryMessage("Fallback occured: \(fallbacks)")
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
                        let commonPrefix = findLongestCommonPrefix(self.prevWords, self.hypothesisWords)
                        Logging.info("[EagerMode] Prev \"\((prevWords.map { $0.word }).joined())\"")
                        Logging.info("[EagerMode] Next \"\((hypothesisWords.map { $0.word }).joined())\"")
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
    
    //MARK: - Visualization
    
    private func visualizeCurrentBuffer() async throws {
        guard let whisperKit = whisperKit else { return }
        
        let currentBuffer = whisperKit.audioProcessor.audioSamples.suffix(Self.fftInResolution)
        //fft
        
        let fftMagnitudesTemp = Self.fft(samples: currentBuffer)
        
        if let first = fftMagnitudesTemp.first, !first.isNaN {
            self.fftMagnitudes = consume fftMagnitudesTemp
        }

        try await Task.sleep(nanoseconds: 50_000_000)
        
    }
    
    @inlinable static func fft(samples : consuming ArraySlice<Float>) -> ContiguousArray<Float> {
        var realOut = ContiguousArray<Float>(repeating: 0.0, count: Self.fftInResolution)
        var imagOut = ContiguousArray<Float>(repeating: 0.0, count: Self.fftInResolution)
        
        var magnitudes = ContiguousArray<Float>.init(repeating: 0.0, count: Self.fftOutResolution)

        
        samples.withContiguousStorageIfAvailable { realInBufferPointer in
            Self.zerosBuffer.withContiguousStorageIfAvailable { imagInBufferPointer in
                realOut.withContiguousMutableStorageIfAvailable { realOutBufferPointer in
                    imagOut.withContiguousMutableStorageIfAvailable { imagOutBufferPointer in
                            vDSP_DFT_Execute(Self.fftSetup,
                                             realInBufferPointer.baseAddress!,
                                             imagInBufferPointer.baseAddress!,
                                             realOutBufferPointer.baseAddress!,
                                             imagOutBufferPointer.baseAddress!)
                            magnitudes.withContiguousMutableStorageIfAvailable { magnitudesBufferPointer in
                                var complex = DSPSplitComplex(realp: realOutBufferPointer.baseAddress!, imagp: imagOutBufferPointer.baseAddress!)
                                vDSP_zvabs(&complex, 1, magnitudesBufferPointer.baseAddress!, 1, UInt(Self.fftOutResolution))
                        }
                    }
                }
            }
        }
        
        //scale down the big boi samples around 1 hertz
        magnitudes[0] *= 0.2
        magnitudes[1] *= 0.4
        
        return magnitudes
    }
    
    // MARK: - Auto-sending Logic
    
    private func checkAudioBuffer() {
        if self.lastBufferEnergy > Float(self.appSettings.silenceThreshold) {
            self.numBuffersMeetThreshold += 1
        } else {
            self.numBuffersMeetThreshold = 0
        }
        
        
    }
}


