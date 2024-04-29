//
//  MicrophoneIndicatorView.swift
//  Brain
//
//  Created by Owen O'Malley on 4/28/24.
//

import SwiftUI

fileprivate struct BarColor : Identifiable {
    var color : Color
    let id = UUID()
}

struct MicrophoneIndicatorView : View {
    
    public var energyLevel : Float
    public var threshold : Double
    public var isActive : Bool
    public let maxNumBars : Int = 12
    
    private var barColor : Color { self.energyLevel > Float(self.threshold) ? Color.green : Color.red }
    private var volumeLevel : Float { self.energyLevel * Float(self.maxNumBars) }
    private var ceilVolumeLevel : Int { Int(ceil(self.volumeLevel)) }
    private var floorVolumeLevel : Int { Int(floor(self.volumeLevel)) }
    private var colors : [BarColor] { (0..<self.maxNumBars).map { BarColor(color: self.getBarColor($0)) } }
    
    var body: some View {
        ZStack {
            Capsule()
                .inset(by: 3)
                .fill(.mainAccent)
            
            Capsule()
                .fill(.mainAccent)
                .innerShadow(Capsule(),
                             darkShadow: .darkShadow,
                             lightShadow: .lightShadow,
                             spread: 0.3,
                             radius: 5)
            Capsule()
                .inset(by: 3)
                .fill(.mainAccent)
            
            HStack(spacing: 1) {
                ForEach(self.colors, id: \.id) { bar in
                    RoundedRectangle(cornerRadius: 1, style: .circular)
                        .fill(bar.color)
                        .innerShadow(RoundedRectangle(cornerRadius: 1, style: .circular),
                                     darkShadow: .darkShadow,
                                     lightShadow: .lightShadow, spread: 0.2, radius: 0.5)
                        .padding(.vertical, 3)
                        
                }
            }
            .mask {
                Capsule()
                    .inset(by: 3)
            }
            

        }
        .frame(minHeight: 30, maxHeight: 35)
    }
    
    private func getBarColor(_ idx : Int) -> Color {
        if idx >= self.ceilVolumeLevel || !self.isActive  { return Color.gray.opacity(0.1) }
        else if idx < self.floorVolumeLevel { return barColor.opacity(1.0) }
        else {
            let barOpacity : Float = ceil((self.volumeLevel - Float(self.floorVolumeLevel)) * 10)/10
            return barColor.opacity(Double(barOpacity))
        }
    }
}



#Preview {
    ZStack {
        Color.mainAccent.ignoresSafeArea()
        MicrophoneIndicatorView(energyLevel: 0.5, threshold: 0.1, isActive: false)
            .frame(width: 100)
    }
}
