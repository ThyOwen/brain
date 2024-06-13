//
//  LoadingView.swift
//  Brain
//
//  Created by Owen O'Malley on 5/20/24.
//

import SwiftUI
import Accelerate

struct LoadingPath : Shape {
    
    public static let numPoints : Int = 32
    
    private static let points : [(Float, Float)] = [
        (0, 0),
        (0.10, 0),
        (0.503, 0.356),
        (0.684, 0.55),
        (0.455, 0.412),
        (0.314, 0.198),
        (0.35, 0.023),
        (0.488, -0.046),
        (0.476, -0.249),
        (0.302, -0.393),
        (0.11, -0.466),
        (0.23, -0.327),
        (0.388, -0.171),
        (0.545, -0.02),
        (0.5826, -0.0162),
        (0.538, -0.014),
        (0.523, -0.085),
        (0.558, -0.081),
        (0.584, -0.057),
        (0.582, -0.017),
        (0.589, -0.088),
        (0.634, 0.035),
        (0.678, 0.193),
        (0.733, 0.452),
        (0.676, 0.26),
        (0.639, 0.12),
        (0.617, -0.015),
        (0.657, -0.112),
        (0.74, -0.117),
        (0.83, -0.084),
        (0.9, 0),
        (1, 0),
        ]
    
    let xUnscaledValues : Array<Float>
    let yUnscaledValues : Array<Float>
    
    init() {
        self.xUnscaledValues = Self.points.map{ $0.0 }
        self.yUnscaledValues = Self.points.map{ -$0.1 }
    }
    
    func path(in rect: CGRect) -> Path {
        
        var xValues = self.xUnscaledValues
        var yValues = self.yUnscaledValues

        xValues.withUnsafeMutableBufferPointer { xValuesBufferPointer in
            xValuesBufferPointer.baseAddress!.withMemoryRebound(to: SIMD32<Float>.self, capacity: 1) { simdBufferPointer in
                simdBufferPointer.pointee *= Float(rect.maxX)
            }
        }
        
        yValues.withUnsafeMutableBufferPointer { xValuesBufferPointer in
            xValuesBufferPointer.baseAddress!.withMemoryRebound(to: SIMD32<Float>.self, capacity: 1) { simdBufferPointer in
                //simdBufferPointer.pointee *= 2
                simdBufferPointer.pointee += 1
                simdBufferPointer.pointee /= 2
                simdBufferPointer.pointee *= Float(rect.maxY)
            }
        }
        
        let xValuesInterpolated = Self.generatePoints(values: xValues)
        let yValuesInterpolated = Self.generatePoints(values: yValues)
        
        
        var path = Path()
        
        path.move(to: .init(x: 0.0, y: rect.midY))
        
        //let startPoint : CGPoint = .init(x: CGFloat(xValuesInterpolated[1]), y: CGFloat(xValuesInterpolated[1]))
        //let startControlPoint : CGPoint = .init(x: CGFloat(xValues[0]), y: rect.midY)
        
        //path.addQuadCurve(to: startPoint, control: startControlPoint)
            
        for idx in 0..<(Self.numPoints) {
            
            let x = CGFloat(xValues[idx])
            let y = CGFloat(yValues[idx])
            
            let xInterp = CGFloat(xValuesInterpolated[idx])
            let yInterp = CGFloat(yValuesInterpolated[idx])
            
            
            let controlPoint : CGPoint = .init(x: x, y: y)
            let point : CGPoint = .init(x: xInterp, y: yInterp)
            
            path.addQuadCurve(to: point, control: controlPoint)
            
        }
        
        //path.addQuadCurve(to: point, control: controlPoint)

        
        return path
    }
    
    private static func generatePoints(values : borrowing Array<Float>) -> Array<Float> {
        
        let indices = Array<Float>.init(stride(from: -0.5, to: Float(values.count), by: 1))
                        
        let n = vDSP_Length(values.count)
        let stride = vDSP_Stride(1)

        var result = [Float](repeating: 0, count: Int(n))

        vDSP_vgenp(values, stride, indices, stride, &result, stride, n, n)
        
        return result
    }
    
    private static func scalePoints(floatArray : inout Array<Float>, value : consuming Float) {
        floatArray.withUnsafeMutableBufferPointer { xValuesBufferPointer in
            xValuesBufferPointer.baseAddress!.withMemoryRebound(to: SIMD32<Float>.self, capacity: 1) { simdBufferPointer in
                simdBufferPointer.pointee += value
            }
        }
    }
}

fileprivate struct TestView : View {
    
    @State private var showExtendedLine : Bool = false
    
    var shape : some View {
        LoadingPath()
            .trim(from: 0.0, to: self.showExtendedLine ? 1.0 : 0.0)
            .stroke(Color.lime, style: .init(lineWidth: 1.75, lineCap: .butt))
    }
    
    var body: some View {
        VStack(spacing: 80) {
            ZStack {
                Color.black
                self.shape
                    .blur(radius: 1.75, opaque: false)
                self.shape
                    .blur(radius: 0.75, opaque: false)
            }
            .frame(width: 300, height: 200)
            .animation(.easeInOut(duration: 3), value: self.showExtendedLine)
            .colorEffect(ShaderLibrary.coloredNoise(.float(0.4)))
            .drawingGroup()

            Button("toggle") {
                withAnimation {
                    self.showExtendedLine.toggle()
                }
                
            }
        }

        .onAppear {
            withAnimation {
                self.showExtendedLine = true
            }
        }
        
    }
}

#Preview {
    TestView()
}
