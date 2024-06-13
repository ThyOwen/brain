//
//  ContentView.swift
//  chatbot
//
//  Created by Owen O'Malley on 8/13/23.
//

import SwiftUI

struct ContentView: View {
    
    @Environment(ChatViewModel.self) private var chatViewModel
    @Environment(Whisper.self) private var whisper
    
    @Environment(MessageBoard.self) private var messageBoard
    
    @State private var isPanel : Bool = true
    @State private var showWave : Bool = true
    
    @State private var showSalSignature : Bool = false
    @State private var showFftWave : Bool = true
    
    @Namespace private var pannelAnimation
    
    var chatMessageView : some View {
        LazyVStack(alignment: .center, spacing: 10) {
            ForEach(Chat.viewMessages[...(self.isPanel ? 6 : 1)]) { idx in
                HStack {
                    if idx.sender == Sender.user { Spacer() }
                    
                    Text(idx.text)
                        .font(.custom("zig", size: self.isPanel ? 10 : 8))
                        .foregroundStyle((idx.sender == Sender.sal ? .green : .white))
                        .blur(radius: 0.5)
                    
                    if idx.sender == Sender.sal { Spacer() }
                }
            }
            .frame(width: self.isPanel ? 250 : 100)
            .animation(.bouncy(duration: 2), value: self.isPanel)
        }
    }
    
    var salSignaturePath : some View {
        LoadingPath()
            .trim(from: 0.0, to: self.showSalSignature ? 1.0 : 0.0)
            .stroke(Color.lime, style: .init(lineWidth: 1.75, lineCap: .round))
            .animation(.easeInOut(duration: self.showSalSignature ? 3 : self.messageBoard.startupWaveFftDuration), value: self.showSalSignature)
    }
    
    var fftPath : some View {
        KarenWave(fftMagnitudes: self.whisper.fftMagnitudes, volume: self.whisper.lastBufferEnergy)
            .stroke(Color.lime.gradient,
                    style: StrokeStyle(lineWidth: 1.75, lineCap: .round))
    }
    
    var karenVisualizer : some View {
        ZStack {
            if self.showFftWave {
                self.fftPath
                    .blur(radius: 1.75, opaque: false)
                self.fftPath
                    .blur(radius: 0.75, opaque: false)
            } else {
                self.salSignaturePath
                    .blur(radius: 1.75, opaque: false)
                self.salSignaturePath
                    .blur(radius: 0.75, opaque: false)
            }

        }
        .padding(.all, 11)
    }
    
    var tv : some View {
        ZStack {
            TVView(isOpen: self.isPanel)

            ZStack {
                Color.black
                if self.showWave {
                    self.karenVisualizer
                        .transition(.opacity)
                } else {
                    self.chatMessageView
                        .transition(.opacity)
                }
            }
            .colorEffect(ShaderLibrary.coloredNoise(.float(0.4)))
            .mask {
                TV(insetAmount: 11)
            }
        }
        //.fixedSize(horizontal: false, vertical: true)
        .aspectRatio(1.2, contentMode: .fit)
        .animation(.linear(duration: 0.2), value: self.showWave)
        .innerShadow(TV(insetAmount: 11),
                     darkShadow: .tvLightHaze,
                     lightShadow: .black.opacity(0.7),
                     spread: 0.3,
                     radius: 20)
        .matchedGeometryEffect(id: "TV", in: self.pannelAnimation, properties: .frame)
        .transition(.offset())
        .zIndex(1)
    }
    
    var volumeIndicator : some View {
        MicrophoneIndicatorView(energyLevel: self.whisper.lastBufferEnergy,
                                threshold: self.whisper.appSettings.silenceThreshold,
                                isActive: self.whisper.isTranscribing)
        .frame(width: 300, height: 3)
        .matchedGeometryEffect(id: "indicator", in: pannelAnimation)
    }
    
