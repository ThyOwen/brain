//
//  MicrophoneButtonView.swift
//  Brain
//
//  Created by Owen O'Malley on 4/21/24.
//

import SwiftUI
import WhisperKit

struct MicrophonePressAndHoldButtonView: View {
    
    @Environment(ChatViewModel.self) private var chatViewModel

    static let colors : [Color] = [.orange, .red]
    
    private var modelLoaded : Bool {
        !(self.chatViewModel.whisper.modelState == .unloaded || self.chatViewModel.whisper.modelState == .loaded)
    }
    
    var button: some View {
        ZStack {
            Capsule()
                .inset(by: 5)
                .fill(
                    LinearGradient(colors: Self.colors,
                                   startPoint: .init(x: 0, y: 0),
                                   endPoint: .init(x: 1, y: 1))
                )
            
            Capsule()
                .inset(by: 20)
                .fill(
                    LinearGradient(colors: Self.colors.reversed(),
                                   startPoint: .init(x: 0, y: 0),
                                   endPoint: .init(x: 1, y: 1))
                )
            
            Image(systemName: "mic.fill")
                .foregroundStyle(Color.init(white: 0.4).opacity(0.5))
                    .foregroundStyle(.darkShadow)
                    .imageScale(.large)
            
        }
    }
    
    var body: some View {
        ZStack {
            Capsule()
                .strokeBorder(LinearGradient(colors: [.darkShadow, .lightShadow],
                                             startPoint: .topLeading,
                                             endPoint: .bottomTrailing), lineWidth: 5)
            Capsule()
                .inset(by: 3)
                .fill(.black)
            
            Button {
                self.chatViewModel.startSingleResponse()
            } label: {
                self.button
            }
            .scaleButtonStyle()
        }
    }
    
}

struct MicrophoneToggleButtonView: View {
    
    @Environment(ChatViewModel.self) private var chatViewModel
    
    static let colors : [Color] = [.cyan, .blue]
    
    var button: some View {
        ZStack {
            Circle()
                .inset(by: 5)
                .fill(
                    LinearGradient(colors: Self.colors,
                                   startPoint: .init(x: 0, y: 0),
                                   endPoint: .init(x: 1, y: 1))
                )
            
            Circle()
                .inset(by: 12)
                .fill(
                    LinearGradient(colors: Self.colors.reversed(),
                                   startPoint: .init(x: 0, y: 0),
                                   endPoint: .init(x: 1.0, y: 1.0))
                )
            
            Image(systemName: "recordingtape.circle.fill")
                .foregroundStyle(Color.init(white: 0.4).opacity(0.5))
                    .foregroundStyle(.darkShadow)
                    .imageScale(.large)
             
        }
    }
    
    var body: some View {
        ZStack {
            
            Circle()
                .strokeBorder(LinearGradient(colors: [.darkShadow, .lightShadow],
                                             startPoint: .topLeading,
                                             endPoint: .bottomTrailing), lineWidth: 5)
            Circle()
                .inset(by: 3)
                .fill(.black)
            
            Button {
                self.chatViewModel.startSingleResponse()
                
            } label: {
                self.button
            }
            .scaleButtonStyle()
        }
        
    }
}

fileprivate struct TestView : View {

    @State private var chatViewModel : ChatViewModel = .init()
    
    var body: some View {
        ZStack {
            Color.mainAccent.ignoresSafeArea()
            MicrophonePressAndHoldButtonView()
                .frame(width: 150, height: 200)
            MicrophoneToggleButtonView()
                .frame(width: 70, height: 70)
                .offset(x: 100, y: -100)
        }
        .environment(self.chatViewModel)
    }
}

#Preview {
    TestView()
}
