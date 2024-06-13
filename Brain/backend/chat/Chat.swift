import Foundation 
import Observation

public enum Sender : String, Codable {
    case sal
    case user
}

public struct ChatMessage : Codable, Identifiable {
    let sender : Sender
    let text : String
    public var id = UUID()
    

}

public final class Chat : Identifiable, Codable {
    
    public var messages : [ChatMessage]
    public let prePrompt : String
    public var id = UUID()
    public var date : Date = .init()
    
    
    public static let viewMessages = [

        ChatMessage(sender: .user,
                    text: "Yeah?  Who's this?"),
        ChatMessage(sender: .sal,
                    text: "Sir, you're on the air.  I wonder if you'd answer a few questions."),
        ChatMessage(sender: .user,
                    text: "Hey, Sal...Sure."),
        ChatMessage(sender: .sal,
                    text: "Why are you doing this?"),
        ChatMessage(sender: .user,
                    text: "Doing what?"),
        ChatMessage(sender: .sal,
                    text: "Robbing a bank."),
        ChatMessage(sender: .user,
                    text: "I don't know... they got money here."),
        ChatMessage(sender: .sal,
                    text: "But I mean, why do you need to steal for money? Couldn't you get a job?"),
        ChatMessage(sender: .user,
                    text: "Get a job doing what?  You gotta be a member of a union, no union card - no job."),
        ChatMessage(sender: .sal,
                    text: "What about, ah, non-union occupations?"),
        ChatMessage(sender: .user,
                    text: "Like what?  Bank teller?  What do they get paid -"),
        ChatMessage(sender: .sal,
                    text: "I'm here to talk to you, Sonny, not..."),
        ChatMessage(sender: .user,
                    text: "Wait a minute... I'm talkin' to you. I'm askin' you a question...")
        
    ]

    init(messages: [ChatMessage] = []) {
        self.messages = messages
        self.prePrompt =
        "a diologue between a human and a chatbot. The chatbot is pleasant, truthful, and always answers questions.\n"
        
    }
    
    public func format() -> String {
        self.prePrompt + self.messages.map { $0.sender.rawValue + ": " + $0.text }
            .joined(separator: "\n")
    }
    
    public func addResponse(text: String , user : Sender) {
        self.messages.append( ChatMessage(sender: user, text: text) )
    }
    /*
    public func updateResponse(text : String, user : String) {
        if let index = self.messages.lastIndex(where: { $0.user == user}) {
            self.messages[index].text = text
        }
    }
    
    public func lastMessage(user : user) -> ChatMessage? {
        self.messages.filter { $0.user == user }.last
    }*/
    
}


extension Chat : Comparable {
    public static func == (lhs: Chat, rhs: Chat) -> Bool {
        return lhs.id == rhs.id
    }

    public static func < (lhs: Chat, rhs: Chat) -> Bool {
        return lhs.date < rhs.date
    }
}
