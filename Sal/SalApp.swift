//
//  SalApp.swift
//  Sal
//
//  Created by Owen O'Malley on 6/24/24.
//

import SwiftUI
import SwiftData

@main
struct SalApp: App {

    @State var chatViewModel : ChatViewModel = .init()

    var body: some Scene {
        WindowGroup {
            
            ContentView()
                .environment(self.chatViewModel)
            
        }
    }
}
