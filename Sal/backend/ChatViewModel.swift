//
//  ViewModel.swift
//  Brain
//
//  Created by Owen O'Malley on 5/4/24.
//

import Foundation
import SwiftData

public enum ChatViewModelState {
    case unloaded, loading, ready, thinking
}

@Observable public final class ChatViewModel {
    
    public private(set) var state : ChatViewModelState = .unloaded
    
    public private(set) var whisper : Whisper
    public private(set) var espeak : ESpeak
    public private(set) var llama : Llama
    
    public private(set) var chat : ChatManager
    
    public var wave : WaveManager
    public var messageBoard : MessageBoardManager
    
    public private(set) var singleResponseRunLoop : Task<Void, Never>? = nil
    
    //MARK: State
    
    public var areModelsLoaded : Bool {
        self.whisper.modelState == .loaded && 
        self.llama.modelState == .loaded &&
        self.espeak.modelState == .loaded &&
        self.chat.modelContainer != nil
    }
    
    //MARK: Params
    
    public let numTokensBeforeSalSpeaks : Int = 30
    public let numBuffersBeforeAutoSend : Int = 10
    
    public init() {
        let messageBoard = MessageBoardManager()
        let wave = WaveManager()
        self.llama = Llama(messageBoard: messageBoard)
        self.whisper = Whisper(messageBoard: messageBoard)
        self.espeak = ESpeak(messageBoard: messageBoard, wave: wave)
        self.chat = ChatManager(messageBoard: messageBoard)

        self.messageBoard = messageBoard
        self.wave = wave
        
    }
    
    public func loadModels() async {
        
        switch self.state {
        case .unloaded:
            break
        case .loading:
            self.messageBoard.postTemporaryMessage("please wait for model to finish loading")
            return
        case .ready, .thinking:
            self.messageBoard.postTemporaryMessage("model is already ready")
            return
        }
        
        self.state = .loading
        
        do {
            try await self.espeak.loadModel()
            try await self.whisper.loadModel()
            try await self.llama.loadModel()
            try await self.chat.loadModelContainer()
        } catch {
            self.messageBoard.postTemporaryMessage(error.localizedDescription, duration: 7)
        }
        
#if os(macOS)
        self.whisper.getAudioDevicesMacOS()
#endif
        
        self.wave.whisper = self.whisper
        self.wave.espeak = self.espeak
        
        self.wave.startWaveTask()

        if !self.areModelsLoaded {
            self.state = .unloaded
            self.messageBoard.postMessage("SAL failed to start")
        } else {
            self.state = .ready
            self.messageBoard.postMessage("ready to converse")
        }
        
    }
    
    public func startSingleResponse() {
        guard self.areModelsLoaded else {
            self.messageBoard.postTemporaryMessage("must load model before usage")
            return
        }
        
        guard let activeChat = self.chat.activeChat else {
            self.messageBoard.postTemporaryMessage("error | chat manager and active chat are nil")
            return
        }
        
        guard self.singleResponseRunLoop == nil else {
            self.messageBoard.postTemporaryMessage("SAL is already running")
            return
        }
        
        self.singleResponseRunLoop = Task(priority: .userInitiated) {
            do {
                self.state = .thinking
                
                try await self.whisper.realtimeRecord(emptyBufferLimit: self.numBuffersBeforeAutoSend)
                
                let unconfirmedText = self.whisper.unconfirmedSegments.map { $0.text }.joined(separator: "")
                let confirmedText = self.whisper.confirmedSegments.map { $0.text }.joined(separator: "")
                
                let userText = "<s>\(consume unconfirmedText + consume confirmedText)</s>"
                
                let userMessage : ChatMessage = .init(sender: .user, text: userText, tokensPerSecondForGeneration: self.whisper.tokensPerSecond)
                
                var salResponse : ChatMessage = .init(sender: .sal, text: "<s>", tokensPerSecondForGeneration: 0)
                
                activeChat.messages.append(userMessage)
                
                let text = activeChat.formatToString() + salResponse.description
                
                try await self.llama.respond(to: text) { llamaContext in
                    
                    var tokenCounter : Int = 0
                    var responseText : String = ""

                    while await !llamaContext.isDone {
                        let (resultString, _)  = try await llamaContext.completionLoop()
                        
                        salResponse.text += resultString
                        
                        tokenCounter += 1
                        responseText += resultString
                        
                        if salResponse.text.suffix(4) == "</s>" {
                            let speechText = responseText.replacingOccurrences(of: "</s>", with: "")

                            self.espeak.generateSpeech(with: speechText)
                            break
                        }
                        
                        if tokenCounter % self.numTokensBeforeSalSpeaks == 0 {
                            
                            //responseText.contains("/s")
                            let speechText = responseText.replacingOccurrences(of: "</s", with: "")
                            self.espeak.generateSpeech(with: speechText)
                            
                            responseText = ""
                        }
                    }

                }
                
                activeChat.messages.append(salResponse)
                
                try await MainActor.run {
                    try self.chat.modelContainer?.mainContext.save()
                }
                                
            } catch {
                self.messageBoard.postTemporaryMessage(error.localizedDescription, duration: 10)
            }
            
            self.singleResponseRunLoop = nil
        }
    }
    
    public func startRunLoop() {

    }
       
}
