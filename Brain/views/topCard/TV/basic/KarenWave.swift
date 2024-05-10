//
//  KarenWave.swift
//  Brain
//
//  Created by Owen O'Malley on 4/29/24.
//

import SwiftUI
import simd

public struct KarenWave: Shape {
    
    var fftSamples : ContiguousArray<Float>
    var volume : Float
    
    let indices : [Int]

    
    init(fftSamples: ContiguousArray<Float>, volume : Float) {
        self.fftSamples = fftSamples
        self.volume = volume
        self.indices = Self.fanoutReorder(length: fftSamples.count)
    }
    
    public func path(in rect: CGRect) -> Path {
        
        let baseLine = rect.midY
        let numSamples = self.fftSamples.count
        
        let xControlPointDelta = Float(rect.width) / (2 * Float(numSamples))
        
        
        let (xValues, xValuesPositiveOffset, xValuesNegativeOffset) = Self.generateXs(width: Float(rect.width), numSamples: numSamples, xOffset: xControlPointDelta)
            
            
        let yValues = Self.normalizeAndScaleSamples(fftSamples: self.fftSamples,
                                                        volume: self.volume,
                                                        heightLimit: Float(rect.midY))
    
        var path = Path()
        
        path.move(to: .init(x: 0, y: rect.height / 2))
        
        let startIdx = self.indices[0]
        
        let startPoint : CGPoint = .init(x: CGFloat(xValues[0]),
                                         y: CGFloat(yValues[startIdx]))
        
        let startFormerControlPoint : CGPoint = .init(x: CGFloat(xControlPointDelta),
                                                      y: baseLine)
        
        let startLatterControlPoint : CGPoint = .init(x: CGFloat(xValuesNegativeOffset[0]),
                                                      y: CGFloat(yValues[startIdx]))
        
        path.addCurve(to: startPoint,
                      control1: startFormerControlPoint,
                      control2: startLatterControlPoint)
        
        for idx in stride(from: 1, to: numSamples, by: 1) {
            let reorderIdx = self.indices[idx]
            let lastReorderIdx = self.indices[idx - 1]
            
            let point : CGPoint = .init(x: CGFloat(xValues[idx]), 
                                        y: CGFloat(yValues[reorderIdx]))
            let formerControlPoint : CGPoint = .init(x: CGFloat(xValuesPositiveOffset[idx - 1]),
                                                     y: CGFloat(yValues[lastReorderIdx]))
            let latterControlPoint : CGPoint = .init(x: CGFloat(xValuesNegativeOffset[idx]),
                                                     y: CGFloat(yValues[reorderIdx]))

            path.addCurve(to: point,
                          control1: formerControlPoint,
                          control2: latterControlPoint)
        }
        
        let endIdx = self.indices[self.indices.count - 1]
        
        let endPoint : CGPoint = .init(x: rect.width,
                                         y: baseLine)
        
        let endFormerControlPoint : CGPoint = .init(x: CGFloat(xValuesPositiveOffset[xValuesPositiveOffset.scalarCount - 1]),
                                                      y: CGFloat(yValues[endIdx]))
        
        let endLatterControlPoint : CGPoint = .init(x: rect.maxX - CGFloat(xControlPointDelta),
                                                      y: baseLine)
        

        
        path.addCurve(to: endPoint,
                      control1: endFormerControlPoint,
                      control2: endLatterControlPoint)
    
        return path
    }
    
    static func fanoutReorder(length : Int) -> [Int] {
        let evenArray = stride(from: 0, to: length, by: 2).map { $0 }
        var oddArray = stride(from: length - 1, through: 1, by: -2).map { $0}
        
        oddArray.append(contentsOf: evenArray)
        return oddArray
    }
    
    static func normalizeAndScaleSamples( fftSamples : ContiguousArray<Float>, volume : Float, heightLimit : Float, padding : Float = 10) -> ContiguousArray<Float> {
        
        var fftSamples = fftSamples
        
        let paddedHeightLimit = heightLimit - padding
        
        fftSamples.withContiguousMutableStorageIfAvailable { fftBufferPointer in
            fftBufferPointer.baseAddress!.withMemoryRebound(to: SIMD32<Float>.self, capacity: 1) { buffer in
                
                let maxSample = buffer.pointee.max()
                
                buffer.pointee /= maxSample
                buffer.pointee *= paddedHeightLimit
                buffer.pointee *= volume
                
                buffer.pointee.oddHalf.evenHalf *= -1
                buffer.pointee.evenHalf.oddHalf *= -1
                
                buffer.pointee += heightLimit
            }
        }
        
        return fftSamples
    }
    
    static func generateXs(width : Float, numSamples : Int, xOffset : Float) -> (xValues: SIMD32<Float>,
                                                                                 xValuesPosOffset: SIMD32<Float>,
                                                                                 xValuesNegOffset: SIMD32<Float>) {
        var xValues = SIMD32<Float>(stride(from: 1, through: 32, by: 1))
        
        xValues *= width
        xValues /= Float(numSamples + 1)
        
        let xValuesPositiveOffset = xValues + xOffset
        let xValuesNegativeOffset = xValues - xOffset
        
        return (xValues, xValuesPositiveOffset, xValuesNegativeOffset)
    }
}

#Preview {
    ZStack {
        Color.mainAccent.ignoresSafeArea()
        
        KarenWave(fftSamples: ContiguousArray<Float>(repeating: Float.random(in: 0...4.0),count: 32), volume: 0.5)
            .stroke(.green.gradient, style: StrokeStyle(lineWidth: 3.0, lineCap: .round))
    }
    
}


