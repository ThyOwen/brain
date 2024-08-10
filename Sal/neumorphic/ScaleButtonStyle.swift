//
//  ScaleButtonStyle.swift
//  Brain
//
//  Created by Owen O'Malley on 5/8/24.
//

import SwiftUI

struct ScaleButtonStyle: ButtonStyle {
    @GestureState private var isTapped : Bool = false
    
    var tapGesture : some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .updating(self.$isTapped) { currentState, gestureState, transaction in
                gestureState = currentState
            }
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            //.scaleEffect(self.isTapped ? 0.95 : 1.0)
            //.gesture(self.tapGesture)
            //.animation(.linear(duration: 0.01), value: configuration.isPressed)
    }
}

extension Button {
    public func scaleButtonStyle() -> some View {
        self.buttonStyle(ScaleButtonStyle())
    }
}

fileprivate struct TestScaleButton: View {
    var body: some View {
        Button {
            print("pressed")
        } label: {
            Capsule()
        }
            .scaleButtonStyle()
    }
}

#Preview {
    TestScaleButton()
        .frame(width: 100, height: 200)
}
