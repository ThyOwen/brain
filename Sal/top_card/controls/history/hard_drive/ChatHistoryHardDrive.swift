//
//  ChatHistorySelector.swift
//  Sal
//
//  Created by Owen O'Malley on 7/4/24.
//

import SwiftUI
import SwiftData

public struct ChatHistoryHardDriveGestureState {
    public var isActive : Bool = false
    public var currentAngle : Angle = .zero
    public var previousAngle : Angle = .zero
}

public enum ChatHistoryDialGestureState {
    case inactive
    case active(angle : Angle)
    
    public var angle : Angle {
        switch self {
        case .active(let angle):
             return angle
        case .inactive:
            return .zero
        }
    }
    
    public var isActive: Bool {
        switch self {
        case .inactive:
            return false
        case .active:
            return true
        }
    }
    
}

struct ChatHistoryHardDrive: View {
    
    @Binding public var tvViewState : TVViewState
    
    @Environment(ChatViewModel.self) private var chatViewModel
    
    @State private var placeHolderRotation : Angle = .zero
    @GestureState public var gestureState : ChatHistoryDialGestureState = .inactive

    private let angleDeltaBeforeUpTick : Angle = .degrees(10)
    private let deltaBufferLimit : Int = 16
    @State private var deltaBuffer : [Double] = []
    @State private var deltaCounter : Int = 0
    
    private var platterAngle : Angle {
        self.gestureState.isActive ? self.gestureState.angle : self.placeHolderRotation
    }
    
    private var actuatorAngle : Angle {
        Angle(degrees: self.platterAngle.degrees * self.actuatorAngleLimit) - .degrees(360 * self.actuatorAngleLimit)
    }
    
    private let actuatorAngleLimit : Double = 0.08

    private let radiusOffsetVolNotches : CGFloat = 60
    private static let numVolumeNotches : Int = 8
    private let angleVolNotches : [Angle] = (0..<ChatHistoryHardDrive.numVolumeNotches).map { idx in
        Angle.degrees((Double(idx) / Double(ChatHistoryHardDrive.numVolumeNotches)) * 360)
    }

    var platter : some View {
        GeometryReader { proxy in
            ZStack {
                
                Circle()
                    .inset(by: 13)
                    .fill(LinearGradient(colors: [ .white.opacity(0.8), .gray],
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing))

                ForEach(0..<12) { idx in
                    Circle()
                        .inset(by: CGFloat(idx * 3) + 15)
                        .strokeBorder(Color.init(white: 0.2), lineWidth: 1, antialiased: true)
                }
                
                ForEach(self.angleVolNotches, id: \.self) { theta in
                    HStack(spacing: 0) {
                        Capsule()
                            .fill(Color.init(white: 0.3).opacity(0.1))
                            .frame(minWidth: 1, maxWidth: 14, maxHeight: 2)
                            .offset(x : self.radiusOffsetVolNotches)
                        Spacer(minLength: 0)
                    }
                    .rotationEffect(theta + self.platterAngle)
                }

                
            }
            .gesture(self.getGesture(inside: proxy.size))
            //self.deltaBuffer.reserveCapacity(self.deltaBufferLimit + 1)

            .onChange(of: self.gestureState.angle) { oldValue, newValue in
                
                guard self.gestureState.isActive else {
                    return
                }
                
                let delta : Double = switch (newValue.degrees, oldValue.degrees) {
                case (0...30, 330...360):
                    (newValue.degrees + 360) - oldValue.degrees
                case (330...360, 0...30):
                    newValue.degrees - (oldValue.degrees + 360)
                default:
                    newValue.degrees - oldValue.degrees
                }
                
                self.deltaBuffer.append(delta)
                
                if self.deltaBuffer.count > self.deltaBufferLimit {
                    self.deltaBuffer.removeFirst()
                }
                
                self.deltaCounter += 1

                guard deltaCounter % 5 == 0 else {
                    return 
                }
                
                let numOfDeltasMeetsTheshold = self.deltaBuffer.filter { idx in
                    idx > self.angleDeltaBeforeUpTick.degrees || idx < -self.angleDeltaBeforeUpTick.degrees
                }
                
                guard numOfDeltasMeetsTheshold.count >= 3 else {
                    return
                }
                
                //take the delta and use it to update the TV's state
                switch (delta, self.tvViewState.displayType) {
                case (_, .chatHistory) where delta <= -self.angleDeltaBeforeUpTick.degrees:
                    let isChatsEmpty = self.chatViewModel.chat.chatHistory.isEmpty || self.chatViewModel.chat.chatHistory.count == 1
                    
                    if !isChatsEmpty, (1...self.chatViewModel.chat.chatHistory.count - 1).contains(self.tvViewState.selectedChatHistoryIndex) {
                        withAnimation {
                            self.tvViewState.selectedChatHistoryIndex -= 1
                        }
                    }
                        
                case (_, .chatHistory) where delta >= self.angleDeltaBeforeUpTick.degrees:
                    let isChatsEmpty = self.chatViewModel.chat.chatHistory.isEmpty || self.chatViewModel.chat.chatHistory.count == 1
                    
                    if !isChatsEmpty, (0...self.chatViewModel.chat.chatHistory.count - 2).contains(self.tvViewState.selectedChatHistoryIndex) {
                        withAnimation {
                            self.tvViewState.selectedChatHistoryIndex += 1
                        }
                    }
                        
                case (_, .historicChatMessages) where delta <= -self.angleDeltaBeforeUpTick.degrees:
                    let chatMessageCount = self.chatViewModel.chat.chatHistory[self.tvViewState.selectedChatHistoryIndex].messages.count
                    let areMessagesEmpty = self.chatViewModel.chat.chatHistory[self.tvViewState.selectedChatHistoryIndex].messages.isEmpty || chatMessageCount == 1
                    
                    if !areMessagesEmpty, (1...chatMessageCount - 1).contains(self.tvViewState.selectedChatMessageIndex) {
                        withAnimation {
                            self.tvViewState.selectedChatMessageIndex -= 1
                        }
                    }
                    
                case (_, .historicChatMessages) where delta >= self.angleDeltaBeforeUpTick.degrees:
                    let chatMessageCount = self.chatViewModel.chat.chatHistory[self.tvViewState.selectedChatHistoryIndex].messages.count
                    let areMessagesEmpty = self.chatViewModel.chat.chatHistory[self.tvViewState.selectedChatHistoryIndex].messages.isEmpty || chatMessageCount == 1
                    
                    if !areMessagesEmpty, (0...chatMessageCount - 2).contains(self.tvViewState.selectedChatMessageIndex) {
                        withAnimation {
                            self.tvViewState.selectedChatMessageIndex += 1
                        }
                    }
                    
                default:
                    break
                }
                
            }
        }
    }
    
