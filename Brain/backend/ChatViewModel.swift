//
//  ViewModel.swift
//  Brain
//
//  Created by Owen O'Malley on 5/4/24.
//

import Foundation


@Observable class ChatViewModel {
    var messageText : String
    var messageTextShouldFlash : Bool
    var characterLimit : Int
    
    var showWave : Bool = true
    
    static let characterLimitUpperBound : Int = 15
    static let characterLimitLowerBound : Int = 8

    private var textIdx : Int = 0
    
    private var shouldAnimate : Bool {
        self.messageText.count > self.characterLimit
    }
    
    private var textIdxLimit : Int {
        if self.shouldAnimate {
            Self.getMaxNumSteps(strLength: self.messageText.count, windowSize: self.characterLimit) ?? 0
        } else {
            self.textIdxLimit
        }
    }
    
    public var subText : String {
        if self.shouldAnimate {
            Self.getWindow(from: self.messageText, size: self.characterLimit, start: self.textIdx) ?? ""
        } else {
            self.messageText
        }
    }
    
    var updateSubTextTask : Task<Void, Never>? = nil
    
    init(messageText: String) {
        self.messageText = messageText
        self.messageTextShouldFlash = false
        self.characterLimit = Self.characterLimitUpperBound
    }
    
    func startTextRealtimeLoop() {
        self.updateSubTextTask = Task {
            while self.shouldAnimate {
                do {
                    try await self.updateText()
                } catch {
                    print("Error: \(error.localizedDescription)")
                    break
                }
            }
        }
    }
    
    func updateText() async throws {
        if self.textIdx < self.textIdxLimit {
            self.textIdx += 1
        } else {
            try await Task.sleep(nanoseconds: 800_000_000)
            self.textIdx = -1
            try await Task.sleep(nanoseconds: 800_000_000)
            self.textIdx = 0
            try await Task.sleep(nanoseconds: 800_000_000)
        }
        try await Task.sleep(nanoseconds: 200_000_000)
    }
    
    static func getWindow(from str: String, size: Int, start: Int) -> String? {
        
        guard start >= 0, size > 0, start + size <= str.count else {
            return nil
        }
        
        let startIndex = str.index(str.startIndex, offsetBy: start)
        let endIndex = str.index(startIndex, offsetBy: size)
        
        // Get the substring
        let window = str[startIndex..<endIndex]
        
        return String(window)
    }
    
    static func getMaxNumSteps(strLength : Int, windowSize: Int) -> Int? {
        
        guard windowSize <= strLength else {
            return nil
        }
        
        let maxStartIndex = strLength - windowSize
        
        return maxStartIndex
    }
}

