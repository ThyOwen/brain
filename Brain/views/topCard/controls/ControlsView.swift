//
//  ControlsView.swift
//  Brain
//
//  Created by Owen O'Malley on 5/6/24.
//

import SwiftUI

struct ControlsView: View {
    
    let smallerCornerRadius : CGFloat = 5
    let paddingAmount : CGFloat = 4.5
    
    var isOpen : Bool
    
    @Binding var showWave : Bool
    
    @Environment(MessageBoard.self) private var messageBoard
    
    @Environment(Whisper.self) private var whisper
    @Environment(ChatViewModel.self) private var chatViewModel

    
    private var cornerRadius : CGFloat { self.isOpen ? 32 : 18 }

    enum ControlsViewMessages : String {
        case mustLoadModel = "must load model before usage"
        case sensitivityIs = "sensitivity is "
        case startedRecording = "recording started"
        case endedRecording = "recording ended"
        case newConversation = "new conversation"
    }
    
    var iconCircle : some View {
        Circle()
            .inset(by: 9)
            .fill(.secondAccent)
            .outerShadow(darkShadow: .darkShadow,
                         lightShadow: .lightShadow, 
                         offset: isOpen ? 3 : 0,
                         radius: isOpen ? 6 : 0)
    }
    
    var button0 : some View {
        Button {
            withAnimation {
                self.showWave.toggle()
            }
        } label: {
            ZStack {
                UnevenRoundedRectangle(cornerRadii: .init(topLeading: (self.cornerRadius-self.paddingAmount),
                                                          bottomLeading: self.smallerCornerRadius,
                                                          bottomTrailing: self.smallerCornerRadius,
                                                          topTrailing: self.smallerCornerRadius),
                                       style: .continuous)
                .fill(.secondAccent)
                .strokeBorder(LinearGradient(colors: [.edgeLightShadow, .edgeDarkShadow],
                                             startPoint: .topLeading,
                                             endPoint: .bottomTrailing), lineWidth: 1)
                self.iconCircle
                
                let icon = self.showWave ? "bubble.left.and.bubble.right.fill" : "waveform.path.ecg.rectangle.fill"
                
                Image(systemName: icon)
                    .foregroundStyle(.lightShadow)
                    .imageScale(self.isOpen ? .medium : .small)
                    .symbolEffect(.bounce, value: self.showWave)
                    //.contentTransition()
                    
            }
        }
        .scaleButtonStyle()
    }
    
    var button1 : some View {
        Button {
            if self.whisper.modelState != .loaded {
                self.messageBoard.postTemporaryMessage(Self.ControlsViewMessages.mustLoadModel.rawValue)
            } else {
                if self.whisper.isRecording {
                    self.messageBoard.postTemporaryMessage(Self.ControlsViewMessages.endedRecording.rawValue)
                } else {
                    self.messageBoard.postTemporaryMessage(Self.ControlsViewMessages.startedRecording.rawValue)
                }
                self.whisper.toggleRecording(shouldLoop: true)
            }
        } label: {
            ZStack {
                
                UnevenRoundedRectangle(cornerRadii: .init(topLeading: self.smallerCornerRadius,
                                                          bottomLeading: self.smallerCornerRadius,
                                                          bottomTrailing: self.smallerCornerRadius,
                                                          topTrailing: (self.cornerRadius-self.paddingAmount)),
                                       style: .continuous)
                .fill(.secondAccent)
                .strokeBorder(LinearGradient(colors: [.edgeLightShadow, .edgeDarkShadow],
                                             startPoint: .topLeading,
                                             endPoint: .bottomTrailing), lineWidth: 1)
                
                self.iconCircle
                /*
                Circle()
                    .inset(by: 5)
                    .fill(
                        LinearGradient(colors: [.cyan, .blue],
                                       startPoint: .init(x: 0, y: 0),
                                       endPoint: .init(x: 1, y: 1))
                    )
                
                Circle()
                    .inset(by: 12)
                    .fill(
                        LinearGradient(colors: [.cyan, .blue].reversed(),
                                       startPoint: .init(x: 0, y: 0),
                                       endPoint: .init(x: 1.0, y: 1.0))
                    )
                */
                Image(systemName: "recordingtape.circle.fill")
                    .foregroundStyle(.darkShadow)
                    .imageScale(self.isOpen ? .medium : .small)
                
            }
        }
        .scaleButtonStyle()
    }
    
