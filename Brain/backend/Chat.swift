import Foundation 
import Observation

@Observable class test {
    
}


public struct Chat {
    
    public var messages : [ChatMessage]
    public let prePrompt : String
    
    
    init(messages: [ChatMessage] = ChatMessage.testMessages) {
        self.messages = messages
        self.prePrompt =
        "a diologue between a human and a chatbot. The chatbot is pleasant, truthful, and always answers questions.\n"
        //"a diologue between a owen and a johnny. Owen is awesome in every way. Johnny is crazy.\n"
        
    }
    
    public func format() -> String {
        self.prePrompt + self.messages.map { $0.sender.rawValue + ": " + $0.content }
            .joined(separator: "\n")
    }
    
    public mutating func addResponse(content: String , sender : Sender) {
        self.messages.append(
            ChatMessage(content,
                sender: sender
                
            )
        )
    }
    
    public mutating func updateResponse(content : String, sender : Sender) {
        if let index = self.messages.lastIndex(where: { $0.sender == sender}) {
            self.messages[index].content += content
        }
    }
    
    public func lastMessage(sender : Sender) -> ChatMessage? {
        self.messages.filter { $0.sender == sender}.last
    }
    
}
