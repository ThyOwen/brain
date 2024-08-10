//
//  WaveView.swift
//  Brain
//
//  Created by Owen O'Malley on 2/1/24.
//

import SwiftUI



struct TVView<Content : View> : View {

    @ViewBuilder let someView : Content
    
    var body: some View {
        ZStack {
            TV()
                .fill(.mainAccent)
                .outerShadow(darkShadow: .darkShadow,
                             lightShadow: .lightShadow,
                             offset: 10,
                             radius: 10)
            
            TV(insetAmount: -0.5)
                .strokeBorder(LinearGradient(colors: [.edgeLightShadow, .edgeDarkShadow],
                                     startPoint: .topLeading,
                                     endPoint: .bottomTrailing), lineWidth: 1)
            TV(insetAmount: 10)
                .fill(.black)
            
            ZStack {
                Color.black
                self.someView
                    .transition(.opacity)
                    .padding(.all, 11)
            }
                .colorEffect(ShaderLibrary.coloredNoise(.float(0.4)))
                .mask {
                    TV(insetAmount: 11)
                }
        }
        .innerShadow(TV(insetAmount: 11),
                     darkShadow: .tvLightHaze,
                     lightShadow: .black.opacity(0.7),
                     spread: 0.3,
                     radius: 20)
    }
}

fileprivate struct TestView : View {
    
    //@State private var chatViewModel : ChatViewModel = .init()
    
    var body: some View {
        ZStack {
            Color.mainAccent.ignoresSafeArea()
            TVView {
                Circle()
            }
                .aspectRatio(1.2, contentMode: .fit)
                .scenePadding()
        }
        //.environment(self.chatViewModel)
    }
}
 
#Preview {
    TestView()
}
