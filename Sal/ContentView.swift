//
//  ContentView.swift
//  chatbot
//
//  Created by Owen O'Malley on 8/13/23.
//

import SwiftUI
import WhisperKit

public struct TVViewState {
    
    public var selectedChatHistoryIndex : Int = 0 
    public var selectedChatMessageIndex : Int = 0
    
    public var showSalSignature : Bool = false
    public var showWaveOrChat : Bool = true
    public var displayType : DisplayType = .none
    public var controlsType : ControlsType = .main
    
    public enum DisplayType {
        case none
        case salSignature
        case waveAndActiveChatMessages
        case historicChatMessages
        case chatHistory
    }
    
    public enum ControlsType {
        case main
        case history
    }
}

struct ContentView: View {
    
    @Environment(ChatViewModel.self) private var chatViewModel
    
    @State private var isPanel : Bool = true
    
    @State private var tvViewState : TVViewState = .init()

    @Namespace private var pannelAnimation

    var audioDevicesView: some View {
        Group {
            #if os(macOS)
            HStack {
                if let audioDevices = self.chatViewModel.whisper.audioDevices, audioDevices.count > 0 {
                    Picker("", selection: self.chatViewModel.whisper.appSettings.$selectedAudioInput) {
                        ForEach(audioDevices, id: \.self) { device in
                            Text(device.name).tag(device.name)
                        }
                    }
                    .frame(width: 250)
                    .disabled(self.chatViewModel.whisper.isRecording)
                }
            }
            .onAppear {
                self.chatViewModel.whisper.audioDevices = AudioProcessor.getAudioDevices()
                if let audioDevices = self.chatViewModel.whisper.audioDevices,
                   !audioDevices.isEmpty,
                   self.chatViewModel.whisper.appSettings.selectedAudioInput == "No Audio Input",
                   let device = audioDevices.first
                {
                    self.chatViewModel.whisper.appSettings.selectedAudioInput = device.name
                }
            }
            #endif
        }
    }
    
    var salSignaturePath : some View {
        LoadingPath()
            .trim(from: 0.0, to: self.tvViewState.showSalSignature ? 1.0 : 0.0)
            .stroke(Color.lime, style: .init(lineWidth: 1.75, lineCap: .round))
            //.animation(.easeInOut(duration: 3), value: self.showSalSignature)
    }
    
    var karenVisualizerPath : some View {
        KarenWave(fftMagnitudes: self.chatViewModel.wave.fftMagnitudes, volume: self.chatViewModel.wave.volume)
            .stroke(Color.lime.gradient,
                    style: StrokeStyle(lineWidth: 1.75, lineCap: .round))
    }
    
    var tv : some View {
        TVView {
            switch self.tvViewState.displayType {
            case .none:
                Text("Awaiting Activation")
                    .font(.custom("zig", size: 16))
                    .foregroundStyle(.white)
                    .blur(radius: 0.75, opaque: false)
            case .salSignature:
                self.salSignaturePath
                    .blur(radius: 1.75, opaque: false)
                self.salSignaturePath
                    .blur(radius: 0.75, opaque: false)
            case .waveAndActiveChatMessages:
                if self.tvViewState.showWaveOrChat {
                    self.karenVisualizerPath
                        .blur(radius: 1.75, opaque: false)
                    self.karenVisualizerPath
                        .blur(radius: 0.75, opaque: false)
                } else {
                    if let chat = self.chatViewModel.chat.activeChat {
                        ChatMessagesView(tvViewState: self.$tvViewState, chat: chat)
                            .padding(.horizontal, 25)
                            .blur(radius: 0.45)
                    } else {
                        Text("there is no active chat")
                            .font(.custom("zig", size: 12))
                            .foregroundStyle(.white)
                            .blur(radius: 0.55)
                    }
                }
            case .chatHistory:
                if !self.chatViewModel.chat.chatHistory.isEmpty {
                    ChatHistoryView(tvViewState: self.$tvViewState)
                        .padding(.horizontal, 25)
                        .blur(radius: 0.55, opaque: false)
                } else {
                    Text("there is no chat history")
                        .font(.custom("zig", size: 12))
                        .foregroundStyle(.white)
                        .blur(radius: 0.55)
                }
            case .historicChatMessages:
                ChatMessagesView(tvViewState: self.$tvViewState, chat: self.chatViewModel.chat.chatHistory[self.tvViewState.selectedChatHistoryIndex])
                    .padding(.horizontal, 25)
                    .blur(radius: 0.45)
            }
        }
        //.fixedSize(horizontal: false, vertical: true)
        .aspectRatio(1.2, contentMode: .fit)
        .animation(.linear(duration: 0.2), value: self.tvViewState.showWaveOrChat)
        .matchedGeometryEffect(id: "TV", in: self.pannelAnimation, properties: .frame)
        .transition(.offset())
        .zIndex(1)
        .onChange(of: self.tvViewState.displayType) { oldValue, newValue in
            
            switch newValue {
            case .salSignature:
                withAnimation(.easeInOut(duration: 3)) {
                    self.tvViewState.showSalSignature = true
                }
            default:
                self.tvViewState.showSalSignature = false
            }
        }
        .padding(.init(top: 0,
                       leading: self.isPanel ? 20 : 00,
                       bottom: 0,
                       trailing: self.isPanel ? 20 : 00))
    }
    
