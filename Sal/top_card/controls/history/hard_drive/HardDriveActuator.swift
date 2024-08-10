//
//  HardDriveActuator.swift
//  Sal
//
//  Created by Owen O'Malley on 7/8/24.
//

import SwiftUI


struct HardDriveActuator : Shape {

    public let tipOffset : CGPoint
    
    func path(in rect: CGRect) -> Path {
        Path { path in
            
            let pivotHeight : CGFloat = rect.maxY //- rect.midX
            
            let tipWidth : CGFloat = rect.midX * self.tipOffset.x
            let tipHeight : CGFloat = rect.midX * self.tipOffset.y
            
            
            let hypot : CGFloat = hypot((rect.maxY - rect.midX - tipHeight), tipWidth)
        
            let α : CGFloat = acos(rect.midX / hypot)
            let ß : CGFloat = asin(tipWidth / hypot)
            
            let Φ = (.pi / 2) - acos(rect.midX / pivotHeight)
            let θ = (.pi / 2) - (α + ß)

            let anchorX = cos(Φ) * rect.midX
            let anchorY = sin(Φ) * rect.midX
            let anchorHeight = pivotHeight - anchorY

            let rightAnchor : CGPoint = .init(x: rect.midX + anchorX, y: anchorHeight)

            path.move(to: .init(x: rect.midX, y: 0))
            path.addLine(to: rightAnchor)
            
            path.addArc(center: .init(x: rect.midX, y: pivotHeight),
                        radius: rect.midX,
                        startAngle: Angle(radians: -Φ),
                        endAngle: Angle(radians: .pi + θ),
                        clockwise: false)
            
            path.addLine(to: .init(x: rect.midX - tipWidth, y: tipHeight))
            path.closeSubpath()
            

            
        }
    }
}

fileprivate struct TestView : View {
    
    @State private var angle : Angle = .zero
    
    var body: some View {
        ZStack {
            Color.mainAccent.ignoresSafeArea()
            HardDriveActuator(tipOffset: .init(x: 0.3, y: 0.7))
                .frame(width: 100, height: 300)
                .rotationEffect(self.angle, anchor: .bottom)
            
            Slider(value: $angle.degrees, in: 0.0 ... 360.0)
                .padding(.horizontal, 50)
        }

    }
}
#Preview {
    TestView()
}
