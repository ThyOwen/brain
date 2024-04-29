//
//  WhisperRuntime.swift
//  Brain
//
//  Created by Owen O'Malley on 4/11/24.
//

import Foundation
import Observation
import Accelerate
import AVFoundation
import WhisperKit

public enum WhisperError : Error {
    case microphoneUnavailable
}

@Observable class Whisper {
    public var whisperKit: WhisperKit? = nil
    #if os(macOS)
    public var audioDevices: [AudioDevice]? = nil
    #endif
    public var isRecording: Bool = false
    public var isTranscribing: Bool = false
    public var currentText: String = ""
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
    
    public var combined : [String] {
        var confirmed = self.confirmedSegments.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
        let unconfirmed = self.unconfirmedSegments.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
        confirmed.append(contentsOf: unconfirmed)
        return confirmed
        
    }

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
    private var visualizeTask: Task<Void, Never>? = nil
    
    @ObservationIgnored public let fftInResolution : Int
    @ObservationIgnored public let fftOutResolution : Int
    @ObservationIgnored private let fftSetup : vDSP_DFT_Setup
    public var fftMagnitudes : [Float]
    public var fftLoudness : Float = 0.0
    
    // MARK: - Countdown
    
    public var countdownValue : Float = 0 // Initial countdown value
    public let countdownLimit : Int = 3
    public var timer : Timer? = nil

    init(fftResolution : Int = 16) {
        self.fftOutResolution = fftResolution
        self.fftInResolution = fftResolution * 2
        self.fftSetup = vDSP_DFT_zop_CreateSetup(nil, UInt(self.fftInResolution), vDSP_DFT_Direction.FORWARD)!
        self.fftMagnitudes = [Float](repeating: 0.0, count: fftResolution)
    }
    
