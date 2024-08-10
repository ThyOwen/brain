//
//  VoiceGenerator.swift
//  Sal
//
//  Created by Owen O'Malley on 6/24/24.
//

import Foundation
import Observation
import AVFAudio
import SwiftUI

import func Accelerate.vecLib.vDSP.vDSP_rmsqv
import struct Accelerate.vecLib.vDSP.vDSP_Length

import enum WhisperKit.ModelState

public enum ESpeakError : Error {
    case couldNotLoadVoice
}

@Observable public final class ESpeak {
    
    private var startupAudioPlayer : AVAudioPlayer? = nil //just for startup sound
    
    public var modelState : ModelState = .unloaded
    
    public let synthesizer : AVSpeechSynthesizer = .init()
    public var voice : AVSpeechSynthesisVoice? = nil
    
    private let format : AVAudioFormat = .init(commonFormat: .pcmFormatFloat32, sampleRate: 22050, channels: 1, interleaved: true)!
        
    public var audioPlayer : AVAudioPlayerNode = .init()
    public var audioEngine : AVAudioEngine? = nil
    
#if os(iOS)
    private let audioSession = AVAudioSession.sharedInstance()
#endif
    let langID: String = "gmw/en-US"
    let voiceID: String = "UniRobot"
    static let voiceCode: String = "gmw.en-US.UniRobot"
    
    private var timerTask : Task<Void,Never>? = nil
    
    private var timeUntilFinished : Double = 0
    public var isSalSpeaking : Bool { self.timeUntilFinished != 0 }
    
    private var messageBoard : MessageBoardManager
    private var wave : WaveManager
    
    init(messageBoard : MessageBoardManager, wave : WaveManager) {
        self.messageBoard = messageBoard
        self.wave = wave
    }
    
    deinit {
        self.audioEngine?.stop()
        self.timerTask?.cancel()
#if os(iOS)
        //try? audioSession.setActive(false)
#endif
    }

    //MARK: - Loading Stuff

    public func loadModel() async throws {
        
        let audioEngine = AVAudioEngine.init()
        self.audioPlayer = AVAudioPlayerNode.init()
        
        self.timerTask = nil
        await MainActor.run {
            self.modelState = .loading
        }
        
        let voice = AVSpeechSynthesisVoice.speechVoices().first { voiceInArray in
            return voiceInArray.identifier == "duck.Sal.ESpeakExtension.auto.en-us.UniRobot"
            //return voiceInArray.identifier == "com.apple.ttsbundle.siri_Helena_de-DE_compact"
            //return voiceInArray.identifier.components(separatedBy: ".").last == "UniRobot"

        }
        
        guard let voice else {
            throw ESpeakError.couldNotLoadVoice
        }
        
        self.voice = voice
        
        
#if os(iOS)
        try? audioSession.setCategory(
            .playback,
            mode: .spokenAudio,
            policy: .default,
            options: [.duckOthers]
        )
#endif

        
        audioEngine.attach(self.audioPlayer)
        
        audioEngine.connect(self.audioPlayer, to: audioEngine.mainMixerNode, format: self.format)
        
        audioEngine.mainMixerNode.installTap(onBus: 0, bufferSize: 512, format: self.format) { [weak self]  buffer, time in
            if let samplesBufferPointer = buffer.floatChannelData?.pointee {
                var rmsEnergy : Float = 0.0
                    
                withUnsafeMutablePointer(to: &rmsEnergy) { rmsEnergyPointer in
                    vDSP_rmsqv(samplesBufferPointer, 1, rmsEnergyPointer, vDSP_Length(64))
                }
                
                self?.wave.updateEspeakBuffer(samplesBufferPointer, volume: rmsEnergy)
            }
        }
        
        audioEngine.prepare()

        try audioEngine.start()
        
        if let isRunning = self.audioEngine?.isRunning, !isRunning {
            self.audioEngine?.stop()
        }
        
        self.audioEngine = consume audioEngine
        
        await MainActor.run {
            self.modelState = .loaded
        }
    }
    
    public func generateSpeech(with text : consuming String) {
        let request = AVSpeechUtterance(string: text)
        
        request.voice = self.voice

        //self.synthesizer.speak(request)

        self.synthesizer.write(request) { audioBuffer in
            
            guard let PCMBuffer = audioBuffer as? AVAudioPCMBuffer, PCMBuffer.frameLength != 0 else {
                self.messageBoard.postTemporaryMessage("error | voice box format is incorrect", duration: 5)
                return
            }
            
            let durationOfBuffer = Double(PCMBuffer.frameLength) / (PCMBuffer.format.sampleRate)
            
            self.timeUntilFinished += durationOfBuffer
            
            self.audioPlayer.scheduleBuffer(PCMBuffer, completionCallbackType: .dataConsumed) { _ in
                if self.timerTask == nil {
                    self.timerTask = Task {
                        //try? await Task.sleep(nanoseconds: 50_000_000)
                        while self.timeUntilFinished != 0 {
                            do {
                                try await self.updateTimer()
                            } catch let error {
                                self.messageBoard.postTemporaryMessage("error | \(error.localizedDescription)", duration: 6)
                            }
                        }
                        
                        print("done")
                        self.timerTask = nil
                    }
                }
            }

            
        } toMarkerCallback: { syntheisMarkerArray in
            print(syntheisMarkerArray.count)
        }
        
        self.audioPlayer.play()
        

    }
    
    private func updateTimer() async throws {
        let candidate = self.timeUntilFinished - 0.05
        
        switch candidate {
        case 0:
            self.audioPlayer.stop()
        case ..<0:
            self.timeUntilFinished = 0
            self.audioPlayer.stop()
        default:
            self.timeUntilFinished = consume candidate
            try await Task.sleep(nanoseconds: 50_000_000)
        }

    }
    
    //MARK: - startup sound
    
    public func playStartup() {
        guard let soundURL = Bundle.main.url(forResource: "startup2", withExtension: "aif") else {
            return
        }

        self.startupAudioPlayer = try? AVAudioPlayer(contentsOf: soundURL)

        self.startupAudioPlayer?.play()
    }
}


fileprivate struct TestView : View {
    @State private var espeak : ESpeak = .init(messageBoard: .init(), wave: .init())
    
    var body: some View {
        ZStack {

            Rectangle()
                .fill(.mainAccent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack {
                
                if self.espeak.modelState != .loaded {
                    ProgressView()
                }
                
                Button {
                    self.espeak.generateSpeech(with: "hello. how are you today? This is mighty strange")
                    
                } label: {
                    Text("speak")
                }
            }
        }
        .onAppear {
            Task {
                try? await self.espeak.loadModel()
            }
        }
    }
}

#Preview {
    TestView()
}
