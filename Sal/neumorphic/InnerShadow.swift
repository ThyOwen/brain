//
//  InnerShadow.swift
//  Brain
//
//  Created by Owen O'Malley on 2/2/24.
//

import SwiftUI

private struct InnerShadowViewModifier<S: Shape> : ViewModifier {
    var shape: S
    var darkShadowColor : Color = .black
    var lightShadowColor : Color = .white
    var spread: CGFloat = 0.5
    var radius: CGFloat = 10
    
    init(shape: S, darkShadowColor: Color, lightShadowColor: Color, spread: CGFloat, radius:CGFloat) {
        self.shape = shape
        self.darkShadowColor = darkShadowColor
        self.lightShadowColor = lightShadowColor
        self.spread = spread
        self.radius = radius
        
        assert((0.0...1.0).contains(spread), "spread must be between 0 and 1")
    }

    fileprivate func strokeLineWidth(_ geo: GeometryProxy) -> CGFloat {
        return geo.size.width * 0.10
    }
    
    fileprivate func strokeLineScale(_ geo: GeometryProxy) -> CGFloat {
        let lineWidth = strokeLineWidth(geo)
        return geo.size.width / CGFloat(geo.size.width - lineWidth)
    }
    
    fileprivate func shadowOffset(_ geo: GeometryProxy) -> CGFloat {
        return (geo.size.width <= geo.size.height ? geo.size.width : geo.size.height) * 0.5 * min(max(spread, 0), 1)
    }
    

    fileprivate func addInnerShadow(_ content: InnerShadowViewModifier.Content) -> some View {
        return GeometryReader { geo in
            
            self.shape.fill(self.lightShadowColor)
                .inverseMask(
                    self.shape
                    .offset(x: -self.shadowOffset(geo), y: -self.shadowOffset(geo))
                )
                .offset(x: self.shadowOffset(geo) , y: self.shadowOffset(geo))
                .blur(radius: self.radius)
                .shadow(color: self.lightShadowColor, radius: self.radius, x: -self.shadowOffset(geo)/2, y: -self.shadowOffset(geo)/2 )
                .mask(
                    self.shape
                )
                .overlay(
                    self.shape
                        .fill(self.darkShadowColor)
                        .inverseMask(
                            self.shape
                            .offset(x: self.shadowOffset(geo), y: self.shadowOffset(geo))
                        )
                        .offset(x: -self.shadowOffset(geo) , y: -self.shadowOffset(geo))
                        .blur(radius: self.radius)
                        .shadow(color: self.darkShadowColor, radius: self.radius, x: self.shadowOffset(geo)/2, y: self.shadowOffset(geo)/2 )
                )
                .mask(
                    self.shape
                )
        }
    }

    func body(content: Content) -> some View {
        content.overlay(
            addInnerShadow(content)
        )
    }
}

extension View {
    public func innerShadow<S : Shape>(_ content: S,
                                           darkShadow: Color,
                                           lightShadow: Color,
                                           spread: CGFloat = 0.5,
                                           radius: CGFloat = 10) -> some View {
        modifier(
            InnerShadowViewModifier(shape: content, darkShadowColor: darkShadow, lightShadowColor: lightShadow, spread: spread, radius: radius)
        )
    }
}

#Preview {
    ZStack {
        Color.mainAccent.ignoresSafeArea()
        Circle()
            .fill(.mainAccent)
            .innerShadow(Circle(),
                         darkShadow: .darkShadow,
                         lightShadow: .lightShadow,
                         spread: 0.5,
                         radius:  10)
            .frame(width: 100, height: 100)

    }
}
