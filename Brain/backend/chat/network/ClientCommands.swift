//
//  ClientCommands.swift
//  Brain
//
//  Created by Owen O'Malley on 5/16/24.
//

import Foundation

public enum ClientCommand: Equatable {
    case connect(username: String)
    case disconnect
    case message(chatID : UUID, text: String)
}

extension ClientCommand: Codable {
    private enum CodingKeys: String, CodingKey {
        case command
        case data
    }

    private enum Cmd: String, Codable {
        case connect, disconnect, message
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Cmd.self, forKey: .command) {
        case .connect:
            let username = try container.decode(String.self, forKey: .data)
            self = .connect(username: username)
        case .disconnect:
            self = .disconnect
        case .message:
            let msg = try container.decode(ClientMessageData.self, forKey: .data)
            self = .message(chatID: msg.toChatID, text: msg.text)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .connect(let username):
            try container.encode(Cmd.connect, forKey: .command)
            try container.encode(username, forKey: .data)
        case .disconnect:
            try container.encode(Cmd.disconnect, forKey: .command)
        case .message(let chatID, let text):
            try container.encode(Cmd.message, forKey: .command)
            try container.encode(ClientMessageData(toChatID: chatID, text: text), forKey: .data)
        }
    }
}
    

private struct ClientMessageData: Codable {
    let toChatID: UUID
    let text: String
}
