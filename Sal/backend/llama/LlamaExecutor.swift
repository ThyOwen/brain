//
//  LlamaRuntime.swift
//  Brain
//
//  Created by Owen O'Malley on 6/18/24.
//

import Foundation
import Observation
import Hub

import struct SwiftUI.AppStorage
import enum WhisperKit.ModelState

public struct LlamaSettings {
    @AppStorage("selectedModel") public var selectedModel : String = "TinyLlama-1.1B (Q4_0, 0.6 GiB)"
}

public struct LlamaModel : Codable {
    let name : String
    let repo : String
    let url : String
    let filename : String
}

extension LlamaModel : Equatable {
    public static func ==(lhs : LlamaModel, rhs : LlamaModel) -> Bool {
        return (lhs.filename == rhs.filename) && (lhs.name == rhs.name)
    }
}

@Observable public final class Llama {
    
    @ObservationIgnored private var llamaContext: LlamaContext? = nil
    
    var messageLog = ""
    var cacheCleared = false
    
    //MARK: - Model Management
    public var modelState : ModelState = .unloaded
    public var localModelPath: String = ""
    public var availableModels: [LlamaModel] = []
    public var localModels: [LlamaModel] = []
    
    public var loadingProgressValue : Float = 0.0
    public var specializationProgressRatio: Float = 0.8
    
    public private(set) var tokensPerSecond : TimeInterval = 0.0
    public private(set) var timeToHeatUp : TimeInterval = 0.0
    public private(set) var timeForGeneration : TimeInterval = 0.0
    
    public var appSettings : LlamaSettings = .init()
    
    private var messageBoard : MessageBoardManager

    init(messageBoard : MessageBoardManager) {
        self.messageBoard = messageBoard
    }

    //MARK: - Loading Model
    
    public func loadModel(redownload: Bool = false) async throws {
        //load json of available models
        if let jsonPath = Bundle.main.url(forResource: "llama_models", withExtension: "json") {
            let data = try Data(contentsOf: jsonPath)
            let decoder = JSONDecoder()
            self.availableModels = try decoder.decode([LlamaModel].self, from: data)

            let parentFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            
            for model in availableModels {
                let fileURL = parentFileURL.appendingPathComponent(model.filename)
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    self.localModels.append(model)
                }
            }
        }
        
        let model = self.availableModels.first { $0.name == self.appSettings.selectedModel }
        
        guard let model else {
            return
        }
        
        var folder: URL?
        //check for preexistance of model
        if self.localModels.contains(model) && !redownload {
            folder = URL(fileURLWithPath: self.localModelPath).appendingPathComponent(model.filename)
        } else {
            self.messageBoard.postMessage("downloading models")
            self.modelState = .downloading
            folder = try await self.download(variant: model.filename, from: model.repo)
        }
        
        await MainActor.run {
            self.loadingProgressValue = self.specializationProgressRatio
            self.modelState = .downloaded
        }

        guard let modelFolder = folder else {
            throw LlamaError.fileSystemError
        }
        
        await MainActor.run {
            // Set the loading progress to 90% of the way after prewarm
            self.loadingProgressValue = self.specializationProgressRatio
            self.modelState = .loading
        }
        
        let progressBarTask = Task {
            await self.updateProgressBar(targetProgress: 0.9, maxTime: 240)
        }
        
        do {
            let llamaContext = try LlamaContext(with: modelFolder.path())
            await llamaContext.bench(pp: 8, tg: 4, pl: 1)
            
            self.llamaContext = consume llamaContext
            progressBarTask.cancel()
        } catch LlamaError.modelError {
            self.messageBoard.postMessage("llama error | could not load model at \(modelFolder.lastPathComponent)")
        } catch LlamaError.contextError {
            self.messageBoard.postMessage("llama error | could not load llama context)")
        } catch {
            self.messageBoard.postTemporaryMessage("Error prewarming models, retrying: \(error.localizedDescription)")
            progressBarTask.cancel()
            if !redownload {
                try await self.loadModel(redownload: true)
                return
            } else {
                // Redownloading failed, error out
                self.modelState = .unloaded
                return
            }
        }
        
        
        await MainActor.run {
            if !self.localModels.contains(model) {
                self.localModels.append(model)
            }
            
            self.loadingProgressValue = 1.0
            self.modelState = .loaded
        }
        
