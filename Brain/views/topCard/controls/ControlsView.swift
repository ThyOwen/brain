//
//  ControlsView.swift
//  Brain
//
//  Created by Owen O'Malley on 5/6/24.
//

import SwiftUI

extension InsettableShape {
    func chamferedEdgeFill(fill : Color, insetAmount : CGFloat) -> some View {
        
        self
            .fill(fill)
    }
}

struct ControlsView: View {
    
    let smallerCornerRadius : CGFloat = 5
    let paddingAmount : CGFloat = 4.5
    
    var isOpen : Bool
    
    @Environment(ChatViewModel.self) private var chatViewModel
    @Environment(Whisper.self) private var whisper
    
    private var cornerRadius : CGFloat { self.isOpen ? 32 : 18 }
    
    var iconCircle : some View {
        Circle()
            .inset(by: 9)
            .fill(.secondAccent)
            .outerShadow(darkShadow: .darkShadow,
                         lightShadow: .lightShadow, 
                         offset: isOpen ? 3 : 0,
                         radius: isOpen ? 6 : 0)
    }
    
    var button0 : some View {
        Button {
            withAnimation {
                self.chatViewModel.showWave.toggle()
            }
        } label: {
            ZStack {
                UnevenRoundedRectangle(cornerRadii: .init(topLeading: (self.cornerRadius-self.paddingAmount),
                                                          bottomLeading: self.smallerCornerRadius,
                                                          bottomTrailing: self.smallerCornerRadius,
                                                          topTrailing: self.smallerCornerRadius),
                                       style: .continuous)
                .fill(.secondAccent)
                .strokeBorder(LinearGradient(colors: [.edgeLightShadow, .edgeDarkShadow],
                                             startPoint: .topLeading,
                                             endPoint: .bottomTrailing), lineWidth: 1)
                self.iconCircle
                
                let icon = self.chatViewModel.showWave ? "bubble.left.and.bubble.right.fill" : "waveform.path.ecg.rectangle.fill"
                
                Image(systemName: icon)
                    .foregroundStyle(.lightShadow)
                    .imageScale(self.isOpen ? .medium : .small)
                    .symbolEffect(.bounce, value: self.chatViewModel.showWave)
                    //.contentTransition()
                    
            }
        }
        .scaleButtonStyle()
    }
    
    var button1 : some View {
        Button {

        } label: {
            ZStack {
                UnevenRoundedRectangle(cornerRadii: .init(topLeading: self.smallerCornerRadius,
                                                          bottomLeading: self.smallerCornerRadius,
                                                          bottomTrailing: self.smallerCornerRadius,
                                                          topTrailing: (self.cornerRadius-self.paddingAmount)),
                                       style: .continuous)
                .fill(.secondAccent)
                .strokeBorder(LinearGradient(colors: [.edgeLightShadow, .edgeDarkShadow],
                                             startPoint: .topLeading,
                                             endPoint: .bottomTrailing), lineWidth: 1)
                self.iconCircle
                
                Image(systemName: "recordingtape.circle.fill")
                    .foregroundStyle(.darkShadow)
                    .imageScale(self.isOpen ? .medium : .small)
                
            }
        }
        .scaleButtonStyle()
    }
    
