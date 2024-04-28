//
//  MicrophoneDialView.swift
//  Brain
//
//  Created by Owen O'Malley on 4/16/24.
//

import SwiftUI


fileprivate struct BarColor : Identifiable {
    var color : Color
    let id = UUID()
}

struct MicrophoneIndicatorView : View {
    
    public var loudness : Float
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
            Capsule().fill(.mainAccent)
                .innerShadow(Capsule(),
                             darkShadow: .darkShadow,
                             lightShadow: .lightShadow,
                             spread: 0.3,
                             radius: 5)
            Capsule().inset(by: 3).fill(.mainAccent)
            HStack(spacing: 1) {
                ForEach(self.colors, id: \.id) { bar in
                    Rectangle()
                        .fill(bar.color)
                }
            }
            .mask {
                Capsule().inset(by: 3)
            }
        }.frame(minHeight: 25, maxHeight: 30)
    }
    
    private func getBarColor(_ idx : Int) -> Color {
        if idx >= self.ceilVolumeLevel || !self.isActive  { return Color.gray.opacity(0.1) }
        else if idx < self.floorVolumeLevel { return barColor.opacity(1.0) }
        else {
            let barOpacity : Float = ceil((self.volumeLevel - Float(self.floorVolumeLevel)) * 10)/10
            return barColor.opacity(Double(barOpacity)) }
    }
}

public enum MicrophoneDialGestureState {
    case inactive
    case active(translation : CGSize)
    
    var isActive: Bool {
        switch self {
        case .inactive:
            return false
        case .active:
            return true
        }
    }
    
    var angle: Angle {
        switch self {
        case .inactive:
            return .zero
        case .active(let translation):
            //let (translation, previousAngle) = tuple
            return Self.getAngle(translation: translation)
        }
    }
    
    static func getAngle(translation : CGSize) -> Angle {
        return -Angle(degrees: translation.width + translation.height)
    }
}

struct MicrophoneDialView: View {
    
    @Binding var sensitivity : Double
    
    @State private var tempSensitivity : Double
    
    @GestureState var gestureState : MicrophoneDialGestureState = .inactive
    
    private var dialAngle : Angle {
        self.gestureState.isActive ? Angle(degrees: self.tempSensitivity * 180) + self.gestureState.angle : Angle(degrees: self.tempSensitivity * 180)
    }
    
    let numVolNotches : Int = 8
    let radiusOffsetVolNotches : CGFloat = 15
    
    var radiusVolNotches : [Angle] { (0...self.numVolNotches).map { idx in
            .radians((Double(idx) / Double(self.numVolNotches)) * .pi)
        }
    }
    
    init(sensitivity : Binding<Double>) {
        self._sensitivity = sensitivity
        self.tempSensitivity = sensitivity.wrappedValue
    }
    
    var volumeGesture : some Gesture {
        DragGesture()
            .updating(self.$gestureState) { currentState, gestureState, transaction in
                gestureState = .active(translation: currentState.translation)
            }
            .onEnded { currentState in
                let sensitivityCandiate = (MicrophoneDialGestureState.getAngle(translation: currentState.translation).degrees / 180) + self.tempSensitivity
                
                self.tempSensitivity = sensitivityCandiate
                if sensitivityCandiate < 0.0 {
                    withAnimation(.interactiveSpring) {
                        self.tempSensitivity = 0.0
                    }                    
                } else if sensitivityCandiate > 1.0 {
                    withAnimation(.interactiveSpring) {
                        self.tempSensitivity = 1.0
                    }
                    
                }
            }
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(.mainAccent)
                .outerShadow(darkShadow: .darkShadow,
                             lightShadow: .lightShadow,
                             offset: 5,
                             radius: 5)
            
            ZStack {
                ForEach(self.radiusVolNotches, id: \.self) { theta in
                    HStack(spacing: 0) {
                        Capsule()
                            .fill(.gray.opacity(0.2))
                            .frame(minWidth: 1, maxWidth: 14, maxHeight: 2)
                            .offset(x : self.radiusOffsetVolNotches)
                        Spacer(minLength: 62)
                    }
                    .rotationEffect(theta)
                }
            }
            
            Circle()
                .fill(.clear)
                .innerShadow(Circle().inset(by: 10),
                             darkShadow: .darkShadow,
                             lightShadow: .lightShadow,
                             spread: 0.5,
                             radius:  10)
            HStack {
                Circle()
                    .fill(LinearGradient(colors: [.red, .orange],
                                         startPoint: .init(x: -0.6, y: 0.25),
                                         endPoint: .init(x: 1, y: 1)))
                    .frame(height: 5)
                    .innerShadow(Circle(),
                                 darkShadow: .darkShadow,
                                 lightShadow: .lightShadow,
                                 spread: 0.6,
                                 radius:  1)
                    .rotationEffect(-self.dialAngle)
                    .offset(x: 2.5)
                Spacer()
            }
            .rotationEffect(self.dialAngle)
             
        }
        .gesture(self.volumeGesture)
        .animation(.interactiveSpring, value: self.sensitivity)
        .onChange(of: self.dialAngle) { oldValue, newValue in
            let sensitivityCandiate = newValue.degrees / 180
            
            if sensitivityCandiate >= 1.0 {
                self.sensitivity = 1.0
            } else if sensitivityCandiate < 0.0 {
                self.sensitivity = 0.0
            } else {
                self.sensitivity = sensitivityCandiate
            }
        }
        .frame(maxWidth: 150)
    }
}

fileprivate struct TestView : View {
    
    @State var sensitivity : Double = 0.0
    
    var body: some View {
        MicrophoneDialView(sensitivity: self.$sensitivity)
    }
}


#Preview {
    ZStack {
        Color.mainAccent.ignoresSafeArea()
        VStack {
            MicrophoneIndicatorView(loudness: 0.5, energyLevel: 0.53, threshold: 0.3, isActive: true)
            //MicrophoneDialView(sensitivity: .constant(10)), isTranscribing: <#Bool#>
            TestView()
            
        }.frame(width: 100)
    }
}
