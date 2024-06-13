//
//  brainApp.swift
//  brain
//
//  Created by Owen O'Malley on 1/7/24.
//

import SwiftUI

@main
struct brainApp: App {
    
    @State var chatViewModel : ChatViewModel
    @State var whisper : Whisper
    @State var messageBoard : MessageBoard
    
    init() {
        let messageBoard = MessageBoard()
        self.whisper = .init(messageBoard: messageBoard)
        self.chatViewModel = .init(username: "me", serverAddress: ServerConstants.serverAddress, serverPort: ServerConstants.serverPort, messageBoard: messageBoard)
        self.messageBoard = messageBoard
    }
    
    var body: some Scene {
        WindowGroup {
            
            ContentView()
                .environment(self.whisper)
                .environment(self.messageBoard)
                .environment(self.chatViewModel)
            
            /*
            ChatTestView()
                .environment(self.messageBoard)
                .environment(self.chatViewModel)
             */
             
        }
    }
}