    var button2 : some View {
        Button {
            if self.whisper.appSettings.silenceThreshold < 1.0 {
                self.whisper.appSettings.silenceThreshold += 0.1
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: self.smallerCornerRadius, style: .continuous)
                    .fill(.secondAccent)
                    .strokeBorder(LinearGradient(colors: [.edgeLightShadow, .edgeDarkShadow],
                                                 startPoint: .topLeading,
                                                 endPoint: .bottomTrailing), lineWidth: 1)
                self.iconCircle
                Image(systemName: "plus")
                    .foregroundStyle(.black)
                    .imageScale(self.isOpen ? .medium : .small)
            }
        }
        .scaleButtonStyle()
    }
    
    var button3 : some View {
        Button {
            
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: self.smallerCornerRadius, style: .continuous)
                    .fill(.secondAccent)
                    .strokeBorder(LinearGradient(colors: [.edgeLightShadow, .edgeDarkShadow],
                                         startPoint: .topLeading,
                                           endPoint: .bottomTrailing), lineWidth: 1)
                self.iconCircle
                
                Image(systemName: "plus.message.fill")
                    .foregroundStyle(.darkShadow)
                    .imageScale(self.isOpen ? .medium : .small)
            }
        }
        .scaleButtonStyle()
    }
    
    var button4 : some View {
        Button {
            if self.whisper.appSettings.silenceThreshold > 0.0 {
                self.whisper.appSettings.silenceThreshold -= 0.1
            }
        } label: {
            ZStack {
                UnevenRoundedRectangle(cornerRadii: .init(topLeading: self.smallerCornerRadius,
                                                          bottomLeading: (self.cornerRadius-self.paddingAmount),
                                                          bottomTrailing: self.smallerCornerRadius,
                                                          topTrailing: self.smallerCornerRadius),
                                       style: .continuous)
                .fill(.secondAccent)
                .strokeBorder(LinearGradient(colors: [.edgeLightShadow, .edgeDarkShadow],
                                             startPoint: .topLeading,
                                             endPoint: .bottomTrailing), lineWidth: 1)
                self.iconCircle
                Image(systemName: "minus")
                    .foregroundStyle(.black)
                    .imageScale(self.isOpen ? .medium : .small)
            }
        }
        .scaleButtonStyle()
    }
    
    var button5 : some View {
        Button {
            
        } label: {
            ZStack {
                UnevenRoundedRectangle(cornerRadii: .init(topLeading: self.smallerCornerRadius,
                                                          bottomLeading: self.smallerCornerRadius,
                                                          bottomTrailing: (self.cornerRadius-self.paddingAmount),
                                                          topTrailing: self.smallerCornerRadius),
                                       style: .continuous)
                    .fill(.secondAccent)
                    .strokeBorder(LinearGradient(colors: [.edgeLightShadow, .edgeDarkShadow],
                                         startPoint: .topLeading,
                                           endPoint: .bottomTrailing), lineWidth: 1)
                
                self.iconCircle
                
                Image(systemName: "antenna.radiowaves.left.and.right.circle.fill")
                    .foregroundStyle(.darkShadow)
                    .imageScale(self.isOpen ? .medium : .small)
            }
        }
        .scaleButtonStyle()
    }
    
    var body: some View {
        ZStack {
            /*
            RoundedRectangle(cornerRadius: self.cornerRadius, style: .continuous)
                .inset(by: -1)
                .fill(.mainAccent)
                .outerShadow(darkShadow: .darkShadow, lightShadow: .lightShadow)
            */
            RoundedRectangle(cornerRadius: self.cornerRadius, style: .continuous)
                .strokeBorder(LinearGradient(colors: [.darkShadow, .lightShadow],
                                     startPoint: .topLeading,
                                     endPoint: .bottomTrailing), lineWidth: 5)
            
            RoundedRectangle(cornerRadius: self.cornerRadius, style: .continuous)
                .inset(by: 3)
                .fill(.black)
            
            Grid(horizontalSpacing: 1.0, verticalSpacing: 1.0) {
                GridRow {
                    self.button0
                        //.aspectRatio(1.0, contentMode: .fit)
                    self.button1
                        //.aspectRatio(1.0, contentMode: .fit)
                }
                GridRow {
                    self.button2
                        //.aspectRatio(1.0, contentMode: .fit)
                    self.button3
                        //.aspectRatio(1.0, contentMode: .fit)
                }
                GridRow {
                    self.button4
                        //.aspectRatio(1.0, contentMode: .fit)
                    self.button5
                        //.aspectRatio(1.0, contentMode: .fit)
                }
            }
            .padding(.all, self.paddingAmount)
            
        }
        .aspectRatio(0.66666, contentMode: .fit)
    }
}


fileprivate struct TestView : View {
    
    @State var chatViewModel : ChatViewModel = .init(messageText: "hello")
    static let whisper : Whisper = .init()
    
    var body: some View {
        ZStack {
            Color.mainAccent.ignoresSafeArea()
            ControlsView(isOpen: true)
                .frame(width: 150)
        }
        .environment(self.chatViewModel)
        .environment(Self.whisper)
    }
}
#Preview {
    TestView()
}
