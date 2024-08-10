//
//  ChatHistoryControls.swift
//  Sal
//
//  Created by Owen O'Malley on 7/10/24.
//

import SwiftUI

struct ChatHistorySelectorButton : View {
    
    public let text : String
    public let cornerRadii : RectangleCornerRadii
    
    
    var body: some View {
        ZStack {
            UnevenRoundedRectangle(cornerRadii: self.cornerRadii)
                .fill(.secondAccent)
                .strokeBorder(LinearGradient(colors: [.edgeLightShadow.opacity(0.5), .edgeDarkShadow],
                                             startPoint: .topLeading,
                                             endPoint: .bottomTrailing), lineWidth: 1)
            
            VStack(spacing: 5) {
                
                Text(self.text)
                    .font(.custom("Futura", size: 12))
                    .foregroundStyle(.buttonText)
                    .blur(radius: 0.3)
                
                Capsule()
                    .fill(.secondAccent)
                    .frame(height: 5)
                    
                    .innerShadow(Capsule(),
                                 darkShadow: .darkShadow,
                                 lightShadow: .lightShadow,
                                 spread: 0.3,
                                 radius: 2)
            }.padding(.horizontal, 15)
        }
    }
}

struct ChatHistoryControls: View {
    
    @Environment(ChatViewModel.self) private var chatViewModel
    
    @Binding public var tvViewState : TVViewState
    
    public let cornerRadius : CGFloat = 40
    
    var resumeButton : some View {
        Button {
            Task {
                await self.chatViewModel.chat.resumeChat(at: self.tvViewState.selectedChatHistoryIndex)
            }
            
            withAnimation {
                self.tvViewState.displayType = .waveAndActiveChatMessages
                self.tvViewState.controlsType = .main
            }
            
        } label: {
            ChatHistorySelectorButton(text: "RSM",cornerRadii: .init(topLeading: 13,
                                                                      bottomLeading: 5,
                                                                      bottomTrailing: 5,
                                                                      topTrailing: 13))
        }
        .scaleButtonStyle()
    }

    var viewButton : some View {
        Button {
            withAnimation {
                self.tvViewState.displayType = .historicChatMessages
            }
        } label: {
            ChatHistorySelectorButton(text: "VIEW", cornerRadii: .init(topLeading: 5,
                                                                      bottomLeading: 5,
                                                                      bottomTrailing: 5,
                                                                      topTrailing: 5))
        }
        .scaleButtonStyle()
    }
    
    var deleteButton : some View {
        Button {
            Task {
                await self.chatViewModel.chat.deleteChat(at: self.tvViewState.selectedChatHistoryIndex)
            }
        } label: {
            ChatHistorySelectorButton(text: "DEL", cornerRadii: .init(topLeading: 5,
                                                                       bottomLeading: 5,
                                                                       bottomTrailing: 5,
                                                                       topTrailing: 5))
        }
        .scaleButtonStyle()
    }
    
    var backButton : some View {
        Button {
            switch self.tvViewState.displayType {
            case .historicChatMessages:
                withAnimation {
                    self.tvViewState.displayType = .chatHistory
                }
            case .chatHistory:
                withAnimation {
                    self.tvViewState.displayType = .waveAndActiveChatMessages
                    self.tvViewState.controlsType = .main
                }
            default:
                break
            }

        } label: {
            ChatHistorySelectorButton(text: "BACK", cornerRadii: .init(topLeading: 5,
                                                                      bottomLeading: 13,
                                                                      bottomTrailing: 13,
                                                                      topTrailing: 5))
        }
        .scaleButtonStyle()
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(.mainAccent)
                .outerShadow(darkShadow: .darkShadow,
                             lightShadow: .lightShadow,
                             offset: 5,
                             radius: 10)
            RoundedRectangle(cornerRadius: 20)
                .inset(by: 5.5)
                .fill(.black)
            
            
            VStack(spacing: 1.5) {
                
                self.resumeButton
                
                self.viewButton
                
                self.deleteButton
                
                self.backButton
                
            }
            .padding(7)
            
        }
        .frame(minWidth: 80, maxWidth: 90, minHeight: 200)
    }

}

fileprivate struct TestView : View {
    
    @State private var chatViewModel : ChatViewModel = .init()
    
    var body: some View {
        ChatHistoryControls(tvViewState: .constant(TVViewState.init()))
            .environment(self.chatViewModel)
            .frame(height: 500)
            .padding(.horizontal, 20)
    }
}

#Preview {
    ZStack {
        Color.mainAccent.ignoresSafeArea()
        
        TestView()
    }
}
