//
//  MicrophoneButtonView.swift
//  Brain
//
//  Created by Owen O'Malley on 4/21/24.
//

import SwiftUI
import WhisperKit

struct MicrophonePressAndHoldButtonView: View {
    
    @Environment(ChatViewModel.self) private var chatViewModel
    @Environment(Whisper.self) private var whisper
    
    @Environment(MessageBoard.self) private var messageBoard

    static let colors : [Color] = [.orange, .red]
    
    private var modelLoaded : Bool {
        !(self.whisper.modelState == .unloaded || self.whisper.modelState == .loaded)
    }
    
    var button: some View {
        ZStack {
            Capsule()
                .inset(by: 5)
                .fill(
                    LinearGradient(colors: Self.colors,
                                   startPoint: .init(x: 0, y: 0),
                                   endPoint: .init(x: 1, y: 1))
                )
            
            Capsule()
                .inset(by: 20)
                .fill(
                    LinearGradient(colors: Self.colors.reversed(),
                                   startPoint: .init(x: 0, y: 0),
                                   endPoint: .init(x: 1, y: 1))
                )
            
            Image(systemName: "mic.fill")
                .foregroundStyle(Color.init(white: 0.4).opacity(0.5))
                    .foregroundStyle(.darkShadow)
                    .imageScale(.large)
            
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
                switch self.whisper.modelState {
                case .unloaded:
                    Task {
                        self.messageBoard.postTemporaryMessage("model started loading", duration: 4)
                        self.whisper.resetState()
                        self.whisper.modelState = .loading
                        await MainActor.run {
                            self.whisper.loadModel(self.whisper.appSettings.selectedModel)
                        }
                    }
                case .loaded:
                    self.whisper.toggleRecording(shouldLoop: true)
                    break
                default:
                    self.messageBoard.postTemporaryMessage("model is still loading", duration: 3)
                }
                
            } label: {
                self.button
            }
            .scaleButtonStyle()
        }
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

struct MicrophoneToggleButtonView: View {
    
    @Environment(ChatViewModel.self) private var chatViewModel
    @Environment(Whisper.self) private var whisper
    
    @Environment(MessageBoard.self) private var messageBoard
    
    static let colors : [Color] = [.cyan, .blue]
    
    var button: some View {
        ZStack {
            Circle()
                .inset(by: 5)
                .fill(
                    LinearGradient(colors: Self.colors,
                                   startPoint: .init(x: 0, y: 0),
                                   endPoint: .init(x: 1, y: 1))
                )
            
            Circle()
                .inset(by: 12)
                .fill(
                    LinearGradient(colors: Self.colors.reversed(),
                                   startPoint: .init(x: 0, y: 0),
                                   endPoint: .init(x: 1.0, y: 1.0))
                )
            
            Image(systemName: "recordingtape.circle.fill")
                .foregroundStyle(Color.init(white: 0.4).opacity(0.5))
                    .foregroundStyle(.darkShadow)
                    .imageScale(.large)
             
        }
    }
    
    var body: some View {
        ZStack {
            
            Circle()
                .strokeBorder(LinearGradient(colors: [.darkShadow, .lightShadow],
                                             startPoint: .topLeading,
                                             endPoint: .bottomTrailing), lineWidth: 5)
            Circle()
                .inset(by: 3)
                .fill(.black)
            
            Button {
                switch self.whisper.modelState {
                case .unloaded:
                    Task {
                        self.messageBoard.postTemporaryMessage("model started loading", duration: 4)
                        self.whisper.resetState()
                        self.whisper.modelState = .loading
                        await MainActor.run {
                            self.whisper.loadModel(self.whisper.appSettings.selectedModel)
                        }
                    }
                case .loaded:
                    self.whisper.toggleRecording(shouldLoop: true)
                    break
                default:
                    self.messageBoard.postTemporaryMessage("model is still loading", duration: 3)
                }
                
            } label: {
                self.button
            }
            .scaleButtonStyle()
        }
        
    }
}

fileprivate struct TestView : View {
    
    @State private var whisper : Whisper
    @State private var chatViewModel : ChatViewModel
    @State private var messageBoard : MessageBoard
    
    init() {
        let messageBoard = MessageBoard()
        self.whisper = .init(messageBoard: messageBoard)
        self.chatViewModel = .init(username: "me", serverAddress: ServerConstants.serverAddress, serverPort: ServerConstants.serverPort, messageBoard: messageBoard)
        self.messageBoard = messageBoard
    }
    
    
    var body: some View {
        ZStack {
            Color.mainAccent.ignoresSafeArea()
            MicrophonePressAndHoldButtonView()
                .frame(width: 150, height: 200)
            MicrophoneToggleButtonView()
                .frame(width: 70, height: 70)
                .offset(x: 100, y: -100)
        }
        .environment(self.whisper)
        .environment(self.chatViewModel)
        .environment(self.messageBoard)
    }
}

#Preview {
    TestView()
}
