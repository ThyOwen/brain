//
//  MicrophoneDialView.swift
//  Brain
//
//  Created by Owen O'Malley on 4/16/24.
//

import SwiftUI
/*
public struct Arc: InsettableShape {
    
    var startDegrees : Double
    var endDegrees : Double
    
    var startAngle: Angle { Angle.degrees(90 + self.startDegrees) }
    var endAngle: Angle { Angle.degrees(90 + self.endDegrees) }
    
    var clockwise: Bool
    
    var insetAmount = 0.0
    
    public var animatableData: AnimatablePair<Double, Double> {
        get {
            AnimatablePair(self.startDegrees, self.endDegrees)
        }

        set {
            self.startDegrees = newValue.first
            self.endDegrees = newValue.second
        }
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: (rect.width / 2) - self.insetAmount, startAngle: startAngle, endAngle: endAngle, clockwise: clockwise)

        return path
    }
    
    public func inset(by amount: CGFloat) -> some InsettableShape {
        var tv = self
        tv.insetAmount += amount
        return tv
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
    
    @Binding var whisper : Whisper
    
    private let radiusOffsetVolNotches : CGFloat = 15
    private let angleVolNotches : [Angle]
    private let numVolNotches : Int
    private let completionAngleWindow : Angle
    private let completionAnglesBound : Double
    
    @State private var tempSensitivity : Double
    @GestureState var gestureState : MicrophoneDialGestureState = .inactive
    @State private var messageTimeOut : Double
    
    private var dialAngle : Angle {
        self.gestureState.isActive ? Angle(degrees: self.tempSensitivity * 180) + self.gestureState.angle : Angle(degrees: self.tempSensitivity * 180)
    }
    
    private var completionAngle : Double {
        self.messageTimeOut * (self.completionAngleWindow.degrees / 2)
    }
    
    private var bufferMeetsSilenceThreshold : Bool {
        self.whisper.lastBufferEnergy > Float(self.whisper.appSettings.silenceThreshold)
    }

    init(whisper : Binding<Whisper>, completionAngleWindow : Angle = .degrees(270), numVolNotches : Int = 8) {
        
        self._whisper = whisper
        self.tempSensitivity = whisper.appSettings.silenceThreshold.wrappedValue
        
        self.numVolNotches = numVolNotches
        self.angleVolNotches = (0...numVolNotches).map { idx in
                .degrees((Double(idx) / Double(numVolNotches)) * 180)
        }
        
        self.completionAngleWindow = completionAngleWindow
        
        self.completionAnglesBound = completionAngleWindow.degrees / 2
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
                    withAnimation(.easeOut(duration: 0.15)) {
                        self.tempSensitivity = 0.0
                    }
                } else if sensitivityCandiate > 1.0 {
                    withAnimation(.easeOut(duration: 0.15)) {
                        self.tempSensitivity = 1.0
                    }
                }
            }
    }
    
    var completionIndicator : some View {
        ZStack {
            Arc(startDegrees: self.completionAnglesBound,
                endDegrees: -self.completionAnglesBound,
                clockwise: true)
                .inset(by: -12)
                .stroke(.mainAccent, style: StrokeStyle(lineWidth: 2.0, lineCap: .round))
                .outerShadow(darkShadow: .darkShadow,
                             lightShadow: .lightShadow, offset: 0.5, radius: 0.5)
            
            Arc(startDegrees: self.completionAngle,
                endDegrees: -self.completionAngle,
                clockwise: true)
                .inset(by: -12)
                .stroke(LinearGradient(colors: [.orange.opacity(0.6), .red.opacity(0.6)],
                                       startPoint: .init(x: 0.5, y: 0),
                                       endPoint: .init(x: 0.5, y: CGFloat(self.messageTimeOut))),
                        style: StrokeStyle(lineWidth: 2.0, lineCap: .round))

        }
        .onChange(of: self.bufferMeetsSilenceThreshold) { oldValue, newValue in

        }
        .onChange(of: self.whisper.countdownValue) { oldValue, newValue in
            withAnimation(.easeInOut(duration: 5.0)) {
                self.messageTimeOut = Double(self.whisper.countdownValue) / Double(self.whisper.countdownValueLimit)
            }
        }
        .animation(.easeInOut, value: self.messageTimeOut)

    }
    
    var body: some View {
        ZStack {
            
            //self.completionIndicator
            
            Circle()
                .fill(.mainAccent)
                .outerShadow(darkShadow: .darkShadow,
                             lightShadow: .lightShadow,
                             offset: 5,
                             radius: 5)
            
            ZStack {
                ForEach(self.angleVolNotches, id: \.self) { theta in
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
        .fixedSize(horizontal: false, vertical: true)
        .gesture(self.volumeGesture)
        .animation(.interactiveSpring, value: self.whisper.appSettings.silenceThreshold)
        .onChange(of: self.dialAngle) { oldValue, newValue in
            let sensitivityCandiate = newValue.degrees / 180
            
            if sensitivityCandiate >= 1.0 {
                self.whisper.appSettings.silenceThreshold = 1.0
            } else if sensitivityCandiate < 0.0 {
                self.whisper.appSettings.silenceThreshold = 0.0
            } else {
                self.whisper.appSettings.silenceThreshold = sensitivityCandiate
            }
        }
        .frame(maxWidth: 150)
    }
}

fileprivate struct TestView : View {
    
    @State var whisper : Whisper = Whisper()
    
    var body: some View {
        VStack {
            MicrophoneDialView(whisper: self.$whisper)
        }
    }
}

#Preview {
    ZStack {
        Color.mainAccent.ignoresSafeArea()
        VStack {
            TestView()
            
        }.frame(width: 100)
    }
}
*/