        self.messageBoard.postMessage("llama is now \(self.modelState.description)")
    }
    
    private func updateProgressBar(targetProgress: borrowing Float, maxTime: borrowing TimeInterval) async {
        let initialProgress = self.loadingProgressValue
        let decayConstant = -log(1 - targetProgress) / Float(maxTime)

        let startTime = Date()

        while true {
            let elapsedTime = Date().timeIntervalSince(startTime)

            // Break down the calculation
            let decayFactor = exp(-decayConstant * Float(elapsedTime))
            let progressIncrement = (1 - initialProgress) * (1 - decayFactor)
            let currentProgress = initialProgress + progressIncrement

            await MainActor.run {
                self.loadingProgressValue = currentProgress
            }
            
            self.messageBoard.postMessage("Model Progress | \((currentProgress * 1000).rounded() / 10)%")

            if currentProgress >= targetProgress {
                break
            }
            
            
            do {
                try await Task.sleep(nanoseconds: 100_000_000)
            } catch {
                break
            }
        }
    }
    
    private func download( variant: String, from repo: String, downloadBase: consuming URL? = nil ) async throws -> URL {
        let hubApi = HubApi(downloadBase: downloadBase, useBackgroundSession: false)
        let repo = Hub.Repo(id: repo, type: .models)

        print("Searching for models matching \"\(variant)\" in \(repo)")
        let modelFiles = try await hubApi.getFilenames(from: repo, matching: variant)
        let uniquePaths = Set(modelFiles.map { $0.components(separatedBy: "/").first! })

        var variantPath: String? = nil

        if uniquePaths.count == 1 {
            variantPath = uniquePaths.first
        }

        guard let variantPath else {
            // If there is still ambiguity, throw an error
            //throw WhisperError.modelsUnavailable("Multiple models found matching \"\(modelSearchPath)\"")
            throw LlamaError.fileSystemError
        }

        print("Downloading model \(variantPath)...")
        let modelFolder = try await hubApi.snapshot(from: repo, matching: variant) { progress in
            //Logging.debug(progress)
            self.loadingProgressValue = Float(progress.fractionCompleted) * self.specializationProgressRatio
        }

        let modelFolderName = modelFolder.appending(path: variantPath)
        return modelFolderName
    }

    //MARK: - Running Model
    
    public func respond(to text: borrowing String, completionLoop : (_ llamaContext : borrowing LlamaContext) async throws -> Void ) async throws {
        guard let llamaContext = self.llamaContext else {
            throw LlamaError.contextError
        }
        
        let timeOfStart = DispatchTime.now().uptimeNanoseconds

        try await llamaContext.completionInit(text: text)
        let timeOfHeatEnd = DispatchTime.now().uptimeNanoseconds
        self.timeToHeatUp = TimeInterval(timeOfHeatEnd - timeOfStart) / 1_000_000_000
        
        try await completionLoop(llamaContext)
        /*
        while await llamaContext.numCur < llamaContext.numLen {
            let result = await llamaContext.completionLoop()
        }
        */
        
        let timeOfEnd = DispatchTime.now().uptimeNanoseconds
        self.timeForGeneration = TimeInterval(timeOfEnd - timeOfHeatEnd) / 1_000_000_000
        self.tokensPerSecond = TimeInterval(await llamaContext.numLen) / self.timeForGeneration

        Task { await llamaContext.clear() }
    }

    public func clear() async {
        guard let llamaContext else {
            return
        }

        await llamaContext.clear()
    }
       
}


#if(targetEnvironment(simulator))
import SwiftUI

struct LlamaTestView : View {
    
    @State private var llama : Llama = .init(messageBoard: MessageBoardManager.init())
    
    var body: some View {
        Button {
            Task {
                do {
                    try await self.llama.loadModel()
                } catch {
                    print(error.localizedDescription)
                }
            }
        } label: {
            Circle()
        }
    }
}

#Preview {
    LlamaTestView()
}
#endif
