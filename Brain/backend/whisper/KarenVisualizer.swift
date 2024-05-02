//
//  KarenVisualizer.swift
//  Brain
//
//  Created by Owen O'Malley on 4/12/24.
//

import Foundation
import Accelerate

extension Whisper {
    static func fftSlow(data: UnsafePointer<Float>,
                    inResolution: Int,
                    outResolution: Int,
                    setup: vDSP_DFT_Setup ) -> [Float] {
    
        var realIn = [Float](repeating: 0, count: inResolution)
        var imagIn = [Float](repeating: 0, count: inResolution)
        var realOut = [Float](repeating: 0, count: inResolution)
        var imagOut = [Float](repeating: 0, count: inResolution)
        
        var magnitudes = [Float](repeating: 0, count: outResolution)
        
        for i in 0...(inResolution - 1) {
            realIn[i] = data[i]
        }
        
        vDSP_DFT_Execute(setup, &realIn, &imagIn, &realOut, &imagOut)
        
            
        realOut.withUnsafeMutableBufferPointer { realOutBufferPointer in
            imagOut.withUnsafeMutableBufferPointer { imagOutBufferPointer in
                var complex = DSPSplitComplex(realp: realOutBufferPointer.baseAddress!, imagp: imagOutBufferPointer.baseAddress!)
                vDSP_zvabs(&complex, 1, &magnitudes, 1, UInt(outResolution))
            }
        }
        
        
        //normalize
        var normalizedMagnitudes = [Float](repeating: 0.0, count: outResolution)
        var scalingFactor : Float = 25.0/Float(outResolution)
        vDSP_vsmul(&magnitudes, 1, &scalingFactor, &normalizedMagnitudes, 1, UInt(outResolution))
        
        return normalizedMagnitudes
    }
    static func fft(data: ArraySlice<Float>,//UnsafePointer<Float>,
                    inResolution: Int,
                    outResolution: Int,
                    setup: vDSP_DFT_Setup ) -> [Float] {
    
        //var realIn = ContiguousArray<Float>(repeating: 0, count: inResolution)
        let imagIn = ContiguousArray<Float>(repeating: 0, count: inResolution)
        var realOut = ContiguousArray<Float>(repeating: 0, count: inResolution)
        var imagOut = ContiguousArray<Float>(repeating: 0, count: inResolution)
        
        var magnitudes = ContiguousArray<Float>(repeating: 0, count: outResolution)

        var normalizedMagnitudes = [Float](repeating: 0.0, count: outResolution)
        var scalingFactor : Float = 25.0 / Float(outResolution)
        
        data.withContiguousStorageIfAvailable { realInBufferPointer in
            imagIn.withContiguousStorageIfAvailable { imagInBufferPointer in
                realOut.withContiguousMutableStorageIfAvailable { realOutBufferPointer in
                    imagOut.withContiguousMutableStorageIfAvailable { imagOutBufferPointer in
                            vDSP_DFT_Execute(setup,
                                             realInBufferPointer.baseAddress!,
                                             imagInBufferPointer.baseAddress!,
                                             realOutBufferPointer.baseAddress!,
                                             imagOutBufferPointer.baseAddress!)
                            magnitudes.withContiguousMutableStorageIfAvailable { magnitudesBufferPointer in
                                var complex = DSPSplitComplex(realp: realOutBufferPointer.baseAddress!, imagp: imagOutBufferPointer.baseAddress!)
                                vDSP_zvabs(&complex, 1, magnitudesBufferPointer.baseAddress!, 1, UInt(outResolution))
                                
                                normalizedMagnitudes.withUnsafeMutableBufferPointer { normalizedMagnitudesBufferPointer in
                                    vDSP_vsmul(magnitudesBufferPointer.baseAddress!, 1, &scalingFactor, normalizedMagnitudesBufferPointer.baseAddress!, 1, UInt(outResolution))
                                }
                        }
                    }
                }
            }
        }

        return normalizedMagnitudes
    }
}
