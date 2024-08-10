//
//  ControlPanelView.swift
//  Sal
//
//  Created by Owen O'Malley on 7/10/24.
//

import SwiftUI

struct ControlPanel<Content : View>: View {
    
    @ViewBuilder public let controlsView : Content
    
    public let cornerRadius : CGFloat = 60
    
    var body: some View {
        ZStack(alignment: .center) {
            /*
            RoundedRectangle(cornerRadius: self.cornerRadius, style: .continuous)
                .strokeBorder(LinearGradient(colors: [.darkShadow, .lightShadow],
                                             startPoint: .topLeading,
                                             endPoint: .bottomTrailing), lineWidth: 1)
            
            RoundedRectangle(cornerRadius: self.cornerRadius)
                .inset(by: 3.5)
                .fill(.black)
            
            */

            RoundedRectangle(cornerRadius: self.cornerRadius)
                .fill(.black)
            
            RoundedRectangle(cornerRadius: self.cornerRadius)
                .inset(by: 1.0)
                .fill(.mainAccent)
                .strokeBorder(LinearGradient(colors: [.edgeLightShadow, .edgeDarkShadow],
                                             startPoint: .topLeading,
                                             endPoint: .bottomTrailing), lineWidth: 1)
                
                .innerShadow(RoundedRectangle(cornerRadius: self.cornerRadius).inset(by: 10),
                             darkShadow: .darkShadow,
                             lightShadow: .lightShadow,
                             spread: 0.1,
                             radius: 20)
            
            self.controlsView
        }
    }
}

#Preview {
    ZStack {
        Color.mainAccent.ignoresSafeArea()
        ControlPanel {
            Circle()
                .padding()
        }
        .frame(width: 300, height: 200)
    }

}
