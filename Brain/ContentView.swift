//
//  ContentView.swift
//  chatbot
//
//  Created by Owen O'Malley on 8/13/23.
//

import SwiftUI

struct ContentView: View {
    
    @Environment(Whisper.self) private var whisper
    @Environment(ChatViewModel.self) private var chatViewModel
    
    @State var chat = Chat()
    
    @State private var isPanel : Bool = true
    
    @Namespace private var pannelAnimation
    
    private var modelLoaded : Bool { self.whisper.modelState == .loaded }
    
    var chatMessageView : some View {
        LazyVStack(alignment: .center, spacing: 10) {
            ForEach(Chat.viewMessages[...(self.isPanel ? 6 : 1)]) { idx in
                HStack {
                    if case idx.sender = Sender.user { Spacer() }
                    
                    Text(idx.content)
                        .font(.custom("zig", size: self.isPanel ? 10 : 8))
                        .foregroundStyle((idx.sender == .bot ? .green : .white))
                        .blur(radius: 0.3)
                    
                    if case idx.sender = Sender.bot { Spacer() }
                }
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.bouncy(duration: 5.0), value: self.isPanel)
    }
    
    var karenPath : some View {
        KarenWave(fftSamples: self.whisper.fftMagnitudes, volume: self.whisper.lastBufferEnergy)
            .stroke(Color.lime.gradient,
                    style: StrokeStyle(lineWidth: 2.0, lineCap: .butt))
    }
    
    var karenVisualizer : some View {
        ZStack {
            self.karenPath
                .blur(radius: 2.5, opaque: false)
            self.karenPath
                .blur(radius: 0.75, opaque: false)
            
        }
        .padding(.all, 11)
    }
    
    var tv : some View {
        ZStack {
            TVView(isOpen: self.isPanel)

            ZStack {
                Color.black
                if self.chatViewModel.showWave {
                    self.karenVisualizer
                        .transition(.opacity)
                } else {
                    self.chatMessageView
                        .transition(.opacity)
                }
            }
            .mask {
                TV(insetAmount: 11)
            }
            .colorEffect(ShaderLibrary.coloredNoise())
            
        }
        //.fixedSize(horizontal: false, vertical: true)
        .aspectRatio(1.2, contentMode: .fit)
        .animation(.linear(duration: 0.2), value: self.chatViewModel.showWave)
        .innerShadow(TV(insetAmount: 11),
                     darkShadow: .tvLightHaze,
                     lightShadow: .black.opacity(0.7),
                     spread: 0.3,
                     radius: 30)
        .matchedGeometryEffect(id: "TV", in: self.pannelAnimation, properties: .frame)
        .transition(.offset())
        .zIndex(1)
    }
    
    var volumeIndicator : some View {
        MicrophoneIndicatorView(energyLevel: self.whisper.lastBufferEnergy,
                                threshold: self.whisper.appSettings.silenceThreshold,
                                isActive: self.whisper.isTranscribing)
        .frame(width: 250, height: 3)
            .matchedGeometryEffect(id: "indicator", in: pannelAnimation)
    }
    
    var statusView : some View {
        ChatRoledex(fontSize: self.isPanel ? 14 : 12)
            .frame(maxWidth: .infinity, minHeight: 35, maxHeight: 50)
            .offset(y: -15)
            .background {
                /*
                LinearGradient(colors: [.black, .clear],
                               startPoint: .bottom,
                               endPoint: .top)
                
                //Color.black
                 
                .offset(y: -10)
                 */
            }
    }
    
    var whisperInfoView : some View {
        HStack {
            Text(self.whisper.effectiveRealTimeFactor.formatted(.number.precision(.fractionLength(3))) + " RTF")
                .font(.body)
                .lineLimit(1)
            Text(self.whisper.tokensPerSecond.formatted(.number.precision(.fractionLength(0))) + " tok/s")
                .font(.body)
                .lineLimit(1)
        }
        //.ignoresSafeArea()
        .matchedGeometryEffect(id: "WhisperInfoView", in: pannelAnimation)
        //.transition(.move(edge: .bottom))
        .transition(.scale)
    }
        
    var textView : some View {
        Group {
            if self.whisper.appSettings.enableEagerDecoding {
                Text("\(Text(self.whisper.confirmedText).fontWeight(.bold))\(Text(self.whisper.hypothesisText).fontWeight(.bold).foregroundColor(.gray))")
                    .font(.headline)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if self.whisper.appSettings.enableDecoderPreview {
                    Text("\(self.whisper.currentText)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top)
                }
            } else {
                /*
                ForEach(Array(self.whisper.confirmedSegments.enumerated()), id: \.element) { _, segment in
                    Text(segment.text)
                        .font(.headline)
                        .fontWeight(.bold)
                        .tint(.green)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(Array(self.whisper.unconfirmedSegments.enumerated()), id: \.element) { _, segment in
                    Text(segment.text)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                 */
                ForEach(Array(self.whisper.combined.enumerated()), id: \.element) { _, segment in
                    Text(segment)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
    
    var topPanelView: some View {
        SheetView(isOpen: $isPanel, maxHeightFraction: 0.8, minHeight: 250) {
            VStack(spacing: self.isPanel ? 40 : 15) {
                
                if isPanel { self.tv }
                
                //if isPanel { self.statusView }
                
                HStack(alignment: isPanel ? .bottom : .center, spacing: isPanel ? 20 : 10) {
                    Spacer()
                    
                    ControlsView(isOpen: self.isPanel)
                    
                    if isPanel {
                        Spacer()
                    } else {
                        self.tv.frame(width: 200)
                    }
                    
                    MicrophoneButtonView()
                        .matchedGeometryEffect(id: "button", in: pannelAnimation)
            
                    Spacer()
                }
                .fixedSize(horizontal: false, vertical: true)
                
                self.volumeIndicator
                //self.statusView
                
            }
            .padding(.init(top: 25, leading: isPanel ? 20 : 0, bottom: isPanel ? 40 : 00, trailing: isPanel ? 20 : 0))
            

        }
        .animation(.easeInOut(duration: 0.4), value: self.isPanel)
        .frame(maxHeight: .infinity, alignment: .top)
    }
    
    var body: some View {
        ZStack {
            Text("contentView")
            self.topPanelView
            
        }
        .allowedDynamicRange(.high)
        .drawingGroup()
        .background(.secondAccent, ignoresSafeAreaEdges: .bottom)
        .background(.mainAccent, ignoresSafeAreaEdges: .top)
        .edgesIgnoringSafeArea(.bottom)
        .onAppear {
            self.chatViewModel.startTextRealtimeLoop()
        }
        .onChange(of: self.isPanel) { oldValue, newValue in
            if newValue {
                self.chatViewModel.characterLimit = ChatViewModel.characterLimitUpperBound
            } else {
                self.chatViewModel.characterLimit = ChatViewModel.characterLimitLowerBound
            }
        }
        
    }
}



fileprivate struct TestView : View {
    
    static let whisper : Whisper = .init()
    static let chatViewModel : ChatViewModel = .init(messageText: "Ohio will invade the world")
    
    var body: some View {
        ContentView()
            .environment(Self.whisper)
            .environment(Self.chatViewModel)
    }
}

#Preview {
    TestView()
}
