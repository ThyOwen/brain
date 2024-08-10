//
//  Wave.swift
//  Brain
//
//  Created by Owen O'Malley on 6/17/24.
//

import Foundation
import Accelerate
import AVFAudio

@Observable public final class WaveManager {
    
    public weak var whisper : Whisper? = nil
    public weak var espeak : ESpeak? = nil
    
    @ObservationIgnored public var whisperBuffer : SIMD32<Float> = .init(repeating: 0.0)
    @ObservationIgnored public var espeakBuffer : SIMD32<Float> = .init(repeating: 0.0)
    
    @ObservationIgnored public var whisperVolume : Float = 0.0
    @ObservationIgnored public var espeakVolume : Float = 0.0
    
    public static let fftInResolution : Int = 64
    public static let fftOutResolution : Int = 32
    public static let fftSetup : vDSP_DFT_Setup = vDSP_DFT_zop_CreateSetup(nil, UInt(WaveManager.fftInResolution), vDSP_DFT_Direction.FORWARD)!
    public static let zerosBuffer : ContiguousArray<Float> = .init(repeating: 0.0, count: WaveManager.fftInResolution)
    
    public var fftMagnitudes : SIMD32<Float> = .init(repeating: 0.0)
    public var volume : Float = 1.0
    
    private var audioBeingGenerated : Bool {
        if let whisper = self.whisper {
            return whisper.isRecording && whisper.isTranscribing
        } else {
            return false
        }
    }
    
    @ObservationIgnored private var updateWaveTask : Task<Void, Never>? = nil
    
    @inlinable public func updateWhisperBuffer(_ samples : consuming ArraySlice<Float>, volume : Float) {
        samples.withContiguousStorageIfAvailable { samplesBufferPointer in
            Self.fft(samples: samplesBufferPointer.baseAddress!, writeTo: &self.whisperBuffer)
        }
        self.whisperVolume = consume volume
    }
    
    @inlinable public func updateEspeakBuffer(_ samplesBufferPointer : consuming UnsafePointer<Float>, volume : Float) {
        Self.fft(samples: samplesBufferPointer, writeTo: &self.espeakBuffer)
        self.espeakVolume = consume volume
    }
    
    //MARK: - Visualize Task
    
    private func visualizeCurrentBuffer() async {
        guard let whisperKit = self.whisper?.whisperKit else {
            return
        }
        
        let currentBuffer = whisperKit.audioProcessor.audioSamples.suffix(WaveManager.fftInResolution)
        
        self.updateWhisperBuffer(currentBuffer, volume: self.whisper?.lastBufferEnergy ?? 0.0)
        
        let fftNewBuffer = self.espeakBuffer + self.whisperBuffer
        let newVolume = self.whisperVolume + self.espeakVolume
        
        await MainActor.run {
            self.fftMagnitudes = consume fftNewBuffer
            self.volume = consume newVolume
        }
        
        try? await Task.sleep(nanoseconds: 20_000_000)
    }
    
    public func startWaveTask() {
        self.updateWaveTask = Task.detached(priority: .high) {
            while true {
                await self.visualizeCurrentBuffer()
            }
        }
    }
    
    @inlinable static func fft(samples : consuming UnsafePointer<Float>, writeTo outputBuffer : inout SIMD32<Float>) {
        var realOut = ContiguousArray<Float>(repeating: 0.0, count: Self.fftInResolution)
        var imagOut = ContiguousArray<Float>(repeating: 0.0, count: Self.fftInResolution)
        
        var magnitudes = ContiguousArray<Float>.init(repeating: 0.0, count: Self.fftOutResolution)
                
        Self.zerosBuffer.withContiguousStorageIfAvailable { imagInBufferPointer in
            realOut.withContiguousMutableStorageIfAvailable { realOutBufferPointer in
                imagOut.withContiguousMutableStorageIfAvailable { imagOutBufferPointer in
                        vDSP_DFT_Execute(Self.fftSetup,
                                         samples,
                                         imagInBufferPointer.baseAddress!,
                                         realOutBufferPointer.baseAddress!,
                                         imagOutBufferPointer.baseAddress!)
                        magnitudes.withContiguousMutableStorageIfAvailable { magnitudesBufferPointer in
                            var complex = DSPSplitComplex(realp: realOutBufferPointer.baseAddress!, imagp: imagOutBufferPointer.baseAddress!)
                            vDSP_zvabs(&complex, 1, magnitudesBufferPointer.baseAddress!, 1, UInt(Self.fftOutResolution))
                            
                            magnitudesBufferPointer.baseAddress!.withMemoryRebound(to: SIMD32<Float>.self, capacity: 1) { magnitudesSIMD in
                                //scale down the big boi samples around 1 hertz
                                magnitudesSIMD.pointee.lowHalf.lowHalf.lowHalf *= SIMD4<Float>(0.2, 0.4, 0.6, 0.8)
                                
                                if !magnitudesSIMD.pointee[0].isNaN {
                                    outputBuffer = magnitudesSIMD.pointee
                                }
                            }
                    }
                }
            }
        }
    }
}
