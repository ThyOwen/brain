//
//  ChatHistory.swift
//  Sal
//
//  Created by Owen O'Malley on 7/2/24.
//

import SwiftUI
import SwiftData


struct ChatDetails : View {
    
    @Bindable public var chat : Chat
    
    var body: some View {
        
        ZStack {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(self.chat.title)
                        .font(.custom("zig", size: 12))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(3)
                    
                    Text(self.chat.summary)
                        .font(.custom("zig", size: 7))
                        .fontWeight(.light)
                        .italic()
                        .foregroundStyle(.white)
                        .lineLimit(3)
                }
                Spacer()
                
                Text(self.chat.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.custom("zig", size: 7))
                    .fontWeight(.light)
                    .foregroundStyle(.white)
                    .frame(maxWidth: 60)
                    .lineLimit(3)
                
            }
        }
    }
}

struct ChatHistoryView: View {
    
    @Binding public var tvViewState : TVViewState
    
    @Environment(ChatViewModel.self) private var chatViewModel
    
    //for animation
    @State private var showSelectedIcon : Bool = true
    
    private let numberOfChatsDisplayed : Int = 3
    
    private var showUpIndicator : Bool {
        self.chatIndicesRange.lowerBound != 0
    }
    private var showDownIndicator : Bool {
        self.chatIndicesRange.upperBound != self.chatViewModel.chat.chatHistory.count
    }
    
    private var chatIndicesRange : Range<Int> {

        let lowerBound = self.tvViewState.selectedChatHistoryIndex
        let upperBound = lowerBound + self.numberOfChatsDisplayed

        if upperBound > self.chatViewModel.chat.chatHistory.count {
            return (lowerBound..<self.chatViewModel.chat.chatHistory.count)
        } else {
            return (lowerBound..<upperBound)
        }
        
    }
    
    @State private var scrollTransition : AnyTransition = .opacity.animation(.easeInOut(duration: 0.2))
    
    var body: some View {
        ZStack {
            VStack(spacing: 15) {
                ForEach(self.chatViewModel.chat.chatHistory[self.chatIndicesRange]) { chat in
                    HStack {
                        ZStack {
                            let isSelectedChat = self.chatViewModel.chat.chatHistory[self.tvViewState.selectedChatHistoryIndex] == chat
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(isSelectedChat ? Color.green : Color.clear)
                                .frame(maxWidth: 20, maxHeight: 20)
                                .opacity(self.showSelectedIcon ? 0.0 : 1.0)
                            
                            Image(systemName: "greaterthan")
                                .foregroundStyle(isSelectedChat ? Color.black : Color.white)
                            
                        }
                        
                        ChatDetails(chat: chat)
                        
                    }
                    .transition(self.scrollTransition.combined(with: .opacity).animation(.easeInOut(duration: 0.2)))
                }
            }
            
            VStack {
                if self.showUpIndicator {
                    Image(systemName: "arrow.up")
                        .symbolEffect(.pulse)
                        .transition(.opacity)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                if self.showDownIndicator {
                    Image(systemName: "arrow.down")
                        .symbolEffect(.pulse)
                        .transition(.opacity)
                        .foregroundColor(.white)
                }
            }.padding(20)
            
        }
        .animation(.easeInOut(duration: 0.1).delay(0.5).repeatForever(autoreverses: true), value: self.showSelectedIcon)
        .onAppear {
            withAnimation {
                self.showSelectedIcon.toggle()
            }
        }
        .onChange(of: self.tvViewState.selectedChatHistoryIndex) { oldValue, newValue in
            if newValue > oldValue {
                self.scrollTransition = .asymmetric(insertion: .move(edge: .bottom), removal: .move(edge: .top))
            } else {
                self.scrollTransition = .asymmetric(insertion: .move(edge: .top), removal: .move(edge: .bottom))
            }
        }
    }
    
}

fileprivate struct TestView : View {
    
    @State private var chatViewModel : ChatViewModel = .init()
    @State private var tvViewState : TVViewState = .init()
    
    var body: some View {
        VStack {
            TVView {
                ChatHistoryView(tvViewState: self.$tvViewState)
                    .padding(.horizontal, 20)
                    .blur(radius: 0.6)
                    .environment(self.chatViewModel)
            }
            .frame(width: 400, height: 350)
            .onAppear {
                try? self.chatViewModel.chat.loadModelContainer()
                self.chatViewModel.chat.loadChatHistory()
            }
            
            HStack {
                Button("up") {
                    withAnimation {
                        self.tvViewState.selectedChatHistoryIndex -= 1
                    }
                }
                Button("down") {
                    withAnimation {
                        self.tvViewState.selectedChatHistoryIndex += 1
                    }
                }
            }
            
            
        }
    }
}

#Preview {
    ZStack {
        Color.mainAccent.ignoresSafeArea()
        
        TestView()
    }
}