    var statusView : some View {
        ZStack {
            Capsule()
                .fill(.secondAccent)
                .outerShadow(darkShadow: .darkShadow,
                             lightShadow: .lightShadow,
                             offset: 2,
                             radius: 4)
            Capsule()
                .inset(by: 3)
                .fill(.black)
                .outerShadow(darkShadow: .darkShadow,
                             lightShadow: .lightShadow,
                             offset: 2,
                             radius: 4)
            
            ZStack {
                Capsule()
                    .inset(by: 4)
                    .fill(.black)
                MessageBoardView(fontSize: 14)
            }
            .colorEffect(ShaderLibrary.coloredNoise(.float(0.35)))
                
        }
        .innerShadow(Capsule().inset(by: 4),
                     darkShadow: .tvLightHaze,
                     lightShadow: .black.opacity(0.7),
                     spread: 0.9,
                     radius: 4)
        .frame(height: 40)
        
        .zIndex(-1)
        
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
        VStack(alignment: .leading) {
            if self.whisper.appSettings.enableEagerDecoding && self.whisper.isStreamMode {
                let startSeconds = self.whisper.eagerResults.first??.segments.first?.start ?? 0
                let endSeconds = self.whisper.lastAgreedSeconds > 0 ? self.whisper.lastAgreedSeconds : self.whisper.eagerResults.last??.segments.last?.end ?? 0
                let timestampText = (self.whisper.appSettings.enableTimestamps && self.whisper.eagerResults.first != nil) ? "[\(String(format: "%.2f", startSeconds)) --> \(String(format: "%.2f", endSeconds))]" : ""
                Text("\(timestampText) \(Text(self.whisper.confirmedText).fontWeight(.bold))\(Text(self.whisper.hypothesisText).fontWeight(.bold).foregroundColor(.gray))")
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
                ForEach(Array(self.whisper.confirmedSegments.enumerated()), id: \.element) { _, segment in
                    let timestampText = self.whisper.appSettings.enableTimestamps ? "[\(String(format: "%.2f", segment.start)) --> \(String(format: "%.2f", segment.end))]" : ""
                    Text(timestampText + segment.text)
                        .font(.headline)
                        .fontWeight(.bold)
                        .tint(.green)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(Array(self.whisper.unconfirmedSegments.enumerated()), id: \.element) { _, segment in
                    let timestampText = self.whisper.appSettings.enableTimestamps ? "[\(String(format: "%.2f", segment.start)) --> \(String(format: "%.2f", segment.end))]" : ""
                    Text(timestampText + segment.text)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if self.whisper.appSettings.enableDecoderPreview {
                    Text("\(self.whisper.currentText)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
    
    var topPanelView: some View {
        SheetView(isOpen: $isPanel, maxHeightFraction: 0.8, minHeight: 250) {
            VStack(spacing: self.isPanel ? 40 : 25) {
                /*
                Button("asdfasdf") {
                    withAnimation {
                        self.showSalSignature.toggle()
                        self.showFftWave.toggle()
                    }
                }
                */
                if isPanel { self.tv }
                
                HStack(alignment: isPanel ? .bottom : .center, spacing: isPanel ? 20 : 15) {
                    Spacer()
                    
                    ControlsView(isOpen: self.isPanel, showWave: self.$showWave)
                    
                    if isPanel {
                        Spacer()
                    } else {
                        self.tv.frame(width: 180)
                    }
                    
                    (self.isPanel ? AnyLayout(ZStackLayout(alignment: .topTrailing)) : AnyLayout(VStackLayout())) {
                        MicrophoneToggleButtonView()
                            .frame(width: 60, height: 60)
                            .offset(x: self.isPanel ? 35 : 0, y: self.isPanel ? -55 : 0)
                        MicrophonePressAndHoldButtonView()
                    }
                        .matchedGeometryEffect(id: "button", in: pannelAnimation)
            
                    Spacer()
                }
                .fixedSize(horizontal: false, vertical: true)
                
                //self.volumeIndicator
                
            }
            .padding(.init(top: isPanel ? 25 : 00, leading: isPanel ? 20 : 0, bottom: isPanel ? 40 : 00, trailing: isPanel ? 20 : 0))
        }
        .animation(.easeInOut(duration: 0.4), value: self.isPanel)
        .frame(maxHeight: .infinity, alignment: .top)
    }
    
    var bottomPanelView: some View {
        ZStack {
            VStack {
                Spacer()
                self.statusView
                    .padding(.bottom, 40)
                    .padding(.horizontal, 40)
            }
        }
    }
    
    var body: some View {
        ZStack {
            self.bottomPanelView
            self.topPanelView
        }
        .drawingGroup()
        .background(.secondAccent, ignoresSafeAreaEdges: .bottom)
        .background(.mainAccent, ignoresSafeAreaEdges: .top)
        .edgesIgnoringSafeArea(.bottom)
        
        .onAppear {
            self.messageBoard.startTextRealtimeLoop()
            withAnimation {
                self.showSalSignature = true
            }
        }
    }
}



fileprivate struct TestView : View {
    
    var chatViewModel : ChatViewModel
    var whisper : Whisper
    var messageBoard : MessageBoard
    
    init() {
        let messageBoard = MessageBoard.init()
        
        self.whisper = .init(messageBoard: messageBoard)
        self.chatViewModel = .init(username: "me", serverAddress: ServerConstants.serverAddress, serverPort: ServerConstants.serverPort, messageBoard: messageBoard)
        self.messageBoard = messageBoard
    }
    
    var body: some View {
        ContentView()
            .environment(self.chatViewModel)
            .environment(self.whisper)
            .environment(self.messageBoard)
    }
}

#Preview {
    TestView()
}
