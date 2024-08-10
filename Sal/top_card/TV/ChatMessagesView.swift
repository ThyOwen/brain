//
//  ChatMessagesView.swift
//  Sal
//
//  Created by Owen O'Malley on 7/14/24.
//

import SwiftUI
import SwiftData


struct ChatMessagesView: View {
    
    @Binding public var tvViewState : TVViewState
    @Bindable public var chat : Chat
    
    public var numMessagesDisplayed : Int = 4
    
    private var chatIndicesRange : Range<Int> {
        let lowerBound = self.tvViewState.selectedChatMessageIndex
        let upperBound = lowerBound + self.numMessagesDisplayed
        
        if upperBound > self.chat.messages.count {
            return (lowerBound..<self.chat.messages.count)
        } else {
            return (lowerBound..<upperBound)
        }
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            ForEach(self.chat.messages[self.chatIndicesRange], id: \.self) { chatMessage in
                HStack {
                    let isUser : Bool = chatMessage.sender == ChatSender.user
                    
                    if isUser { Spacer() }
                    
                    VStack(alignment: isUser ? .trailing : .leading) {
                        
                        Text(chatMessage.sender.rawValue)
                            .font(.custom("zig", size: 8))
                            .foregroundStyle(isUser ? Color.white : Color.green)
                        
                        Text(chatMessage.text)
                            .font(.custom("zig", size: 12))
                            .foregroundStyle(isUser ? Color.white : Color.green)
                    }
                    
                    if !isUser { Spacer() }
                }.transition(.asymmetric(insertion: .move(edge: .bottom),
                                         removal: .move(edge: .top)).combined(with: .opacity).animation(.easeInOut(duration: 0.2)))

            }
        }.transition(.opacity)
    }
}

fileprivate struct TestView : View {
    
    @State private var chatViewModel : ChatViewModel = .init()
    @State private var tvViewState : TVViewState = .init()
    
    var body: some View {
        VStack {
            TVView {
                if let chat = self.chatViewModel.chat.activeChat {
                    ChatMessagesView(tvViewState: self.$tvViewState, chat: chat)
                        .padding(.horizontal, 30)
                        .blur(radius: 0.5)
                }
            }
            
            HStack {
                Button("up") {
                    withAnimation {
                        self.tvViewState.selectedChatMessageIndex += 1
                    }
                }
                
                Button("down") {
                    withAnimation {
                        self.tvViewState.selectedChatMessageIndex -= 1
                    }
                }
            }
        }
        .onAppear {
            try? self.chatViewModel.chat.loadModelContainer()
            try? self.chatViewModel.chat.loadChatHistory()
            self.chatViewModel.chat.createChat(withPrePrompt: "Asdfasdfasdf")
            
            
            
            self.chatViewModel.chat.activeChat?.messages.append(.init(sender: .user, text: "Yeah?  Who's this?", tokensPerSecondForGeneration: 0.9))
            self.chatViewModel.chat.activeChat?.messages.append(.init(sender: .sal, text: "Sir, you're on the air.  I wonder if you'd answer a few questions.", tokensPerSecondForGeneration: 0.9))
            self.chatViewModel.chat.activeChat?.messages.append(.init(sender: .user, text: "Hey, Sal...Sure.", tokensPerSecondForGeneration: 0.9))
            self.chatViewModel.chat.activeChat?.messages.append(.init(sender: .sal, text: "Why are you doing this?", tokensPerSecondForGeneration: 0.9))
            self.chatViewModel.chat.activeChat?.messages.append(.init(sender: .user, text: "Doing what?", tokensPerSecondForGeneration: 0.9))
            self.chatViewModel.chat.activeChat?.messages.append(.init(sender: .sal, text: "Robbing a bank.", tokensPerSecondForGeneration: 0.9))
            self.chatViewModel.chat.activeChat?.messages.append(.init(sender: .user, text: "I don't know... They got money here?", tokensPerSecondForGeneration: 0.9))
            self.chatViewModel.chat.activeChat?.messages.append(.init(sender: .sal, text: "But I mean, why do you need to steal? Couldn't you get a job?", tokensPerSecondForGeneration: 0.9))
            self.chatViewModel.chat.activeChat?.messages.append(.init(sender: .user, text: "Get a job doing what?  You gotta be a member of a union.", tokensPerSecondForGeneration: 0.9))
            self.chatViewModel.chat.activeChat?.messages.append(.init(sender: .sal, text: "What about, ah, non-union occupations?", tokensPerSecondForGeneration: 0.9))
        }
    }
}

    
#Preview {
    ZStack {
        Color.mainAccent.ignoresSafeArea()
        TestView()
            .frame(width: 350, height: 300)
    }
}
