//
//  WaveView.swift
//  Brain
//
//  Created by Owen O'Malley on 2/1/24.
//

import SwiftUI

struct TVView: View {
    
    let isOpen : Bool
    let rimColor : Color = .mainAccent
    
    let cornerRadius : CGFloat = 100

    @Environment(ChatViewModel.self) private var chatViewModel
    
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
            
            TV(insetAmount: 11)
                .colorEffect(ShaderLibrary.coloredNoise())
            /*
            VStack(spacing: 0) {
                Spacer()
                
                ChatRoledex(fontSize: self.isOpen ? 14 : 12)
                    .frame(maxWidth: .infinity, minHeight: 35, maxHeight: 50)
                    .offset(y: -15)
                    .background {
                        
                        LinearGradient(colors: [.black, .clear],
                                       startPoint: .bottom,
                                       endPoint: .top)
                        
                        //Color.black
                        .offset(y: -10)
                    }
                    
                    
                    
            }
            .mask {
                TV(insetAmount: 11)
            }
            */
        }
    }
}

fileprivate struct TestView : View {
    
    @State private var chatViewModel : ChatViewModel = .init(messageText: "Ohio will invade the world")
    @State private var isPanel : Bool = true
    
    var body: some View {
        VStack {
            Button("Toggle") {
                withAnimation {
                    self.isPanel.toggle()
                }
            }
            ZStack {
                Color.mainAccent.ignoresSafeArea()
                TVView(isOpen: self.isPanel)
                    .aspectRatio(1.2, contentMode: .fit)
                    .scenePadding()
            }
            .environment(self.chatViewModel)
        }
    }
}
 
#Preview {
    TestView()
}
