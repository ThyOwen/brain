//
//  brainApp.swift
//  brain
//
//  Created by Owen O'Malley on 1/7/24.
//

import SwiftUI

@main
struct brainApp: App {
    
    @State private var whisper : Whisper = .init()
    @State private var chatViewModel : ChatViewModel = .init(messageText: "load model to start usage")
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(self.chatViewModel)
                .environment(self.whisper)
        }
    }
}
