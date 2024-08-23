import Foundation 
import Observation
import SwiftData

public enum ChatManagerError : Error {
    case chatModelContainerError, activeChatError, chatHistoryError
}

public enum ChatSender : String, Codable {
    case sal = "bot"
    case user = "user"
}

public struct ChatMessage : Codable, CustomStringConvertible {
    public let sender : ChatSender
    public var text : String
    public let date : Date
    public let tokensPerSecondForGeneration : TimeInterval
    
    public var description: String {
        self.sender.rawValue + ": " + self.text
    }
    
    init(sender: ChatSender, text: consuming String, tokensPerSecondForGeneration : TimeInterval) {
        self.sender = sender
        self.text = text
        self.tokensPerSecondForGeneration = tokensPerSecondForGeneration
        self.date = .now
    }
    
    
}

extension ChatMessage : Comparable {
    public static func < (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        return lhs.date > rhs.date
    }
}

extension ChatMessage : Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.sender)
        hasher.combine(self.text)
        hasher.combine(self.date)
    }
}

@Model public final class Chat {
    
    public var messages : [ChatMessage] = []
    public let prePrompt : String
    public let date : Date = Date.now
    
    public let whisperModelName : String = ""
    public let llamaModelName : String = ""
    
    public var summary : String = ""
    public var title : String = ""

    init(withPrePrompt prePrompt : String) {
        self.prePrompt = prePrompt
    }
    
    public func formatToString() -> String {
        self.prePrompt + self.messages.map { $0.description }.joined(separator: "\n") + "\n"
    }
}

@Observable public final class ChatManager {
    
    public private(set) var modelContainer : ModelContainer? = nil
    public private(set) var activeChat : Chat? = nil
    
    public private(set) var chatHistory : [Chat] = []


    private var messageBoard : MessageBoardManager
    
    
    init(messageBoard : MessageBoardManager) {
        self.messageBoard = messageBoard
    }
    
    @MainActor public func loadModelContainer(useDummyChats : Bool = true) throws {
        let modelConfiguration = ModelConfiguration(for: Chat.self, isStoredInMemoryOnly: true)

        self.modelContainer = try ModelContainer(for: Chat.self, configurations: modelConfiguration)
        
        guard useDummyChats else {
            return
        }
        
        
        for idx in (0...10) {

            let exampleChat = Chat.init(withPrePrompt: "Lorem ipsum dolor sit amet, consectetur adipiscing elit.")
            
            exampleChat.title = "\(idx) - Lorem Ipsum"
            
            exampleChat.summary = "Lorem ipsum dolor sit amet, consectetur adipiscing elit."
            
            let exampleMessages : [ChatMessage] = [
                .init(sender: .user, text: "Suspendisse quis quam nibh.", tokensPerSecondForGeneration: 0.9),
                .init(sender: .sal, text: "Fusce condimentum faucibus nisl tristique congue.", tokensPerSecondForGeneration: 0.9),
                .init(sender: .user, text: "Vestibulum purus sem, mattis sed iaculis sed, fermentum non urna.", tokensPerSecondForGeneration: 0.9),
                .init(sender: .sal, text: "Maecenas commodo gravida ultrices.", tokensPerSecondForGeneration: 0.9),
                .init(sender: .user, text: "Proin id felis dignissim, euismod eros sit amet, maximus velit.", tokensPerSecondForGeneration: 0.9),
                .init(sender: .sal, text: "Duis quis vulputate urna, eget euismod metus.", tokensPerSecondForGeneration: 0.9),
                .init(sender: .user, text: "Sed mollis porttitor viverra.", tokensPerSecondForGeneration: 0.9),
                .init(sender: .sal, text: "Morbi a magna sem.", tokensPerSecondForGeneration: 0.9),
                
            ]
            
            exampleChat.messages = exampleMessages

            self.modelContainer?.mainContext.insert(exampleChat)
        }
    }
    
