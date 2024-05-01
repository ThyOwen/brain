//
//  WaveView.swift
//  Brain
//
//  Created by Owen O'Malley on 2/1/24.
//

import SwiftUI
import CoreGraphics

struct TVView: View {
    
    var fftSamples : [Float]
    var volume : Float 
    let shadow : CGFloat = 10
    let rimColor : Color = .mainAccent
    
    @State private var vertices : AnimatableVector = .zero
    
    init(fftSamples: [Float], volume: Float) {
        self.fftSamples = fftSamples
        self.volume = volume
        
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
            
            
            KarenWave(fftSamples: self.fftSamples, volume: self.volume)
                .stroke(.yellow.gradient,
                        style: StrokeStyle(lineWidth: 2.0, lineCap: .butt))
                .padding(.all, 12)
                .mask {
                    TV(insetAmount: 12)
                }
                
                
            
            
            TV(insetAmount: 12)
                .fill(.clear)
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
        TVView(fftSamples: (0...31).map { _ in Float.random(in: 0...4.0) }, volume: 0.5)
    }
}
