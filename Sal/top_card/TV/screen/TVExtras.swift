//
//  TVExtras.swift
//  Brain
//
//  Created by Owen O'Malley on 2/2/24.
//

import SwiftUI

struct TV : InsettableShape {
    
    var insetAmount = 0.0
    
    func path(in rect: CGRect) -> Path {
        Path { path in
            
            path.move(to: CGPoint(x: rect.minX + insetAmount, y: rect.midY))
            
            path.addQuadCurve(to: CGPoint(x: rect.midX , y: rect.minY + insetAmount),
                              control: CGPoint(x: rect.minX + insetAmount, y: rect.minY + insetAmount))
            
            path.addQuadCurve(to: CGPoint(x: rect.maxX - insetAmount, y: rect.midY),
                              control: CGPoint(x: rect.maxX - insetAmount, y: rect.minY + insetAmount))
            
            path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY - insetAmount),
                              control: CGPoint(x: rect.maxX - insetAmount, y: rect.maxY - insetAmount))
            
            path.addQuadCurve(to: CGPoint(x: rect.minX + insetAmount, y: rect.midY),
                              control: CGPoint(x: rect.minX + insetAmount, y: rect.maxY - insetAmount))
        }
    }
    
    func inset(by amount: CGFloat) -> some InsettableShape {
        var tv = self
        tv.insetAmount += amount
        return tv
    }
}

struct Stripes: Shape {
    
    private let numStripes : CGFloat
    
    init(numStripes : CGFloat) {
        self.numStripes = numStripes
    }
    
    func path(in rect: CGRect) -> Path {
        Path { path in
            let width = rect.size.width
            let height = rect.size.height
            
            for y in stride(from: height * 0.05,
                            through: height,
                            by: (height / self.numStripes)) {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: width, y: y))
            }
        }
    }
}

struct Bars : View {
    private let numStripes : CGFloat
    private let clipShape : any Shape
    private let lineWidth : CGFloat
    
    init(numStripes: CGFloat, clipShape: any Shape, lineWidth: CGFloat) {
        self.numStripes = numStripes
        self.clipShape = clipShape
        self.lineWidth = lineWidth
    }
    
    var body: some View {
        Stripes(numStripes: CGFloat(self.numStripes))
            .stroke(.gray.opacity(0.2) ,lineWidth: self.lineWidth)
            .clipShape(TV())
    }
}

#Preview {
    ZStack {
        TV()
        Bars(numStripes: 18, clipShape: TV(), lineWidth: 2)
    }.frame(height: 300)
}
