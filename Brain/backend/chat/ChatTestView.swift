//
//  ChatTestView.swift
//  Brain
//
//  Created by Owen O'Malley on 5/16/24.
//

import SwiftUI

struct ChatTestView: View {
    
    @Environment(ChatViewModel.self) private var chatViewModel
    
    @Environment(MessageBoard.self) private var messageBoard

    @State private var messageText = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text(self.messageBoard.boardText)
            //Text(self.chatViewModel.salConnection.)
            Button {
                self.chatViewModel.sendMessage(message: Date().description)
            } label: {
               Text("send")
            }
        }
        .onAppear {
            self.chatViewModel.connect()
        }
        .padding()
    }
}

fileprivate struct TestView : View {
    
    @State var chatViewModel : ChatViewModel
    @State var whisper : Whisper
    @State var messageBoard : MessageBoard
    
    init() {
        let messageBoard = MessageBoard()
        self.whisper = .init(messageBoard: messageBoard)
        self.chatViewModel = .init(username: "me", serverAddress: ServerConstants.serverAddress, serverPort: ServerConstants.serverPort, messageBoard: messageBoard)
        self.messageBoard = messageBoard
    }
    
    var body: some View {
        ContentView()
            .environment(self.chatViewModel)
            .environment(self.whisper)
            .environment(self.messageBoard)
    }
}

#Preview {
    TestView()
}
