import Foundation
import SwiftSoup

public enum Sender : String {
    case bot
    case user
}

public struct ChatMessage : Identifiable {
    var content : String
    let sender : Sender
    
    public let id : UUID = UUID()
    public let datetime : Date = Date()
}

