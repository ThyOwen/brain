//
//  Home.swift
//  Brain
//
//  Created by Owen O'Malley on 2/1/24.
//

import SwiftUI
/*
struct ChatView: View {
    
    //@StateObject var modelGenerate = ModelGenerate(modelUrl: URL(string: "/Users/duck/Downloads/ggml-model-q4_0.gguf")!)
    @StateObject var modelGenerate : ModelGenerate = .init()
    //@StateObject var whisperStream : WhisperStream = WhisperStream.init()
    
    @State var chat : Chat = Chat()
    @State private var messageText : String = ""
    @State private var processing : Bool = false
    
    // var webdata : [WebpageData] = search(searchQuery: "Walt Disney", numResults: 5)
    
    var body : some View {
        VStack {
            //Text(modelGenerate.messageLog)
            Button("test") {
                //whisperStream.onRealtime()
                //whisperStream.onTranscribePrepare()
              
            }
            //Text(whisperStream.text)

            ScrollView {
                LazyVStack {
                    ForEach(chat.messages, id: \.id) { message in
                        let target_message = chat.lastMessage(sender: .user)?.id == message.id

                        
                        messageView(message: message, target_message: target_message)

                    }
                }
            }
 
            
            HStack {
                TextField("write something down plz", text: $messageText)
                    
                
                Button("Send") {
                    if !processing { sendMessage(chat: chat, messageText: messageText) }
                    
                    withAnimation {
                        processing = true
                    }
                    
                    
                }
            }
        }
        .padding()
    }
    
    func messageView(message : ChatMessage, target_message : Bool) -> some View {
        HStack {
            message.sender == .user ? Spacer() : nil
            
            Text(message.content)
                .font(.body)
                .foregroundColor(.white)
                .padding(10)
                .background(message.sender == .user ? .blue : .gray.opacity(0.5))
                .cornerRadius(10)
                
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        AngularGradient(
                            colors: [.pink, .orange],
                            center: .center,
                            angle: .radians(chat.spin)),
                        lineWidth: target_message ? chat.border : 0.0)
                )


                .onAppear {
                    if target_message && processing {
                        withAnimation(
                            .linear(duration: 4)
                            .repeatForever(autoreverses: false)) {
                                chat.spin += 2 * .pi
                            }
                        }
                }
            message.sender == .bot ? Spacer() : nil
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5)) {
                chat.border = processing ? 2.0 : 0.0
            }
        }
    }
    
    func sendMessage(chat : Chat, messageText : String) {
        processing = true
        
        chat.addResponse(content: messageText, sender: .user)
        chat.addResponse(content: "", sender: .bot)
        
        
        Task {
            try await modelGenerate.completeChat(chat: chat)
            //await modelGenerate.complete(text: "the meaning of life is")
        }
        
        
        //
        self.messageText = ""
        
        }
    func searchGoogle(messageText : String) {
       
        
        
    }
}

#Preview {
    ChatView()
}
*/
