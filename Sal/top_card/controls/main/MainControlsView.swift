//
//  ControlsView.swift
//  Brain
//
//  Created by Owen O'Malley on 5/6/24.
//

import SwiftUI

struct ControlsButtonView<Content : View> : View {
    public let cornerRadii : RectangleCornerRadii
    public let isOpen : Bool
    
    @ViewBuilder public let content : Content
    
    var body: some View {
        ZStack {
            UnevenRoundedRectangle(cornerRadii: self.cornerRadii, style: .continuous)
                .fill(.secondAccent)
                .strokeBorder(LinearGradient(colors: [.edgeLightShadow, .edgeDarkShadow],
                                             startPoint: .topLeading,
                                             endPoint: .bottomTrailing), lineWidth: 1)
            
            Circle()
                .inset(by: 9)
                .fill(.secondAccent)
                .outerShadow(darkShadow: .darkShadow,
                             lightShadow: .lightShadow,
                             offset: self.isOpen ? 3 : 0,
                             radius: self.isOpen ? 5 : 0)
            
            self.content
        }
    }
}

struct ControlsView: View {
    
    let smallerCornerRadius : CGFloat = 5
    let paddingAmount : CGFloat = 4.5
    
    var isOpen : Bool
    
    @Binding public var tvViewState : TVViewState
    
    @Environment(ChatViewModel.self) private var chatViewModel

    private var cornerRadius : CGFloat { self.isOpen ? 32 : 18 }
    
    var button0 : some View {
        Button {
            self.tvViewState.showWaveOrChat.toggle()
        } label: {
            
            let icon = self.tvViewState.showWaveOrChat ? "waveform.path.ecg.rectangle.fill" : "bubble.left.and.bubble.right.fill"

            ControlsButtonView(cornerRadii: .init(topLeading: (self.cornerRadius-self.paddingAmount),
                                                  bottomLeading: self.smallerCornerRadius,
                                                  bottomTrailing: self.smallerCornerRadius,
                                                  topTrailing: self.smallerCornerRadius),
                               isOpen: self.isOpen) {
                Image(systemName: icon)
                    .foregroundStyle(.buttonText)
                    .imageScale(self.isOpen ? .medium : .small)
                    .blur(radius: 0.25)
            }
        }
        .scaleButtonStyle()
    }
    
    var button1 : some View {
        Button {
            Task {
                await self.chatViewModel.loadModels()
                
                let prePrompt = "a diologue between a human and a robot. The robot is kind and always answers questions truthfully. When the robot is finished it indicates that is done speaking with the '</s>' symbol,  and never speaks twice in a row.\n"
                
                await self.chatViewModel.chat.createChat(withPrePrompt: prePrompt)
                
                withAnimation {
                    self.tvViewState.displayType = .waveAndActiveChatMessages
                }
            }
        } label: {
            ControlsButtonView(cornerRadii: .init(topLeading: self.smallerCornerRadius,
                                                  bottomLeading: self.smallerCornerRadius,
                                                  bottomTrailing: self.smallerCornerRadius,
                                                  topTrailing: (self.cornerRadius-self.paddingAmount)),
                               isOpen: self.isOpen) {
                Text("LOAD\nMODEL")
                    .font(.custom("Futura", size: self.isOpen ? 8 : 6))
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .foregroundStyle(.buttonText)
                    .blur(radius: 0.3)
            }
        }
        .scaleButtonStyle()
    }
    
    var button2 : some View {
        Button {
            if self.chatViewModel.whisper.appSettings.silenceThreshold < 1.0 {
                self.chatViewModel.whisper.appSettings.silenceThreshold = round((self.chatViewModel.whisper.appSettings.silenceThreshold * 10) + 1) / 10
            }
            self.chatViewModel.messageBoard.postTemporaryMessage("mic sensitivity is \(self.chatViewModel.whisper.appSettings.silenceThreshold)")
        } label: {
            ControlsButtonView(cornerRadii: .init(topLeading: self.smallerCornerRadius,
                                                  bottomLeading: self.smallerCornerRadius,
                                                  bottomTrailing: self.smallerCornerRadius,
                                                  topTrailing: self.smallerCornerRadius),
                               isOpen: self.isOpen) {
                Image(systemName: "plus")
                    .foregroundStyle(.black)
                    .imageScale(self.isOpen ? .medium : .small)
                    .blur(radius: 0.25)
            }
        }
        .scaleButtonStyle()
    }
    
    var button3 : some View {
        Button {
            self.chatViewModel.messageBoard.postTemporaryMessage("created new conversation")
        } label: {
            ControlsButtonView(cornerRadii: .init(topLeading: self.smallerCornerRadius,
                                                  bottomLeading: self.smallerCornerRadius,
                                                  bottomTrailing: self.smallerCornerRadius,
                                                  topTrailing: self.smallerCornerRadius),
                               isOpen: self.isOpen) {
                Image(systemName: "plus.message.fill")
                    .foregroundStyle(.buttonText)
                    .imageScale(self.isOpen ? .medium : .small)
                    .blur(radius: 0.25)
            }
        }
        .scaleButtonStyle()
    }
    
    var button4 : some View {
        Button {
            if self.chatViewModel.whisper.appSettings.silenceThreshold > 0.0 {
                self.chatViewModel.whisper.appSettings.silenceThreshold = round((self.chatViewModel.whisper.appSettings.silenceThreshold * 10) - 1) / 10
            }
            self.chatViewModel.messageBoard.postTemporaryMessage("mic sensitivity is  \(self.chatViewModel.whisper.appSettings.silenceThreshold)")
        } label: {
            ControlsButtonView(cornerRadii: .init(topLeading: self.smallerCornerRadius,
                                                 bottomLeading: (self.cornerRadius-self.paddingAmount),
                                                 bottomTrailing: self.smallerCornerRadius,
                                                 topTrailing: self.smallerCornerRadius),
                               isOpen: self.isOpen) {
                Image(systemName: "minus")
                    .foregroundStyle(.black)
                    .imageScale(self.isOpen ? .medium : .small)
                    .blur(radius: 0.25)
            }

        }
        .scaleButtonStyle()
    }
    
    var button5 : some View {
        Button {
            withAnimation {
                self.tvViewState.controlsType = .history
                self.tvViewState.displayType = .chatHistory
            }
        } label: {
            ControlsButtonView(cornerRadii: .init(topLeading: self.smallerCornerRadius,
                                                  bottomLeading: self.smallerCornerRadius,
                                                  bottomTrailing: (self.cornerRadius-self.paddingAmount),
                                                  topTrailing: self.smallerCornerRadius),
                               isOpen: self.isOpen) {
                Image(systemName: "clock.fill")
                    .foregroundStyle(.buttonText)
                    .imageScale(self.isOpen ? .medium : .small)
                    .blur(radius: 0.25)
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
    
    @State var chatViewModel : ChatViewModel = .init()
    
    @State var tvViewState : TVViewState = .init()
    
    var body: some View {
        ZStack {
            Color.mainAccent.ignoresSafeArea()
            ControlsView(isOpen: true, tvViewState: self.$tvViewState)
                .frame(width: 150)
        }
        .environment(self.chatViewModel)
    }
}
#Preview {
    TestView()
}