    var volumeIndicator : some View {
        MicrophoneIndicatorView(energyLevel: self.chatViewModel.whisper.lastBufferEnergy,
                                threshold: self.chatViewModel.whisper.appSettings.silenceThreshold,
                                isActive: self.chatViewModel.whisper.isTranscribing)
        .frame(width: 300, height: 3)
        .matchedGeometryEffect(id: "indicator", in: pannelAnimation)
    }
    
    var statusView : some View {
        ZStack {
            Capsule()
                .fill(.secondAccent)
                .outerShadow(darkShadow: .darkShadow,
                             lightShadow: .lightShadow,
                             offset: 2,
                             radius: 4)
            Capsule()
                .inset(by: 3)
                .fill(.black)
                .outerShadow(darkShadow: .darkShadow,
                             lightShadow: .lightShadow,
                             offset: 2,
                             radius: 4)
            
            ZStack {
                Capsule()
                    .inset(by: 4)
                    .fill(.black)
                MessageBoardView(fontSize: 14)
            }
            .colorEffect(ShaderLibrary.coloredNoise(.float(0.35)))
                
        }
        .innerShadow(Capsule().inset(by: 4),
                     darkShadow: .tvLightHaze,
                     lightShadow: .black.opacity(0.7),
                     spread: 0.9,
                     radius: 4)
        .frame(height: 40)
        
        .zIndex(-1)
        
    }
    
    var whisperInfoView : some View {
        HStack {
            Text(self.chatViewModel.whisper.effectiveRealTimeFactor.formatted(.number.precision(.fractionLength(3))) + " RTF")
                .font(.body)
                .lineLimit(1)
            Text(self.chatViewModel.whisper.tokensPerSecond.formatted(.number.precision(.fractionLength(0))) + " tok/s")
                .font(.body)
                .lineLimit(1)
        }
        //.ignoresSafeArea()
        .matchedGeometryEffect(id: "WhisperInfoView", in: pannelAnimation)
        //.transition(.move(edge: .bottom))
        .transition(.scale)
    }
    
    var mainControls : some View {
        HStack(alignment: .center, spacing: isPanel ? 20 : 15) {
            Spacer()
            
            ControlsView(isOpen: self.isPanel, tvViewState: self.$tvViewState)
            
            if isPanel {
                Spacer()
            } else {
                self.tv
                    .frame(width: 180)
            }
            
            MicrophonePressAndHoldButtonView().matchedGeometryEffect(id: "button", in: pannelAnimation)
            
            Spacer()
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.init(top: 0,
                       leading: self.isPanel ? 20 : 00,
                       bottom: 0,
                       trailing: self.isPanel ? 20 : 00))
        .transition(.move(edge: .leading))
    }
    
    var historyControls : some View {
        HStack(alignment: .center, spacing: isPanel ? 20 : 15) {
            Spacer()
            
            ChatHistoryHardDrive(tvViewState: self.$tvViewState)

            
            if isPanel {
                Spacer()
            } else {
                self.tv
                    .frame(width: 180)
            }
            
            ChatHistoryControls(tvViewState: self.$tvViewState)
                //.padding(.horizontal, 10)
            Spacer()

        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.init(top: 0,
                       leading: self.isPanel ? 10 : 00,
                       bottom: 0,
                       trailing: self.isPanel ? 10 : 00))
        .transition(.move(edge: .trailing))
    }
    
    var topPanelView: some View {
        SheetView(isOpen: self.$isPanel, maxHeightFraction: 0.8, minHeight: 220) {
            VStack(spacing: self.isPanel ? 50 : 25) {
                
                //self.audioDevicesView
                
                if isPanel { self.tv }
                
                /*
                ControlPanel {
                    switch self.tvViewState.controlsType {
                    case .main:
                        self.mainControls
                    case .history:
                        self.historyControls
                    }
                }.frame(maxHeight: 250)
                */

                switch self.tvViewState.controlsType {
                case .main:
                    self.mainControls
                case .history:
                    self.historyControls
                }
            }
            .padding(.init(top: isPanel ? 40 : 10, leading: 0, bottom: isPanel ? 40 : 40, trailing: 0))
        }
        .animation(.easeInOut(duration: 0.4), value: self.isPanel)
        .frame(maxHeight: .infinity, alignment: .top)
    }
    
    var bottomPanelView: some View {
        VStack(spacing: 40) {
            
            Spacer()

            self.statusView
                .padding(.bottom, 40)
                .padding(.horizontal, 40)
        }
    }
    
    var body: some View {
        ZStack {
            self.bottomPanelView
            self.topPanelView
        }
        .drawingGroup()
        .background(.secondAccent, ignoresSafeAreaEdges: .bottom)
        .background(.mainAccent, ignoresSafeAreaEdges: .top)
        .edgesIgnoringSafeArea(.bottom)
        
        .onAppear {
            self.chatViewModel.messageBoard.startMessageBoardTask()
            withAnimation {
                self.tvViewState.displayType = .salSignature
            }
        }
    }
}

fileprivate struct TestView : View {
    
    @State private var chatViewModel : ChatViewModel = .init()

    var body: some View {
        ContentView()
            .environment(self.chatViewModel)
    }
}

#Preview {
    TestView()
}