    @MainActor public func createChat(withPrePrompt prePrompt : consuming String) {
        guard let context = self.modelContainer?.mainContext else {
            self.messageBoard.postTemporaryMessage("error loading context")
            return
        }
        
        //let prePrompt = "A conversation between a Robot and a Human. the Robot is kind but demonstrates a hint of sass in the conversation."
        
        let chat = Chat(withPrePrompt: prePrompt)
        
        self.activeChat = chat
        
        context.insert(chat)
    }
    
    @MainActor public func loadChatHistory(fetchLimit : Int? = nil) {
        guard let context = self.modelContainer?.mainContext else {
            self.messageBoard.postTemporaryMessage("Error | there is no context for chat history")
            return
        }
 
        let predicate : Predicate<Chat>?
        
        if let activeChatID = self.activeChat?.persistentModelID {
            predicate = #Predicate<Chat> { $0.persistentModelID != activeChatID }
        } else {
            predicate = nil
        }
        
        var previousChatsFetchDescription = FetchDescriptor<Chat>.init(
            predicate: predicate,
            sortBy: [.init(\.date)]
        )
        
        if let fetchLimit = fetchLimit {
            previousChatsFetchDescription.fetchLimit = fetchLimit
        }
        
        do {
            self.chatHistory = try context.fetch(previousChatsFetchDescription)
        } catch {
            self.messageBoard.postMessage("error | could not fetch chat history")
        }
    }
    
    @MainActor public func resumeChat(at idx : Int) {
        guard !self.chatHistory.isEmpty else {
            self.messageBoard.postTemporaryMessage("Error | chat history is or empty")
            return
        }
        
        guard idx < self.chatHistory.count else {
            self.messageBoard.postTemporaryMessage("Error | selected chat is out of bounds")
            return
        }
        
        let chatTitle = self.chatHistory[idx].title
        
        self.activeChat = self.chatHistory[idx]
        
        self.messageBoard.postTemporaryMessage("successful resumption of chat titled \(consume chatTitle)", duration: 10)
        
    }
    
    @MainActor public func deleteChat(at idx : Int) {
        guard !self.chatHistory.isEmpty else {
            self.messageBoard.postTemporaryMessage("Error | chat history is or empty")
            return
        }
        
        guard idx < self.chatHistory.count else {
            self.messageBoard.postTemporaryMessage("Error | selected chat is out of bounds")
            return
        }
        
        guard let context = self.modelContainer?.mainContext else {
            self.messageBoard.postTemporaryMessage("Error | there is no context for chat history")
            return
        }
        
        let chatTitle = self.chatHistory[idx].title
        
        context.delete(self.chatHistory[idx])
        
        do {
            try context.save()
            self.messageBoard.postTemporaryMessage("sucessful deletion of chat titled \(consume chatTitle)", duration: 10)
        } catch {
            self.messageBoard.postTemporaryMessage("Error | save error")
        }
    }
    
}

import SwiftUI

fileprivate struct TestView : View {
    
    @State private var chat : ChatManager = .init(messageBoard: .init())
    
    
    
    var body : some View {
        VStack {
            
            ScrollView {
                LazyVStack {
                    ForEach(self.chat.chatHistory) { chat in
                        Text("\(chat.persistentModelID.id.hashValue)")
                    }
                }
            }
            
            HStack {
                Text("active chat")
                Text("\(String(describing: self.chat.activeChat?.persistentModelID.id.hashValue))")
            }
            
            HStack {
                Button("load chat history") {
                    self.chat.loadChatHistory()
                }
                
                Button("create new chat") {
                    let prePrompt = ""
                    self.chat.createChat(withPrePrompt: prePrompt)
                }
                
                Button("set chat as active") {
                    self.chat.resumeChat(at: 5)
                }

                
            }.onAppear {
                try? self.chat.loadModelContainer()
            }
        }
    }
}

#Preview {
    TestView()
}
