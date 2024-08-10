//
//  KarenWave.swift
//  Brain
//
//  Created by Owen O'Malley on 4/29/24.
//

import SwiftUI
import simd

public struct KarenWave: Shape {
    
    let fftMagnitudes : SIMD32<Float>
    let volume : Float
    
    static let indices : [Int] = Self.fanoutReorder(length: WaveManager.fftOutResolution)
    
    init(fftMagnitudes : SIMD32<Float>, volume : Float) {
        self.fftMagnitudes = fftMagnitudes

        self.volume = volume
    }
    
    public func path(in rect: CGRect) -> Path {
        
        guard self.fftMagnitudes.max() != 0.0 else {
            return Path { path in
                path.move(to: .init(x: 0.0, y: rect.midY))
                path.addLine(to: .init(x: rect.maxX, y: rect.midY))
            }
        }

        let numSamples = 32
        
        let xControlPointDelta = Float(rect.width) / (2 * Float(numSamples))
        
        
        let (xValues, xValuesPositiveOffset, xValuesNegativeOffset) = Self.generateXs(width: Float(rect.width), numSamples: numSamples, xOffset: xControlPointDelta)
            
            
        let yValues = Self.normalizeAndScaleSamples(fftMagnitudes: self.fftMagnitudes,
                                                    volume: self.volume,
                                                    heightLimit: Float(rect.midY))
        
        var path = Path()
        
        path.move(to: .init(x: 0, y: rect.height / 2))
        
        let startIdx = Self.indices[0]
        
        let startPoint : CGPoint = .init(x: CGFloat(xValues[0]),
                                         y: CGFloat(yValues[startIdx]))
        
        let startFormerControlPoint : CGPoint = .init(x: CGFloat(xControlPointDelta),
                                                      y: rect.midY)
        
        let startLatterControlPoint : CGPoint = .init(x: CGFloat(xValuesNegativeOffset[0]),
                                                      y: CGFloat(yValues[startIdx]))
        
        path.addCurve(to: startPoint,
                      control1: startFormerControlPoint,
                      control2: startLatterControlPoint)
        
        for idx in stride(from: 1, to: numSamples, by: 1) {
            let reorderIdx = Self.indices[idx]
            let lastReorderIdx = Self.indices[idx - 1]
            
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
        
        let endIdx = Self.indices[WaveManager.fftOutResolution - 1]
        
        let endPoint : CGPoint = .init(x: rect.width,
                                         y: rect.midY)
        
        let endFormerControlPoint : CGPoint = .init(x: CGFloat(xValuesPositiveOffset[xValuesPositiveOffset.scalarCount - 1]),
                                                      y: CGFloat(yValues[endIdx]))
        
        let endLatterControlPoint : CGPoint = .init(x: rect.maxX - CGFloat(xControlPointDelta),
                                                      y: rect.midY)
        

        
        path.addCurve(to: endPoint,
                      control1: endFormerControlPoint,
                      control2: endLatterControlPoint)
    
        return path
    }
    
    static func fanoutReorder(length : borrowing Int) -> [Int] {
        let evenArray = stride(from: 0, to: length, by: 2).map { $0 }
        var oddArray = stride(from: length - 1, through: 1, by: -2).map { $0}
        
        oddArray.append(contentsOf: evenArray)
        return oddArray
    }
    
    private static func normalizeAndScaleSamples( fftMagnitudes : consuming SIMD32<Float>,
                                                  volume : consuming Float,
                                                  heightLimit : Float,
                                                  padding : Float = 10) -> SIMD32<Float> {
        
        let paddedHeightLimit = heightLimit - padding
        
        let maxSample = fftMagnitudes.max()
                
        fftMagnitudes /= maxSample
        fftMagnitudes *= paddedHeightLimit
        fftMagnitudes *= volume
                
        fftMagnitudes.oddHalf.evenHalf *= -1
        fftMagnitudes.evenHalf.oddHalf *= -1
                
        fftMagnitudes += heightLimit

        
        return fftMagnitudes
    }
    
    private static func generateXs(width : Float, numSamples : Int, xOffset : Float) -> (xValues: SIMD32<Float>,
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

fileprivate struct TestView : View {
    
    @State var fftMagnitudes : SIMD32<Float> = .init(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    
    var body: some View {
        ZStack {
            Color.mainAccent.ignoresSafeArea()
            
            KarenWave(fftMagnitudes: self.fftMagnitudes, volume: 0.5)
                .stroke(.green.gradient, style: StrokeStyle(lineWidth: 3.0, lineCap: .round))
        }
    }
}

#Preview {
    TestView()
    
}