    var button2 : some View {
        Button {
            if self.whisper.appSettings.silenceThreshold < 1.0 {
                self.whisper.appSettings.silenceThreshold = round((self.whisper.appSettings.silenceThreshold * 10) + 1) / 10
            }
            self.messageBoard.postTemporaryMessage(ControlsViewMessages.sensitivityIs.rawValue + String(self.whisper.appSettings.silenceThreshold))
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: self.smallerCornerRadius, style: .continuous)
                    .fill(.secondAccent)
                    .strokeBorder(LinearGradient(colors: [.edgeLightShadow, .edgeDarkShadow],
                                                 startPoint: .topLeading,
                                                 endPoint: .bottomTrailing), lineWidth: 1)
                self.iconCircle
                Image(systemName: "plus")
                    .foregroundStyle(.black)
                    .imageScale(self.isOpen ? .medium : .small)
            }
        }
        .scaleButtonStyle()
    }
    
    var button3 : some View {
        Button {
            self.messageBoard.postTemporaryMessage(Self.ControlsViewMessages.newConversation.rawValue)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: self.smallerCornerRadius, style: .continuous)
                    .fill(.secondAccent)
                    .strokeBorder(LinearGradient(colors: [.edgeLightShadow, .edgeDarkShadow],
                                         startPoint: .topLeading,
                                           endPoint: .bottomTrailing), lineWidth: 1)
                self.iconCircle
                
                Image(systemName: "plus.message.fill")
                    .foregroundStyle(.darkShadow)
                    .imageScale(self.isOpen ? .medium : .small)
            }
        }
        .scaleButtonStyle()
    }
    
    var button4 : some View {
        Button {
            if self.whisper.appSettings.silenceThreshold > 0.0 {
                self.whisper.appSettings.silenceThreshold = round((self.whisper.appSettings.silenceThreshold * 10) - 1) / 10
            }
            self.messageBoard.postTemporaryMessage(ControlsViewMessages.sensitivityIs.rawValue + String(self.whisper.appSettings.silenceThreshold))
        } label: {
            ZStack {
                UnevenRoundedRectangle(cornerRadii: .init(topLeading: self.smallerCornerRadius,
                                                          bottomLeading: (self.cornerRadius-self.paddingAmount),
                                                          bottomTrailing: self.smallerCornerRadius,
                                                          topTrailing: self.smallerCornerRadius),
                                       style: .continuous)
                .fill(.secondAccent)
                .strokeBorder(LinearGradient(colors: [.edgeLightShadow, .edgeDarkShadow],
                                             startPoint: .topLeading,
                                             endPoint: .bottomTrailing), lineWidth: 1)
                self.iconCircle
                Image(systemName: "minus")
                    .foregroundStyle(.black)
                    .imageScale(self.isOpen ? .medium : .small)
            }
        }
        .scaleButtonStyle()
    }
    
    var button5 : some View {
        Button {
            
        } label: {
            ZStack {
                UnevenRoundedRectangle(cornerRadii: .init(topLeading: self.smallerCornerRadius,
                                                          bottomLeading: self.smallerCornerRadius,
                                                          bottomTrailing: (self.cornerRadius-self.paddingAmount),
                                                          topTrailing: self.smallerCornerRadius),
                                       style: .continuous)
                    .fill(.secondAccent)
                    .strokeBorder(LinearGradient(colors: [.edgeLightShadow, .edgeDarkShadow],
                                         startPoint: .topLeading,
                                           endPoint: .bottomTrailing), lineWidth: 1)
                
                self.iconCircle
                
                Image(systemName: "antenna.radiowaves.left.and.right.circle.fill")
                    .foregroundStyle(.darkShadow)
                    .imageScale(self.isOpen ? .medium : .small)
            }
        }
        .scaleButtonStyle()
    }
    
    var body: some View {
        ZStack {
            /*
            RoundedRectangle(cornerRadius: self.cornerRadius, style: .continuous)
                .inset(by: -1)
                .fill(.mainAccent)
                .outerShadow(darkShadow: .darkShadow, lightShadow: .lightShadow)
            */
            RoundedRectangle(cornerRadius: self.cornerRadius, style: .continuous)
                .strokeBorder(LinearGradient(colors: [.darkShadow, .lightShadow],
                                     startPoint: .topLeading,
                                     endPoint: .bottomTrailing), lineWidth: 5)
            
            RoundedRectangle(cornerRadius: self.cornerRadius, style: .continuous)
                .inset(by: 3)
                .fill(.black)
            
            Grid(horizontalSpacing: 1.0, verticalSpacing: 1.0) {
                GridRow {
                    self.button0
                        //.aspectRatio(1.0, contentMode: .fit)
                    self.button1
                        //.aspectRatio(1.0, contentMode: .fit)
                }
                GridRow {
                    self.button2
                        //.aspectRatio(1.0, contentMode: .fit)
                    self.button3
                        //.aspectRatio(1.0, contentMode: .fit)
                }
                GridRow {
                    self.button4
                        //.aspectRatio(1.0, contentMode: .fit)
                    self.button5
                        //.aspectRatio(1.0, contentMode: .fit)
                }
            }
            .padding(.all, self.paddingAmount)
            
        }
        .aspectRatio(0.66666, contentMode: .fit)
    }
}


fileprivate struct TestView : View {
    
    @State var whisper : Whisper
    @State var chatViewModel : ChatViewModel
    @State var messageBoard : MessageBoard
    @State var showWave : Bool = false
    
    init() {
        let messageBoard = MessageBoard()
        self.whisper = .init(messageBoard: messageBoard)
        self.chatViewModel = .init(username: ServerConstants.username, serverAddress: ServerConstants.serverAddress, serverPort: ServerConstants.serverPort, messageBoard: messageBoard)
        self.messageBoard = messageBoard
    }
    
    var body: some View {
        ZStack {
            Color.mainAccent.ignoresSafeArea()
            ControlsView(isOpen: true, showWave: self.$showWave)
                .frame(width: 150)
        }
        .environment(self.chatViewModel)
        .environment(self.whisper)
        .environment(self.messageBoard)
    }
}
#Preview {
    TestView()
}
