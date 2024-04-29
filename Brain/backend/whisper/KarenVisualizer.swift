//
//  KarenVisualizer.swift
//  Brain
//
//  Created by Owen O'Malley on 4/12/24.
//

import Foundation
import Accelerate

extension Whisper {
    static func rms(data: UnsafePointer<Float>, frameLength: UInt) -> Float {
        var val : Float = 0
        vDSP_measqv(data, 1, &val, frameLength)

        var db = log10f(val)
        //inverse dB to +ve range where 0(silent) -> 160(loudest)
        db = 160 + db;
        //Only take into account range from 120->160, so FSR = 40
        db = db - 40

        let dividor = Float(120/0.3)
        let adjustedVal = 0.3 + db/dividor
        
        return adjustedVal
    }
    
    static func fft(data: UnsafePointer<Float>,
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
    
    static func interpolate(current: Float, previous: Float) -> [Float]{
        var vals = [Float](repeating: 0, count: 11)
        vals[10] = current
        vals[5] = (current + previous)/2
        vals[2] = (vals[5] + previous)/2
        vals[1] = (vals[2] + previous)/2
        vals[8] = (vals[5] + current)/2
        vals[9] = (vals[10] + current)/2
        vals[7] = (vals[5] + vals[9])/2
        vals[6] = (vals[5] + vals[7])/2
        vals[3] = (vals[1] + vals[5])/2
        vals[4] = (vals[3] + vals[5])/2
        vals[0] = (previous + vals[1])/2
        
        return vals
    }
}
