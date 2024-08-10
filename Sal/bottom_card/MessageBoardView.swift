//
//  ChatRoledex.swift
//  Brain
//
//  Created by Owen O'Malley on 2/13/24.
//

import SwiftUI

extension View {
    func addGlowEffect(_ amount : CGFloat) -> some View {
        self
        .background {
            self.blur(radius: amount).brightness(0.1)
        }
    }
}

struct MessageBoardView: View {
    
    let fontSize : CGFloat

    @Environment(ChatViewModel.self) private var chatViewModel
    
    var body: some View {
        ZStack(alignment: .leading) {
            
            Text(String(repeating: "@", count: MessageBoardManager.characterLimit))
                .font(.custom("DigitalDreamSkew", size: self.fontSize))
                .foregroundColor(.init(white: 0.1, opacity: 0.5))
            
            ZStack(alignment: .leading) {
                Text(self.chatViewModel.messageBoard.boardText)
                    .font(.custom("DigitalDreamBoldSkew", size: self.fontSize))
                    .foregroundColor(.init(hue: 0.55, saturation: 0.8, brightness: 0.9))
                Text(self.chatViewModel.messageBoard.boardText)
                    .font(.custom("DigitalDreamSkew", size: self.fontSize))
                    .foregroundColor(.white)
            }
            .blur(radius: 0.25, opaque: false)
            
            .mask {
                Text(self.chatViewModel.messageBoard.boardText)
                    .font(.custom("DigitalDreamSkew", size: self.fontSize))
            }
            .addGlowEffect(0.2)
        }
        //.animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: self.textIdx)

    }
    
}

fileprivate struct TestView : View {
    
    @State var chatViewModel : ChatViewModel = .init()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            MessageBoardView(fontSize: 14)
                .frame(maxWidth: 300, minHeight: 30, maxHeight: 35)
        }
        .environment(self.chatViewModel)
    }
}

#Preview {
    TestView()
}
