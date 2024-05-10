//
//  WhisperView.swift
//  Brain
//
//  Created by Owen O'Malley on 4/12/24.
//

import SwiftUI
import WhisperKit

/*
struct MenuItem: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var image: String
}

struct WhisperView: View {
    
    @State private var showAdvancedOptions: Bool = false
    @State private var selectedCategoryId: MenuItem.ID?
    
    @State var whisper : Whisper = .init()
    
    private var menu = [
        MenuItem(name: "Transcribe", image: "book.pages"),
        MenuItem(name: "Stream", image: "waveform.badge.mic"),
    ]

    var body: some View {
        NavigationSplitView(columnVisibility: Binding.constant(.all)) {
            modelSelectorView
                .padding()
            Spacer()
            List(menu, selection: $selectedCategoryId) { item in
                HStack {
                    Image(systemName: item.image)
                    Text(item.name)
                        .font(.system(.title3))
                        .bold()
                }
            }
            .disabled(self.whisper.modelState != .loaded)
            .foregroundColor(self.whisper.modelState != .loaded ? .secondary : .primary)
            .navigationTitle("WhisperAX")
            .navigationSplitViewColumnWidth(min: 300, ideal: 350)
        } detail: {
            VStack {
                #if os(iOS)
                modelSelectorView
                    .padding()
                transcriptionView
                #elseif os(macOS)
                VStack(alignment: .leading) {
                    transcriptionView
                }
                .padding()
                #endif
                controlsView
            }
            .toolbar(content: {
                ToolbarItem {
                    Button {
                        let fullTranscript = formatSegments(self.whisper.confirmedSegments + self.whisper.unconfirmedSegments, withTimestamps: self.whisper.appSettings.enableTimestamps).joined(separator: "\n")
                        #if os(iOS)
                        UIPasteboard.general.string = fullTranscript
                        #elseif os(macOS)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(fullTranscript, forType: .string)
                        #endif
                    } label: {
                        Label("Copy Text", systemImage: "doc.on.doc")
                    }
                    .foregroundColor(.primary)
                    .frame(minWidth: 0, maxWidth: .infinity)
                }
            })
        }
        .onAppear {
            #if os(macOS)
            selectedCategoryId = menu.first(where: { $0.name == self.whisper.appSettings.selectedTab })?.id
            #endif
            self.whisper.fetchModels()
        }
    }

    // MARK: - Transcription

    var transcriptionView: some View {
        VStack {
            ScrollView(.horizontal) {
                HStack(spacing: 1) {
                    let startIndex = max(self.whisper.bufferEnergy.count - 300, 0)
                    ForEach(Array(self.whisper.bufferEnergy.enumerated())[startIndex...], id: \.element) { _, energy in
                        ZStack {
                            RoundedRectangle(cornerRadius: 2)
                                .frame(width: 2, height: CGFloat(energy) * 24)
                        }
                        .frame(maxHeight: 24)
                        .background(energy > Float(self.whisper.appSettings.silenceThreshold) ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                    }
                }
            }
            .defaultScrollAnchor(.trailing)
            .frame(height: 24)
            .scrollIndicators(.never)
            ScrollView {
                VStack(alignment: .leading) {
                    if self.whisper.appSettings.enableEagerDecoding {
                        let timestampText = (self.whisper.appSettings.enableTimestamps && self.whisper.eagerResults.first != nil) ? "[\(String(format: "%.2f", self.whisper.eagerResults.first??.segments.first?.start ?? 0)) --> \(String(format: "%.2f", self.whisper.lastAgreedSeconds))]" : ""
                        Text("\(timestampText) \(Text(self.whisper.confirmedText).fontWeight(.bold))\(Text(self.whisper.hypothesisText).fontWeight(.bold).foregroundColor(.gray))")
                            .font(.headline)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if self.whisper.appSettings.enableDecoderPreview {
                            Text("\(self.whisper.currentText)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top)
                        }
                    } else {
                        ForEach(Array(self.whisper.confirmedSegments.enumerated()), id: \.element) { _, segment in
                            let timestampText = self.whisper.appSettings.enableTimestamps ? "[\(String(format: "%.2f", segment.start)) --> \(String(format: "%.2f", segment.end))]" : ""
                            Text(timestampText + segment.text)
                                .font(.headline)
                                .fontWeight(.bold)
                                .tint(.green)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        ForEach(Array(self.whisper.unconfirmedSegments.enumerated()), id: \.element) { _, segment in
                            let timestampText = self.whisper.appSettings.enableTimestamps ? "[\(String(format: "%.2f", segment.start)) --> \(String(format: "%.2f", segment.end))]" : ""
                            Text(timestampText + segment.text)
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if self.whisper.appSettings.enableDecoderPreview {
                            Text("\(self.whisper.unconfirmedText.joined(separator: "\n"))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(self.whisper.currentText)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .defaultScrollAnchor(.bottom)
            .padding()
            if let whisper = self.whisper.whisperKit,
               !self.whisper.isRecording,
               !self.whisper.isTranscribing,
               whisper.progress.fractionCompleted > 0,
               whisper.progress.fractionCompleted < 1 {
                ProgressView(whisper.progress)
                    .progressViewStyle(.linear)
                    .labelsHidden()
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Models

    var modelSelectorView: some View {
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

                if self.whisper.modelState == .unloaded {
                    Divider()
                    Button {
                        self.whisper.resetState()
                        self.whisper.loadModel(self.whisper.appSettings.selectedModel)
                        self.whisper.modelState = .loading
                    } label: {
                        Text("Load Model")
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                    }
                    .buttonStyle(.borderedProminent)
                } else if self.whisper.loadingProgressValue < 1.0 {
                    VStack {
                        HStack {
                            ProgressView(value: self.whisper.loadingProgressValue, total: 1.0)
                                .progressViewStyle(LinearProgressViewStyle())
                                .frame(maxWidth: .infinity)

                            Text(String(format: "%.1f%%", self.whisper.loadingProgressValue * 100))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        if self.whisper.modelState == .prewarming {
                            Text("Specializing \(self.whisper.appSettings.selectedModel) for your device...\nThis can take several minutes on first load")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Controls

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
    
    var controlsView: some View {
        VStack {
            basicSettingsView
            if let selectedCategoryId, let item = menu.first(where: { $0.id == selectedCategoryId }) {
                switch item.name {
                    case "Stream":
                        VStack {
                            HStack {
                                Button {
                                    self.whisper.resetState()
                                } label: {
                                    Label("Reset", systemImage: "arrow.clockwise")
                                }
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .buttonStyle(.borderless)

                                Spacer()

                                audioDevicesView

                                Spacer()

                                VStack {
                                    Button {
                                        showAdvancedOptions.toggle()
                                    } label: {
                                        Label("Settings", systemImage: "slider.horizontal.3")
                                    }
                                    .frame(minWidth: 0, maxWidth: .infinity)
                                    .buttonStyle(.borderless)
                                }
                            }

                            ZStack {
                                Button {
                                    withAnimation {
                                        self.whisper.toggleRecording(shouldLoop: true)
                                    }
                                } label: {
                                    Image(systemName: !self.whisper.isRecording ? "record.circle" : "stop.circle.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 70, height: 70)
                                        .padding()
                                        .foregroundColor(self.whisper.modelState != .loaded ? .gray : .red)
                                }
                                .contentTransition(.symbolEffect(.replace))
                                .buttonStyle(BorderlessButtonStyle())
                                .disabled(self.whisper.modelState != .loaded)
                                .frame(minWidth: 0, maxWidth: .infinity)

                                VStack {
                                    Text("Encoder runs: \(self.whisper.currentEncodingLoops)")
                                        .font(.caption)
                                    Text("Decoder runs: \(self.whisper.currentDecodingLoops)")
                                        .font(.caption)
                                }
                                .offset(x: -120, y: 0)

                                if self.whisper.isRecording {
                                    Text("\(String(format: "%.1f", self.whisper.bufferSeconds)) s")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .offset(x: 80, y: 0)
                                }
                            }
                        }
                    default:
                        EmptyView()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .sheet(isPresented: $showAdvancedOptions, content: {
            advancedSettingsView
                .presentationDetents([.medium, .large])
                .presentationBackgroundInteraction(.enabled)
                .presentationContentInteraction(.scrolls)
        })
    }

    var basicSettingsView: some View {
        VStack {
            HStack {
                Picker("", selection: self.whisper.appSettings.$selectedTask) {
                    ForEach(DecodingTask.allCases, id: \.self) { task in
                        Text(task.description.capitalized).tag(task.description)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .disabled(!(self.whisper.whisperKit?.modelVariant.isMultilingual ?? false))
            }
            .padding(.horizontal)

            LabeledContent {
                Picker("", selection: self.whisper.appSettings.$selectedLanguage) {
                    ForEach(self.whisper.availableLanguages, id: \.self) { language in
                        Text(language.description).tag(language.description)
                    }
                }
                .disabled(!(self.whisper.whisperKit?.modelVariant.isMultilingual ?? false))
            } label: {
                Label("Language", systemImage: "globe")
            }
            .padding(.horizontal)
            .padding(.top)

            HStack {
                Text(self.whisper.effectiveRealTimeFactor.formatted(.number.precision(.fractionLength(3))) + " RTF")
                    .font(.system(.body))
                    .lineLimit(1)
                Spacer()
                Text(self.whisper.tokensPerSecond.formatted(.number.precision(.fractionLength(0))) + " tok/s")
                    .font(.system(.body))
                    .lineLimit(1)
                Spacer()
                Text("First token: " + (self.whisper.firstTokenTime - self.whisper.pipelineStart).formatted(.number.precision(.fractionLength(2))) + "s")
                    .font(.system(.body))
                    .lineLimit(1)
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
    }

    var advancedSettingsView: some View {
        #if os(iOS)
        NavigationView {
            settingsForm
                .navigationBarTitleDisplayMode(.inline)
        }
        #else
        VStack {
            Text("Decoding Options")
                .font(.title2)
                .padding()
            settingsForm
                .frame(minWidth: 500, minHeight: 500)
        }
        #endif
    }

    var settingsForm: some View {
        List {
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

            HStack {
                Text("Show Decoder Preview")
                InfoButton("Toggling this will show a small preview of the decoder output in the UI under the transcribe. This can be useful for debugging.")
                Spacer()
                Toggle("", isOn: self.whisper.appSettings.$enableDecoderPreview)
            }
            .padding(.horizontal)

            HStack {
                Text("Prompt Prefill")
                InfoButton("When Prompt Prefill is on, it will force the task, language, and timestamp tokens in the decoding loop. \nToggle it off if you'd like the model to generate those tokens itself instead.")
                Spacer()
                Toggle("", isOn: self.whisper.appSettings.$enablePromptPrefill)
            }
            .padding(.horizontal)

            HStack {
                Text("Cache Prefill")
                InfoButton("When Cache Prefill is on, the decoder will try to use a lookup table of pre-computed KV caches instead of computing them during the decoding loop. \nThis allows the model to skip the compute required to force the initial prefill tokens, and can speed up inference")
                Spacer()
                Toggle("", isOn: self.whisper.appSettings.$enableCachePrefill)
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
                Text("Max Fallback Count:")
                HStack {
                    Slider(value: self.whisper.appSettings.$fallbackCount, in: 0...5, step: 1)
                    Text(self.whisper.appSettings.fallbackCount.formatted(.number))
                        .frame(width: 30)
                    InfoButton("Controls how many times the decoder will fallback to a higher temperature if any of the decoding thresholds are exceeded.\n Higher values will cause the decoder to run multiple times on the same audio, which can improve accuracy at the cost of speed.")
                }
            }
            .padding(.horizontal)

            VStack {
                Text("Compression Check Tokens")
                HStack {
                    Slider(value: self.whisper.appSettings.$compressionCheckWindow, in: 0...100, step: 5)
                    Text(self.whisper.appSettings.compressionCheckWindow.formatted(.number))
                        .frame(width: 30)
                    InfoButton("Amount of tokens to use when checking for whether the model is stuck in a repetition loop.\nRepetition is checked by using zlib compressed size of the text compared to non-compressed value.\n Lower values will catch repetitions sooner, but too low will miss repetition loops of phrases longer than the window.")
                }
            }
            .padding(.horizontal)

            VStack {
                Text("Max Tokens Per Loop")
                HStack {
                    Slider(value: self.whisper.appSettings.$sampleLength, in: 0...Double(min(self.whisper.whisperKit?.textDecoder.kvCacheMaxSequenceLength ?? WhisperKit.maxTokenContext, WhisperKit.maxTokenContext)), step: 10)
                    Text(self.whisper.appSettings.sampleLength.formatted(.number))
                        .frame(width: 30)
                    InfoButton("Maximum number of tokens to generate per loop.\nCan be lowered based on the type of speech in order to further prevent repetition loops from going too long.")
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

            Section(header: Text("Experimental")) {
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
        }
        .navigationTitle("Decoding Options")
        .toolbar(content: {
            ToolbarItem {
                Button {
                    showAdvancedOptions = false
                } label: {
                    Label("Done", systemImage: "xmark.circle.fill")
                        .foregroundColor(.primary)
                }
            }
        })
    }
}

fileprivate struct TestView : View {
    @State var whisper : Whisper = .init()
    
    var body : some View {
        WhisperView()
            .environment(self.whisper)
    }
    
}

#Preview {
    TestView()
}
*/