    var actuator : some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(Color.init(white: 0.2))
                .frame(width: 20)
                .offset(y: 10)
                .outerShadow(darkShadow: .darkShadow,
                             lightShadow: .lightShadow,
                             offset: 3,
                             radius: 3)
            
            Circle()
                .stroke(style: .init(lineWidth: 0.5, lineJoin: .round))
                .fill(Color.init(white: 0.4))
                .frame(width: 10)
                .offset(x: -5, y: 5)
            
            
            HardDriveActuator(tipOffset: .init(x: 0.3, y: 0.7))
                .stroke(style: .init(lineWidth: 3, lineJoin: .round))
                .fill(Color.init(white: 0.1))
                .frame(width: 20, height: 70)
                .rotationEffect(self.actuatorAngle, anchor: .bottom)
            
                .outerShadow(darkShadow: .darkShadow,
                             lightShadow: nil,
                             offset: 2,
                             radius: 2)

        }
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            
            Circle()
                .fill(.mainAccent)
                .outerShadow(darkShadow: .darkShadow,
                             lightShadow: .lightShadow,
                             offset: 7,
                             radius: 15)
            Circle()
                .inset(by: 10)
                .fill(.black)
            
            self.platter
            self.actuator
                .offset(x: -10, y: -10)
            //Slider(value: self.$platterAngle.degrees, in: 0...360)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(minWidth: 175, maxWidth: 200)
    }
    
    private func getGesture(inside size : consuming CGSize) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .updating(self.$gestureState) { currentState, gestureState, transaction in
                
                let angle = Self.calculateAngle(from: currentState, inside: size)
                gestureState = .active(angle: angle)
            }
            .onEnded { currentState in
                let angle = Self.calculateAngle(from: currentState, inside: size)
                
                self.placeHolderRotation = consume angle
                self.deltaBuffer = []
                self.deltaCounter = 0
            }
    }
    
    private static func calculateAngle(from gestureValue : consuming DragGesture.Value, inside circularFrame : borrowing CGSize) -> Angle {
        let deltaY = gestureValue.location.y - (circularFrame.height / 2)
        let deltaX = gestureValue.location.x - (circularFrame.width / 2)
        let angle = Angle(radians: Double(atan2(deltaY, deltaX)) + (.pi))
        return angle
    }

}



fileprivate struct TestView: View {
    
    @State private var tvViewState : TVViewState = .init()
    
    @State private var chatViewModel : ChatViewModel = .init()
    var body: some View {
        ZStack {
            Color.mainAccent.ignoresSafeArea()
            ChatHistoryHardDrive(tvViewState: self.$tvViewState)
                .environment(self.chatViewModel)
                .frame(width: 300)
        }
    }
}

#Preview {
    TestView()
}
