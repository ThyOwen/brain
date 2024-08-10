//
//  MessageBoard.swift
//  Brain
//
//  Created by Owen O'Malley on 5/16/24.
//

import Foundation
import Observation


public struct MessageBoardState : ~Copyable {
    var messageText : String
    var shouldAnimate : Bool
    var textIdxLimit : Int
    var textIdx : Int
    
    public mutating func updateText() -> String {
        let text = if self.shouldAnimate {
            Self.getWindow(from: self.messageText, start: self.textIdx) ?? ""
        } else {
            self.messageText
        }
        
        if self.textIdx < self.textIdxLimit {
            self.textIdx += 1
        } else {
            self.textIdx = 0
        }
        
        return text
    }
    
    public static func getWindow(from str: borrowing String, start: borrowing Int) -> String? {
        
        guard start >= 0, MessageBoardManager.characterLimit > 0, start + MessageBoardManager.characterLimit <= str.count else {
            return nil
        }
        
        let startIndex = str.index(str.startIndex, offsetBy: start)
        let endIndex = str.index(startIndex, offsetBy: MessageBoardManager.characterLimit)
        
        // Get the substring
        let window = str[startIndex..<endIndex]
        
        return String(window)
    }
}

public final actor MessageBoard {
    public var temporary : MessageBoardState = .init(messageText: "", shouldAnimate: false, textIdxLimit: 0, textIdx: 0)
    public var permanent : MessageBoardState
    
    public private(set) var showTemporary : Bool = false
    
    public init(initialMessageText: consuming String) {
        let textIdxLimit = Self.getMaxNumSteps(strLength: initialMessageText.count) ?? 0
        let permanentShouldAnimate = initialMessageText.count > MessageBoardManager.characterLimit
        
        self.permanent = .init(messageText: initialMessageText, shouldAnimate: permanentShouldAnimate, textIdxLimit: textIdxLimit, textIdx: 0)

    }
    
    public func postTemporaryMessage(_ message: consuming String, duration : borrowing UInt64 = 3) async {
        let shouldAnimate = message.count > MessageBoardManager.characterLimit

        let textIdxLimit = shouldAnimate ? (Self.getMaxNumSteps(strLength: message.count) ?? 0) : message.count
        
        self.temporary = MessageBoardState.init(messageText: message, shouldAnimate: shouldAnimate, textIdxLimit: textIdxLimit, textIdx: 0)
        self.showTemporary = true
        
        try? await Task.sleep(nanoseconds: duration * 1_000_000_000)
        
        self.showTemporary = false
    }
    
    public func postMessage(_ message: consuming String) async {
        let shouldAnimate = message.count > MessageBoardManager.characterLimit

        let textIdxLimit = shouldAnimate ? (Self.getMaxNumSteps(strLength: message.count) ?? 0) : message.count
        
        self.permanent = MessageBoardState.init(messageText: message, shouldAnimate: shouldAnimate, textIdxLimit: textIdxLimit, textIdx: 0)
    }
    
    public func update() async -> String {
        if self.showTemporary {
            return self.temporary.updateText()
        } else {
            return self.permanent.updateText()
        }
    }
    
    //MARK: - Helpers
    static func getMaxNumSteps(strLength : borrowing Int) -> Int? {
        
        guard MessageBoardManager.characterLimit <= strLength else {
            return nil
        }
        
        let maxStartIndex = strLength - MessageBoardManager.characterLimit
        
        return maxStartIndex
    }
    
}

@Observable public final class MessageBoardManager {
    private var messageBoardActor : MessageBoard
    public var boardText : String = ""
    
    public static let characterLimit : Int = 25
    
    @ObservationIgnored private var updateMessageBoardTask : Task<Void, Never>? = nil
    
    init(initialMessageText: String = "load model to start usage") {
        self.messageBoardActor = .init(initialMessageText: initialMessageText)
    }
    
    public func postMessage(_ message : String) {
        Task(priority: .background) {
            await self.messageBoardActor.postMessage(message)
        }
    }
    
    public func postTemporaryMessage(_ message : String, duration : UInt64 = 5) {
        Task(priority: .background) {
            await self.messageBoardActor.postTemporaryMessage(message, duration: duration)
        }
    }
    
    public func startMessageBoardTask() {
        self.updateMessageBoardTask = Task.detached(priority: .background) {
            while true {
                let text = await self.messageBoardActor.update()
                await MainActor.run {
                    self.boardText = text
                }
                
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
    }
}

