//
//  Button.swift
//  Brain
//
//  Created by Owen O'Malley on 2/3/24.
//

import SwiftUI

public enum SoftButtonPressedEffect {
    case none
    case flat
    case hard
    case inset
}

public struct SoftDynamicButtonStyle<S: Shape> : ButtonStyle {

    var shape: S
    var mainColor : Color
    var darkShadowColor : Color
    var lightShadowColor : Color
    var pressedEffect : SoftButtonPressedEffect
    
    public init(_ shape: S, mainColor : Color, darkShadowColor: Color, lightShadowColor: Color, pressedEffect : SoftButtonPressedEffect) {
        self.shape = shape
        self.mainColor = mainColor
        self.darkShadowColor = darkShadowColor
        self.lightShadowColor = lightShadowColor
        self.pressedEffect = pressedEffect
    }
    
    public func makeBody(configuration: Self.Configuration) -> some View {
        SoftDynamicButton(configuration: configuration, 
                          shape: shape,
                          mainColor: mainColor,
                          darkShadowColor: darkShadowColor,
                          lightShadowColor: lightShadowColor,
                          pressedEffect: pressedEffect)
    }

    struct SoftDynamicButton: View {
        let configuration: ButtonStyle.Configuration
        
        var shape: S
        var mainColor : Color
        var darkShadowColor : Color
        var lightShadowColor : Color
        var pressedEffect : SoftButtonPressedEffect
        
        @Environment(\.isEnabled) private var isEnabled: Bool
        
        var body: some View {
            configuration.label
                
                //.scaleEffect(configuration.isPressed ? 0.95 : 1)
                .background {
                    ZStack {
                        if isEnabled {
                            if case .flat = pressedEffect {
                                shape.stroke(darkShadowColor, lineWidth : configuration.isPressed ? 1 : 0)
                                    .opacity(configuration.isPressed ? 1 : 0)
                                shape.fill(mainColor)
                            }
                            else if case .hard = pressedEffect  {
                                shape.fill(mainColor)
                                    .innerShadow(shape, darkShadow: darkShadowColor, lightShadow: lightShadowColor, spread: 0.15, radius: 3)
                                    .opacity(configuration.isPressed ? 1 : 0)
                            }
                            else if case .inset = pressedEffect {
                                shape.stroke(darkShadowColor, lineWidth : configuration.isPressed ? 0 : 0)
                                    .opacity(configuration.isPressed ? 1 : 0)
                                shape.fill(mainColor)
                            
                                .outerShadow(darkShadow: darkShadowColor,
                                             lightShadow: lightShadowColor,
                                             offset: 5,
                                             radius: 5)
                                .innerShadow(shape,
                                             darkShadow: darkShadowColor,
                                             lightShadow: lightShadowColor,
                                             spread: 0.5,
                                             radius: 3)
                                .opacity(configuration.isPressed ? 1 : 0)
                            }
                            shape.fill(mainColor)
                                .outerShadow(darkShadow: darkShadowColor, 
                                             lightShadow: lightShadowColor, 
                                             offset: 5,
                                             radius: 5)
                            
                                .compositingGroup()
                                .opacity(pressedEffect == .none ? 1 : (configuration.isPressed ? 0 : 1) )
                        } else {
                            //if isEnabled { shape.stroke(darkShadowColor, lineWidth : 1).opacity(1) }
                            shape.fill(mainColor)
                            //.scaleEffect(configuration.isPressed ? 0.95 : 1)

                        }
                    }
                }

                
        }
    }
    
}


extension Button {
    public func softButtonStyle<S : Shape>(_ content: S,
                                           mainColor : Color,
                                           darkShadowColor: Color,
                                           lightShadowColor: Color,
                                           pressedEffect : SoftButtonPressedEffect = .hard) -> some View {
        self.buttonStyle(SoftDynamicButtonStyle(content,
                                                mainColor: mainColor,
                                                darkShadowColor: darkShadowColor,
                                                lightShadowColor: lightShadowColor,
                                                pressedEffect : pressedEffect ))
    }
}

#Preview {
    ZStack {
        Color.mainAccent.ignoresSafeArea()
        HStack {
            Spacer()
            Button(action: {
                
            }, label: {
                Text("asdfasfd")
                    .bold()
                    .frame(width: 100, height: 100)
                //RoundedRectangle(cornerRadius: 10)
            })
            .softButtonStyle(RoundedRectangle(cornerRadius: 10),
                             mainColor: .mainAccent,
                             darkShadowColor: .darkShadow,
                             lightShadowColor: .lightShadow,
                             pressedEffect: .inset)
            Spacer()
            Button(action: {
                
            }, label: {
                Text("asdfasfd")
                    .bold()
                    .frame(width: 100, height: 100)
                //RoundedRectangle(cornerRadius: 10)
            })
            .softButtonStyle(Circle(),
                             mainColor: .mainAccent,
                             darkShadowColor: .darkShadow,
                             lightShadowColor: .lightShadow,
                             pressedEffect: .flat)
            Spacer()
        }
    }
}