    func resetState() {
        isRecording = false
        isTranscribing = false
        whisperKit?.audioProcessor.stopRecording()
        currentText = ""
        unconfirmedText = []

        firstTokenTime = 0
        pipelineStart = 0
        effectiveRealTimeFactor = 0
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

    func fetchModels() {
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
                    print("Error enumerating files at \(modelPath): \(error.localizedDescription)")
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

        print("Found locally: \(localModels)")
        print("Previously selected model: \(self.appSettings.selectedModel)")

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

    func loadModel(_ model: String, redownload: Bool = false) {
        print("Selected Model: \(UserDefaults.standard.string(forKey: "selectedModel") ?? "nil")")

        whisperKit = nil
        Task {
            whisperKit = try await WhisperKit(
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
                    print("Error prewarming models, retrying: \(error.localizedDescription)")
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
                    
                    availableLanguages = whisperKit.tokenizer?.languages.map { $0.key }.sorted() ?? ["english"]
                    loadingProgressValue = 1.0
                    modelState = whisperKit.modelState
                }
            }
        }
    }
    
    func deleteModel() {
        if localModels.contains(self.appSettings.selectedModel) {
            let modelFolder = URL(fileURLWithPath: localModelPath).appendingPathComponent(self.appSettings.selectedModel)
            
            do {
                try FileManager.default.removeItem(at: modelFolder)
                
                if let index = localModels.firstIndex(of: self.appSettings.selectedModel) {
                    localModels.remove(at: index)
                }
                
                modelState = .unloaded
            } catch {
                print("Error deleting model: \(error)")
            }
        }
    }

    func updateProgressBar(targetProgress: Float, maxTime: TimeInterval) async {
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

    func selectFile() {
        isFilePickerPresented = true
    }

    func toggleRecording(shouldLoop: Bool) {
        isRecording.toggle()
        if isRecording {
            resetState()
            startRecording(shouldLoop)
        } else {
            stopRecording(shouldLoop)
        }
    }

    func startRecording(_ loop: Bool) {
        if let audioProcessor = whisperKit?.audioProcessor {
            Task(priority: .userInitiated) {
                guard await AudioProcessor.requestRecordPermission() else {
                    print("Microphone access was not granted.")
                    return
                }
                
                var deviceId: DeviceID?
                #if os(macOS)
                if self.appSettings.selectedAudioInput != "No Audio Input",
                   let devices = self.audioDevices,
                   let device = devices.first(where: {$0.name == self.appSettings.selectedAudioInput}) {
                    deviceId = device.id
                }

                // There is no built-in microphone
                if deviceId == nil {
                   throw WhisperError.microphoneUnavailable
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

    func stopRecording(_ loop: Bool) {
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
                    print("Error: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Transcribe Logic

    func transcribeAudioSamples(_ samples: [Float]) async throws -> TranscriptionResult? {
        guard let whisperKit = whisperKit else { return nil }

        let languageCode = whisperKit.tokenizer?.languages[self.appSettings.selectedLanguage] ?? "en"
        let task: DecodingTask = self.appSettings.selectedTask == "transcribe" ? .transcribe : .translate
        let seekClip = [lastConfirmedSegmentEndSeconds]

        let options = DecodingOptions(
            verbose: false,
            task: task,
            language: languageCode,
            temperature: Float(self.appSettings.temperatureStart),
            temperatureFallbackCount: Int(self.appSettings.fallbackCount),
            sampleLength: Int(self.appSettings.sampleLength),
            usePrefillPrompt: self.appSettings.enablePromptPrefill,
            usePrefillCache: self.appSettings.enableCachePrefill,
            skipSpecialTokens: !self.appSettings.enableSpecialCharacters,
            withoutTimestamps: !self.appSettings.enableTimestamps,
            clipTimestamps: seekClip
        )

        // Early stopping checks
        let decodingCallback: ((TranscriptionProgress) -> Bool?) = { progress in
            DispatchQueue.main.async {
                let fallbacks = Int(progress.timings.totalDecodingFallbacks)
                if progress.text.count < self.currentText.count {
                    if fallbacks == self.currentFallbacks {
                        self.unconfirmedText.append(self.currentText)
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
                    return false
                }
            }
            if progress.avgLogprob! < options.logProbThreshold! {
                return false
            }

            return nil
        }

        let transcription = try await whisperKit.transcribe(audioArray: samples, decodeOptions: options, callback: decodingCallback)
        return transcription
    }

    // MARK: - Streaming Logic

    func realtimeLoop() {
        transcriptionTask = Task {
            while isRecording && isTranscribing {
                do {
                    try await transcribeCurrentBuffer()
                } catch {
                    print("Error: \(error.localizedDescription)")
                    break
                }
            }
        }
        visualizeTask = Task {
            while isRecording && isTranscribing {
                do {
                    try await visualizeCurrentBuffer()
                } catch {
                    print("Error: \(error.localizedDescription)")
                    break
                }
            }
        }
    }

    func stopRealtimeTranscription() {
        isTranscribing = false
        transcriptionTask?.cancel()
    }

    func visualizeCurrentBuffer() async throws {
        guard let whisperKit = whisperKit else { return }
        
        let currentBuffer = whisperKit.audioProcessor.audioSamples.suffix(self.fftInResolution)
        
        async let fftMagnitudes = currentBuffer.withUnsafeBufferPointer { currentBufferPointer in
             return Self.fft(data: currentBufferPointer.baseAddress!,
                                              inResolution: self.fftInResolution,
                                              outResolution: self.fftOutResolution,
                                              setup: self.fftSetup)
        }
        
        async let rmsValue = currentBuffer.withUnsafeBufferPointer { currentBufferPointer in
            return Self.rms(data: currentBufferPointer.baseAddress!, frameLength: UInt(currentBuffer.count))
        }
        
        let fftLoudnessUnchecked : Float //could be infinite or NaN

        (self.fftMagnitudes, fftLoudnessUnchecked) = await (fftMagnitudes, rmsValue)
        
        self.fftLoudness = (fftLoudnessUnchecked.isNaN || fftLoudnessUnchecked.isInfinite) ? 0.0 : fftLoudnessUnchecked

        try await Task.sleep(nanoseconds: 20_000_000)
        
    }
    
    func transcribeCurrentBuffer() async throws {
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
            // Retrieve the current relative energy values from the audio processor
            let currentRelativeEnergy = whisperKit.audioProcessor.relativeEnergy

            // Calculate the number of energy values to consider based on the duration of the next buffer
            // Each energy value corresponds to 1 buffer length (100ms of audio), hence we divide by 0.1
            let energyValuesToConsider = Int(nextBufferSeconds / 0.1)

            // Extract the relevant portion of energy values from the currentRelativeEnergy array
            let nextBufferEnergies = currentRelativeEnergy.suffix(energyValuesToConsider)

            // Determine the number of energy values to check for voice presence
            // Considering up to the last 1 second of audio, which translates to 10 energy values
            let numberOfValuesToCheck = max(10, nextBufferEnergies.count - 10)

            // Check if any of the energy values in the considered range exceed the silence threshold
            // This indicates the presence of voice in the buffer
            let voiceDetected = nextBufferEnergies.prefix(numberOfValuesToCheck).contains { $0 > Float(self.appSettings.silenceThreshold) }

            // Only run the transcribe if the next buffer has voice
            guard voiceDetected else {
                await MainActor.run {
                    if currentText == "" {
                        currentText = "Waiting for speech..."
                    }
                }

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

        if self.appSettings.enableEagerDecoding {
            // Run realtime transcribe using word timestamps for segmentation
            let transcription = try await transcribeEagerMode(Array(currentBuffer))
            await MainActor.run {
                self.tokensPerSecond = transcription?.timings?.tokensPerSecond ?? 0
                self.firstTokenTime = transcription?.timings?.firstTokenTime ?? 0
                self.pipelineStart = transcription?.timings?.pipelineStart ?? 0
                self.currentLag = transcription?.timings?.decodingLoop ?? 0
                self.currentEncodingLoops = Int(transcription?.timings?.totalEncodingRuns ?? 0)

                let totalAudio = Double(currentBuffer.count) / Double(WhisperKit.sampleRate)
                self.totalInferenceTime = transcription?.timings?.fullPipeline ?? 0
                self.effectiveRealTimeFactor = Double(totalInferenceTime) / totalAudio
            }
        } else {
            // Run realtime transcribe using timestamp tokens directly
            let transcription = try await transcribeAudioSamples(Array(currentBuffer))

            // We need to run this next part on the main thread
            await MainActor.run {
                currentText = ""
                unconfirmedText = []
                guard let segments = transcription?.segments else {
                    return
                }

                self.tokensPerSecond = transcription?.timings?.tokensPerSecond ?? 0
                self.firstTokenTime = transcription?.timings?.firstTokenTime ?? 0
                self.pipelineStart = transcription?.timings?.pipelineStart ?? 0
                self.currentLag = transcription?.timings?.decodingLoop ?? 0
                self.currentEncodingLoops += Int(transcription?.timings?.totalEncodingRuns ?? 0)

                let totalAudio = Double(currentBuffer.count) / Double(WhisperKit.sampleRate)
                self.totalInferenceTime += transcription?.timings?.fullPipeline ?? 0
                self.effectiveRealTimeFactor = Double(totalInferenceTime) / totalAudio

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

    func transcribeEagerMode(_ samples: [Float]) async throws -> TranscriptionResult? {
        guard let whisperKit = whisperKit else { return nil }

        guard whisperKit.textDecoder.supportsWordTimestamps else {
            confirmedText = "Eager mode requires word timestamps, which are not supported by the current model: \(self.appSettings.selectedModel)."
            return nil
        }

        let languageCode = whisperKit.tokenizer?.languages[self.appSettings.selectedLanguage] ?? "en"
        let task: DecodingTask = self.appSettings.selectedTask == "transcribe" ? .transcribe : .translate

        let options = DecodingOptions(
            verbose: false,
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
                    return false
                }
            }
            if progress.avgLogprob! < options.logProbThreshold! {
                return false
            }

            return nil
        }

        Logging.info("[EagerMode] \(lastAgreedSeconds)-\(Double(samples.count)/16000.0) seconds")

        let streamingAudio = samples
        var streamOptions = options
        streamOptions.clipTimestamps = [lastAgreedSeconds]
        let lastAgreedTokens = lastAgreedWords.flatMap { $0.tokens }
        streamOptions.prefixTokens = lastAgreedTokens
        do {
            let transcription: TranscriptionResult? = try await whisperKit.transcribe(audioArray: streamingAudio, decodeOptions: streamOptions, callback: decodingCallback)
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
                            Logging.info("[EagerMode] Current:  \(lastAgreedSeconds) -> \(Double(samples.count) / 16000.0) \(currentWords)")
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
    
    // MARK: - Auto-sending Logic
    
    func startCountdown() {
        // Reset the countdown value to 10
        self.countdownValue = Float(self.countdownLimit)
        
        // Create and schedule the timer to fire every 1 second
        self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.countdownValue -= 1
            // When the countdown reaches zero, stop the timer
            if self.countdownValue <= 0 {
                self.timer?.invalidate()
                self.timer = nil
            }
        }
    }
    
    func resetCountdown() {
        // Invalidate and remove the timer
        self.timer?.invalidate()
        self.timer = nil
        // Reset the countdown value
        self.countdownValue = 0
    }
}


