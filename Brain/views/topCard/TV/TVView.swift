//
//  WaveView.swift
//  Brain
//
//  Created by Owen O'Malley on 2/1/24.
//

import SwiftUI

struct TVView: View {
    
    let shadow : CGFloat
    let rimColor : Color
    
    @Namespace private var pannelAnimation
    
    init(rimColor : Color, shadow : CGFloat) {
        self.shadow = shadow
        self.rimColor = rimColor
    }
    
    var body: some View {
        ZStack {
            TV(insetAmount: 0)
                .fill(self.rimColor)
                .strokeBorder(
                    LinearGradient(colors: [.edgeLightShadow.opacity(0.7),.edgeDarkShadow],
                                           startPoint: UnitPoint(x: 0, y: 0),
                                           endPoint: UnitPoint(x: 1, y: 1)),
                            lineWidth: 2)
                .outerShadow(darkShadow: .darkShadow,
                             lightShadow: .lightShadow,
                             offset: shadow,
                             radius: shadow)

            TV(insetAmount: 10)
                .fill(self.rimColor)
                .strokeBorder(
                    LinearGradient(colors: [.edgeDarkShadow, .edgeLightShadow],
                                   startPoint: UnitPoint(x: 0, y: 0),
                                   endPoint: UnitPoint(x: 1, y: 1)),
                    lineWidth: 2)

            TV(insetAmount: 12)
                .colorEffect(
                    ShaderLibrary.coloredNoise(.float(0.01), .color(Color(white: 0.25)))
                )
                .innerShadow(TV(insetAmount: 12),
                             darkShadow: .black.opacity(0.7),
                             lightShadow: .white.opacity(0.3),
                             spread: 0.2,
                             radius: shadow + 10)

        }
        .aspectRatio(1.2, contentMode: .fit)
    }
}

 
#Preview {
    ZStack {
        Color.mainAccent.ignoresSafeArea()
        TVView(rimColor : .mainAccent, shadow: 10)
    }
}
