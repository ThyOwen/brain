//
//  ServerMessage.swift
//  Brain
//
//  Created by Owen O'Malley on 5/16/24.
//

import Foundation

public enum ServerMessage: Equatable {
    case connected(to: String)
    case disconnected
    case users([String])
    case chats([Chat])
    case message(chatID: UUID, text: String)
}

extension ServerMessage: Codable {
    private enum CodingKeys: String, CodingKey {
        case command
        case data
    }

    private enum Cmd: String, Codable {
        case connected, disconnected, chats, users, message
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Cmd.self, forKey: .command) {
            case .connected:
                let server = try container.decode(String.self, forKey: .data)
                self = .connected(to: server)
            case .disconnected:
                self = .disconnected
            case .chats:
                let chats = try container.decode([Chat].self, forKey: .data)
                self = .chats(chats)
            case .users:
                let users = try container.decode([String].self, forKey: .data)
                self = .users(users)
            case .message:
                let data = try container.decode(ServerMessageData.self, forKey: .data)
                self = .message(chatID: data.toChatID, text: data.text)
            
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
            case .connected(let to):
                try container.encode(Cmd.connected, forKey: .command)
                try container.encode(to, forKey: .data)
            case .disconnected:
                try container.encode(Cmd.disconnected, forKey: .command)
            case .chats(let chats):
                try container.encode(Cmd.chats, forKey: .command)
                try container.encode(chats, forKey: .data)
            case .users(let users):
                try container.encode(Cmd.users, forKey: .command)
                try container.encode(users, forKey: .data)
            case .message(let chatID, let text):
                try container.encode(Cmd.message, forKey: .command)
                try container.encode(ServerMessageData(toChatID: chatID, text: text), forKey: .data)
        }
    }
}

// Pieces of data we need to encode / decode JSON


private struct ChatAndUsername: Codable {
    let chatID: UUID
    let username: String
}

private struct ServerMessageData: Codable {
    let toChatID : UUID
    let text: String
}
