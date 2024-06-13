//
//  MessageBoard.swift
//  Brain
//
//  Created by Owen O'Malley on 5/16/24.
//

import Foundation
import Observation
import AVKit

struct MessageBoardState : ~Copyable {
    var messageText : String
    var shouldAnimate : Bool
    var textIdxLimit : Int
    var textIdx : Int
}

@Observable public final class MessageBoard {
    @ObservationIgnored private(set) var temporary : MessageBoardState = .init(messageText: "", shouldAnimate: false, textIdxLimit: 0, textIdx: 0)
    @ObservationIgnored private(set) var permanent : MessageBoardState
    
    private var showTemporary : Bool = false
    
    static let characterLimit : Int = 25
    
    public var boardText : String
    
    private var updateSubTextTask : Task<Void, Never>? = nil
    
    private var audioPlayer : AVAudioPlayer? = nil
    
    private static let id = Int.random(in: 1...4) - 1
    private static let startupWaveFftDurations : [Double] = [1.5, 1.2, 2.2, 3.5]
    private static let startupWaveDelays : [Double] = [2.8, 2.0, 3.2, 4.5]
    private static let startupWaveDurations : [Double] = [2.25, 2.5, 2.9, 2.5]
    
    public let startupWaveFftDuration : Double
    public let startupWaveDelay : Double
    public let startupWaveDuration : Double


    public init(initialMessageText: String = "Load model to start messaging") {
        let textIdxLimit = Self.getMaxNumSteps(strLength: initialMessageText.count) ?? 0
        let permanentShouldAnimate = initialMessageText.count > Self.characterLimit
        
        self.permanent = .init(messageText: initialMessageText, shouldAnimate: permanentShouldAnimate, textIdxLimit: textIdxLimit, textIdx: 0)
        
        self.boardText = Self.getWindow(from: initialMessageText, start: 0) ?? "NONE"
        
        self.startupWaveFftDuration = Self.startupWaveFftDurations[Self.id]
        self.startupWaveDelay = Self.startupWaveDelays[Self.id]
        self.startupWaveDuration = Self.startupWaveDurations[Self.id]

        
    }
    //MARK: - Message Board
    public func startTextRealtimeLoop() {
        self.updateSubTextTask = Task {
            while true {
                do {
                    if self.showTemporary {
                        try await self.updateBoard(&self.temporary)
                    } else {
                        try await self.updateBoard(&self.permanent)
                    }
                } catch {
                    print("Error: \(error.localizedDescription)")
                    break
                }
            }
        }
    }
    
    public func postTemporaryMessage(_ message: String, duration : UInt64 = 3) {
        Task {
            let shouldAnimate = message.count > Self.characterLimit

            let textIdxLimit = shouldAnimate ? (Self.getMaxNumSteps(strLength: message.count) ?? 0) : message.count
            
            await MainActor.run {
                self.temporary = MessageBoardState.init(messageText: message, shouldAnimate: shouldAnimate, textIdxLimit: textIdxLimit, textIdx: 0)
                self.showTemporary = true
            }
            
            try? await Task.sleep(nanoseconds: duration * 1_000_000_000)
            
            await MainActor.run {
                self.showTemporary = false
            }
        }
    }
    
    public func postMessage(_ message: String) {
        Task {
            let shouldAnimate = message.count > Self.characterLimit

            let textIdxLimit = shouldAnimate ? (Self.getMaxNumSteps(strLength: message.count) ?? 0) : message.count
            
            await MainActor.run {
                self.permanent = MessageBoardState.init(messageText: message, shouldAnimate: shouldAnimate, textIdxLimit: textIdxLimit, textIdx: 0)
            }
        }
    }
    
    private func updateBoard(_ state : inout MessageBoardState) async throws {
        if state.shouldAnimate {
            self.boardText = Self.getWindow(from: state.messageText, start: state.textIdx) ?? ""
        } else {
            self.boardText = state.messageText
        }
        
        if state.textIdx < state.textIdxLimit {
            state.textIdx += 1
        } else {
            state.textIdx = 0
        }
        
        try await Task.sleep(nanoseconds: 200_000_000)
        
    }
    
    //MARK: - Helpers
    private static func getWindow(from str: borrowing String, start: Int) -> String? {
        
        guard start >= 0, Self.characterLimit > 0, start + Self.characterLimit <= str.count else {
            return nil
        }
        
        let startIndex = str.index(str.startIndex, offsetBy: start)
        let endIndex = str.index(startIndex, offsetBy: Self.characterLimit)
        
        // Get the substring
        let window = str[startIndex..<endIndex]
        
        return String(window)
    }
    
    private static func getMaxNumSteps(strLength : Int) -> Int? {
        
        guard Self.characterLimit <= strLength else {
            return nil
        }
        
        let maxStartIndex = strLength - Self.characterLimit
        
        return maxStartIndex
    }
    
    //MARK: - Audio
    
    public func playStartup() {
        guard let soundURL = Bundle.main.url(forResource: "startup\(Self.id)", withExtension: "aif") else {
            return
        }

        self.audioPlayer = try? AVAudioPlayer(contentsOf: soundURL)

        self.audioPlayer?.play()
    }
}
