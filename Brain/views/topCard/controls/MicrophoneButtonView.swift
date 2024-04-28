//
//  MicrophoneButtonView.swift
//  Brain
//
//  Created by Owen O'Malley on 4/21/24.
//

import SwiftUI
import WhisperKit

struct MicrophoneButtonView: View {
    
    @State public var whisper : Whisper
    
    private var micIcon : String { self.whisper.isTranscribing ? "stop.circle.fill" : "mic.fill" }

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
                .fill(
                    LinearGradient(colors: [.orange, .red,],
                                   startPoint: .init(x: 0, y: 0),
                                   endPoint: .init(x: 1, y: 1))
                )
            
            Capsule()
                .inset(by: 15)
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
                    .foregroundStyle(.gray)
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
                        .foregroundColor(.gray)
                }
            } else {
                Image(systemName: self.micIcon)
                    .foregroundStyle(.gray)
                    .imageScale(.large)
                    .opacity(0.6)
            }
        }
    }
    
    var body: some View {
        Button(
            action: {
                if self.whisper.modelState == .unloaded {
                    self.whisper.resetState()
                    self.whisper.loadModel(self.whisper.appSettings.selectedModel)
                    self.whisper.modelState = .loading
                } else {
                    self.whisper.toggleRecording(shouldLoop: true)
                }
            },
            
            label: {
                self.button
            }
        )
        .softButtonStyle(Capsule(),
                         mainColor: .mainAccent,
                         darkShadowColor: .darkShadow,//.red.opacity(0.7),
                         lightShadowColor: .lightShadow,//.orange.opacity(0.7),
                         pressedEffect: .flat)
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



#Preview {
    ZStack {
        Color.mainAccent.ignoresSafeArea()
        MicrophoneButtonView(whisper: Whisper())
            .frame(width: 120, height: 150)
    }
}
