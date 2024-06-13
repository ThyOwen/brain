//
//  ChatEntry.swift
//  Brain
//
//  Created by Owen O'Malley on 5/16/24.
//

import Foundation

enum ChatEntry {
    case message(ChatMessage)
    case userJoined(String)
    case userLeft(String)
}

struct ServerConstants {
    static let username = "Jack"
    
    // ::1 will always connect to localhost (this is the IPv6 equivalent to 127.0.0.1)
    static let serverAddress = "::1"
    static let serverPort = 9999
}
