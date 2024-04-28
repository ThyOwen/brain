//
//  OuterShadow.swift
//  Brain
//
//  Created by Owen O'Malley on 2/2/24.
//

import SwiftUI

private struct OuterShadowViewModifier: ViewModifier {
    var lightShadowColor : Color?
    var darkShadowColor : Color?
    var offset: CGFloat
    var radius : CGFloat
    
    init(darkShadowColor: Color?, lightShadowColor: Color?, offset: CGFloat, radius: CGFloat) {
        self.darkShadowColor = darkShadowColor
        self.lightShadowColor = lightShadowColor
        self.offset = offset
        self.radius = radius
    }

    func body(content: Content) -> some View {
        if let darkShadowColor = self.darkShadowColor {
            content.shadow(color: darkShadowColor, radius: radius, x: offset, y: offset)
        }
        
        if let lightShadowColor = self.lightShadowColor {
            content.shadow(color: lightShadowColor, radius: radius, x: -offset, y: -offset)
        }
        
    }

}

extension View {

    public func outerShadow(darkShadow: Color?,
                                lightShadow: Color?,
                                offset: CGFloat = 6,
                                radius:CGFloat = 3) -> some View {
        modifier(OuterShadowViewModifier(darkShadowColor: darkShadow, lightShadowColor: lightShadow, offset: offset, radius: radius))
    }
    
}


#Preview {
    ZStack {
        Color.mainAccent.ignoresSafeArea()
        Circle()
            .fill(.mainAccent)
            .outerShadow(darkShadow: .darkShadow,
                         lightShadow: .lightShadow,
                         offset: 20,
                         radius: 20)
            .frame(height: 100)

    }
}
