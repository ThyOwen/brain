//
//  MicrophoneButtonView.swift
//  Brain
//
//  Created by Owen O'Malley on 4/21/24.
//

import SwiftUI
import WhisperKit

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
}

struct MicrophoneButtonView: View {
    
    @Environment(Whisper.self) private var whisper
    
    private var micIcon : String { self.whisper.isTranscribing || self.whisper.isRecording ? "stop.circle.fill" : "mic.fill" }

    private var modelLoaded : Bool {
        !(self.whisper.modelState == .unloaded || self.whisper.modelState == .loaded)
    }
    
    var audioDevicesView: some View {
        Group {
            #if os(macOS)
            HStack {
                if let audioDevices = self.whisper.audioDevices, self.whisper.audioDevices?.count ?? 0 > 0 {
                    Picker("", selection: self.whisper.appSettings.$selectedAudioInput) {
                        ForEach(audioDevices, id: \.self) { device in
                            Text(device.name).tag(device.name)
                        }
                    }
                    .frame(width: 250)
                    .disabled(self.whisper.isRecording)
                }
            }
            .onAppear {
                self.whisper.audioDevices = AudioProcessor.getAudioDevices()
                if let audioDevices = self.whisper.audioDevices,
                   !audioDevices.isEmpty,
                   self.whisper.appSettings.selectedAudioInput == "No Audio Input",
                   let device = audioDevices.first {
                    self.whisper.appSettings.selectedAudioInput = device.name
                }
            }
            #endif
        }
    }
    
    var button: some View {
        ZStack {
            
            Capsule()
                .inset(by: 5)
                .fill(
                    LinearGradient(colors: [.orange, .red,],
                                   startPoint: .init(x: 0, y: 0),
                                   endPoint: .init(x: 1, y: 1))
                )
            
            Capsule()
                .inset(by: 20)
                .fill(
                    LinearGradient(colors: [.red, .orange],
                                   startPoint: .init(x: 0, y: 0),
                                   endPoint: .init(x: 1, y: 1))
                )
            
            if self.whisper.modelState == .unloaded {
                Text("Load Model")
                    .rotationEffect(.degrees(-90))
                    .fixedSize()
                    .frame(width: 20, height: 100)
                    .foregroundStyle(.darkShadow)
                    .fontWeight(.bold)
            } else if self.whisper.loadingProgressValue < 1.0 {
                VStack {
                    /*
                    ProgressView(value: self.whisper.loadingProgressValue, total: 1.0)
                        .progressViewStyle(.circular)
                        .frame(maxWidth: .infinity)
                     */

                    Text(String(format: "%.1f%%", self.whisper.loadingProgressValue * 100))
                        .font(.caption)
                        .foregroundColor(.darkShadow)
                }
            } else {
                Image(systemName: self.micIcon)
                    .foregroundStyle(.darkShadow)
                    .imageScale(.large)
                    .opacity(0.6)
            }
        }
    }
    
    var body: some View {
        
        ZStack {
            Capsule()
                .strokeBorder(LinearGradient(colors: [.darkShadow, .lightShadow],
                                     startPoint: .topLeading,
                                     endPoint: .bottomTrailing), lineWidth: 5)
            
            Capsule()
                .inset(by: 3)
                .fill(.black)
            
            Button {
                    if self.whisper.modelState == .unloaded {
                        self.whisper.resetState()
                        self.whisper.loadModel(self.whisper.appSettings.selectedModel)
                        self.whisper.modelState = .loading
                    } else {
                        self.whisper.toggleRecording(shouldLoop: true)
                    }
                } label: {
                    self.button
                }
            /*
             .softButtonStyle(Capsule(),
             mainColor: .mainAccent,
             darkShadowColor: .darkShadow,//.red.opacity(0.7),
             lightShadowColor: .lightShadow,//.orange.opacity(0.7),
             pressedEffect: .flat)
             */
            .scaleButtonStyle()
            .disabled(self.modelLoaded)
            .animation(.spring, value: self.modelLoaded)
            .onAppear {
            #if os(macOS)
                self.whisper.fetchModels()
                self.whisper.audioDevices = AudioProcessor.getAudioDevices()
                if let audioDevices = self.whisper.audioDevices,
                   !audioDevices.isEmpty,
                   self.whisper.appSettings.selectedAudioInput == "No Audio Input",
                   let device = audioDevices.first {
                    self.whisper.appSettings.selectedAudioInput = device.name
                }
            #endif
            }
        }
    }
    
    
}


fileprivate struct TestView : View {
    
    static let whisper = Whisper()
    
    var body: some View {
        ZStack {
            Color.mainAccent.ignoresSafeArea()
            MicrophoneButtonView()
                .frame(width: 150, height: 200)
        }.environment(Self.whisper)
    }
}

#Preview {
    TestView()
}
