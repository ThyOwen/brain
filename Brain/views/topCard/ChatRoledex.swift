//
//  ChatRoledex.swift
//  Brain
//
//  Created by Owen O'Malley on 2/13/24.
//

import SwiftUI

struct ChatRoledex: View {
    
    @Binding var chat : Chat
    @Binding var processing : Bool
    
    @State var messageText : String = ""
    @State var isOpen : Bool = false
    
    private var size : CGFloat { isOpen ? 500.0 : 60.0 }
    
    var body: some View {
        VStack {
                        
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(chat.messages, id: \.id) { message in
                        messageView(message: message)
                        
                            .containerRelativeFrame(.vertical,
                                                    count: isOpen ? 10 : 2,
                                                    spacing: 00)
                            
                            .scrollTransition { content, phase in
                                content
                                    .rotation3DEffect(Angle(degrees: phase.isIdentity ? phase.value * 90 : -phase.value * 90),
                                                      axis: (x: 1.0, y: 0.0, z: 0.0),
                                                      anchor: phase.value <= 0 ? .bottom : .top,
                                                      anchorZ: 0
                                                      
                                    )
                            }
                            
                    }
                }.scrollTargetLayout()
                    
            }
            
            .contentMargins(10, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            
            //.scrollBounceBehavior(.basedOnSize)
            
            /*
            HStack {
                TextField("write something down plz", text: $messageText)
            }*/
            
        }
        .frame(height: size)
        .animation(.easeInOut, value: size)
        
        .background {
            RoundedRectangle(cornerRadius: 30).fill(.mainAccent)
            .innerShadow(RoundedRectangle(cornerRadius: 30),
                         darkShadow: .darkShadow,
                         lightShadow: .lightShadow,
                         spread: 0.1,
                         radius: 10)
            }
        .onTapGesture {
            withAnimation {
                isOpen.toggle()
            }
        }
    }
    
    func messageView(message : ChatMessage) -> some View {
        HStack {
            //message.sender == .user ? Spacer() : nil
            
            Text(message.content)
                .lineLimit(...1)
                .font(.body)
                .foregroundColor(isOpen ? .white : (message.sender == .user ? .gray: .black))
                .padding(isOpen ? 7 : 0)
                .background(isOpen ? (message.sender == .user ? .darkShadow.opacity(0.8) : .darkShadow.opacity(0.4)) : .clear)
                .cornerRadius(10)
                //.padding(.init(top: 0, leading: 20, bottom: 0, trailing: 20))
                
            //message.sender == .bot ? Spacer() : nil
        }
    }
}

#Preview {
    ZStack {
        Color.mainAccent.ignoresSafeArea()
        ChatRoledex(chat: .constant(Chat(messages: ChatMessage.viewMessages)),
                    processing: .constant(false))
    }
    
}
