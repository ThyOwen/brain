//
//  SettingsView.swift
//  Brain
//
//  Created by Owen O'Malley on 4/15/24.
//

import SwiftUI
import WhisperKit
/*
struct InfoButton: View {
    var infoText: String
    @State private var showInfo = false
    
    init(_ infoText: String) {
        self.infoText = infoText
    }
    var body: some View {
        Button(action: {
            self.showInfo = true
        }) {
            Image(systemName: "info.circle")
                .foregroundColor(.blue)
        }
        .popover(isPresented: $showInfo) {
            Text(infoText)
                .padding()
        }
        .buttonStyle(BorderlessButtonStyle())
    }
}

struct WhisperSettingsView: View {
    
    @State var showAdvancedOptions : Bool = false
    
    @Binding var whisper : Whisper
    
    var whisperSettings: some View {
        List {
            
            Section(header: Text("Whisper Settings")) {
                HStack {
                    Text("Show Timestamps")
                    InfoButton("Toggling this will include/exclude timestamps in both the UI and the prefill tokens.\nEither <|notimestamps|> or <|0.00|> will be forced based on this setting unless \"Prompt Prefill\" is de-selected.")
                    Spacer()
                    Toggle("", isOn: self.whisper.appSettings.$enableTimestamps)
                }
                .padding(.horizontal)
                
                HStack {
                    Text("Special Characters")
                    InfoButton("Toggling this will include/exclude special characters in the transcription text.")
                    Spacer()
                    Toggle("", isOn: self.whisper.appSettings.$enableSpecialCharacters)
                }
                .padding(.horizontal)
                
                VStack {
                    Text("Starting Temperature:")
                    HStack {
                        Slider(value: self.whisper.appSettings.$temperatureStart, in: 0...1, step: 0.1)
                        Text(self.whisper.appSettings.temperatureStart.formatted(.number))
                        InfoButton("Controls the initial randomness of the decoding loop token selection.\nA higher temperature will result in more random choices for tokens, and can improve accuracy.")
                    }
                }
                .padding(.horizontal)
                
                VStack {
                    Text("Silence Threshold")
                    HStack {
                        Slider(value: self.whisper.appSettings.$silenceThreshold, in: 0...1, step: 0.05)
                        Text(self.whisper.appSettings.silenceThreshold.formatted(.number))
                            .frame(width: 30)
                        InfoButton("Relative silence threshold for the audio. \n Baseline is set by the quietest 100ms in the previous 2 seconds.")
                    }
                }
                .padding(.horizontal)
                
                HStack {
                    Text("Eager Streaming Mode")
                    InfoButton("When Eager Streaming Mode is on, the transcription will be updated more frequently, but with potentially less accurate results.")
                    Spacer()
                    Toggle("", isOn: self.whisper.appSettings.$enableEagerDecoding)
                }
                .padding(.horizontal)
                .padding(.top)

                VStack {
                    Text("Token Confirmations")
                    HStack {
                        Slider(value: self.whisper.appSettings.$tokenConfirmationsNeeded, in: 1...10, step: 1)
                        Text(self.whisper.appSettings.tokenConfirmationsNeeded.formatted(.number))
                            .frame(width: 30)
                        InfoButton("Controls the number of consecutive tokens required to agree between decoder loops before considering them as confirmed in the streaming process.")
                    }
                }
                .padding(.horizontal)
                
            }
                .listRowBackground(Color.mainAccent)
        }
        .navigationTitle("Decoding Options")
        .background(Color.mainAccent.opacity(0.5))
        .scrollContentBackground(.hidden)
        
    }
    
    
    
    var body: some View {
        whisperSettings
        Group {
            VStack {
                HStack {
                    Image(systemName: "circle.fill")
                        .foregroundStyle(self.whisper.modelState == .loaded ? .green : (self.whisper.modelState == .unloaded ? .red : .yellow))
                        .symbolEffect(.variableColor, isActive: self.whisper.modelState != .loaded && self.whisper.modelState != .unloaded)
                    Text(self.whisper.modelState.description)

                    Spacer()

                    if self.whisper.availableModels.count > 0 {
                        Picker("", selection: self.whisper.appSettings.$selectedModel) {
                            ForEach(self.whisper.availableModels, id: \.self) { model in
                                HStack {
                                    let modelIcon = self.whisper.localModels.contains { $0 == model.description } ? "checkmark.circle" : "arrow.down.circle.dotted"
                                    Text("\(Image(systemName: modelIcon)) \(model.description.components(separatedBy: "_").dropFirst().joined(separator: " "))").tag(model.description)
                                }
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .onChange(of: self.whisper.appSettings.selectedModel, initial: false) { _, _ in
                            self.whisper.modelState = .unloaded
                        }
                    } else {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.5)
                    }
                    
                    Button(action: {
                        self.whisper.deleteModel()
                    }, label: {
                        Image(systemName: "trash")
                    })
                    .help("Delete model")
                    .buttonStyle(BorderlessButtonStyle())
                    .disabled(self.whisper.localModels.count == 0)
                    .disabled(!self.whisper.localModels.contains(self.whisper.appSettings.selectedModel))

                    #if os(macOS)
                    Button(action: {
                        let folderURL = self.whisper.whisperKit?.modelFolder ?? (self.whisper.localModels.contains(self.whisper.appSettings.selectedModel) ? URL(fileURLWithPath: self.whisper.localModelPath) : nil)
                        if let folder = folderURL {
                            NSWorkspace.shared.open(folder)
                        }
                    }, label: {
                        Image(systemName: "folder")
                    })
                    .buttonStyle(BorderlessButtonStyle())
                    #endif
                    Button(action: {
                        if let url = URL(string: "https://huggingface.co/\(self.whisper.appSettings.repoName)") {
                            #if os(macOS)
                            NSWorkspace.shared.open(url)
                            #else
                            UIApplication.shared.open(url)
                            #endif
                        }
                    }, label: {
                        Image(systemName: "link.circle")
                    })
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
        }
    
    }
}

#Preview {
    WhisperSettingsView()
}
*/
