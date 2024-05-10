import Foundation 
import Observation


@Observable public class Chat {
    
    public var messages : [ChatMessage]
    public let prePrompt : String
    
    static let viewMessages = [

        ChatMessage(content: "Yeah?  Who's this?",
                    sender: .user),
        ChatMessage(content: "Sir, you're on the air.  I wonder if you'd answer a few questions.",
                    sender: .bot),
        ChatMessage(content: "Hey, Sal...Sure.",
                    sender: .user),
        ChatMessage(content: "Why are you doing this?",
                    sender: .bot),
        ChatMessage(content: "Doing what?",
                    sender: .user),
        ChatMessage(content: "Robbing a bank.",
                    sender: .bot),
        ChatMessage(content: "I don't know... they got money here.",
                    sender: .user),
        ChatMessage(content: "But I mean, why do you need to steal? Couldn't you get a job?",
                    sender: .bot),
        ChatMessage(content: "Get a job doing what?  You gotta be a member of a union, no union card - no job.",
                    sender: .user),
        ChatMessage(content: "What about, ah, non-union occupations?",
                    sender: .bot),
        ChatMessage(content: "Like what?  Bank teller?  What do they get paid -",
                    sender: .user),
        ChatMessage(content: "I'm here to talk to you, Sonny, not...",
                    sender: .bot),
        ChatMessage(content: "Wait a minute... I'm talkin' to you. I'm askin' you a question...",
                    sender: .bot),
        
    ]
    
    init(messages: [ChatMessage] = []) {
        self.messages = messages
        self.prePrompt =
        "a diologue between a human and a chatbot. The chatbot is pleasant, truthful, and always answers questions.\n"
        //"a diologue between a owen and a johnny. Owen is awesome in every way. Johnny is crazy.\n"
        
    }
    
    public func format() -> String {
        self.prePrompt + self.messages.map { $0.sender.rawValue + ": " + $0.content }
            .joined(separator: "\n")
    }
    
    public func addResponse(content: String , sender : Sender) {
        self.messages.append( ChatMessage(content: content, sender: sender) )
    }
    
    public func updateResponse(content : String, sender : Sender) {
        if let index = self.messages.lastIndex(where: { $0.sender == sender}) {
            self.messages[index].content += content
        }
    }
    
    public func lastMessage(sender : Sender) -> ChatMessage? {
        self.messages.filter { $0.sender == sender }.last
    }
    
}
