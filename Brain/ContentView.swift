//
//  ContentView.swift
//  chatbot
//
//  Created by Owen O'Malley on 8/13/23.
//

import SwiftUI

struct ContentView: View {
    
    @State var isPanel : Bool = true
    
    @State var whisper = Whisper()
    
    @State private var size : CGFloat = 100
    
    @Namespace private var pannelAnimation
    
    private var energy : Float {
        get { self.whisper.bufferEnergy.last ?? 0.0 }
    }
    

    var karenVisualizer : some View {
        TVView(rimColor: .mainAccent, shadow: 10)
            .scenePadding()
            .matchedGeometryEffect(id: "TV", in: pannelAnimation, properties: .frame)
            .transition(.offset())
            .zIndex(1)

    }
    
    var statusView : some View {
        HStack {
            Text(self.whisper.effectiveRealTimeFactor.formatted(.number.precision(.fractionLength(3))) + " RTF")
                .font(.body)
                .lineLimit(1)
            Text(self.whisper.tokensPerSecond.formatted(.number.precision(.fractionLength(0))) + " tok/s")
                .font(.body)
                .lineLimit(1)
        }
        //.ignoresSafeArea()
        .matchedGeometryEffect(id: "StatusView", in: pannelAnimation)
        //.transition(.move(edge: .bottom))
        .transition(.scale)
    }
    
    var topPanelView: some View {
        SheetView(isOpen: $isPanel, maxHeightFraction: 0.8, minHeight: 240) {
            VStack {
                if isPanel { self.statusView }
                
                if isPanel { self.karenVisualizer }
                
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

                /*
                ChatRoledex(
                    chat: .constant(Chat(messages: ChatMessage.viewMessages)),
                    processing: .constant(true)
                ).padding()
                 */
                
                HStack(alignment: isPanel ? .bottom : .center, spacing: isPanel ? 25 : 5) {
                    Spacer()
                    VStack(spacing: isPanel ? 15 : 8) {
                        MicrophoneIndicatorView(loudness: self.whisper.fftLoudness,
                                                energyLevel: self.energy,
                                                threshold: self.whisper.appSettings.silenceThreshold, 
                                                isActive: self.whisper.isTranscribing)
                            .matchedGeometryEffect(id: "indicator", in: pannelAnimation)
                        
                        MicrophoneDialView(sensitivity: self.whisper.appSettings.$silenceThreshold)
                            .matchedGeometryEffect(id: "dial", in: pannelAnimation)
                        
                    }.fixedSize(horizontal: false, vertical: true)
                    
                    if isPanel {
                        Spacer()
                    } else {
                        self.karenVisualizer.frame(width: 200)
                    }
                    
                    MicrophoneButtonView(whisper: self.whisper)
                        .matchedGeometryEffect(id: "button", in: pannelAnimation)
            
                    Spacer()
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 10)
                
                
            }
            .padding(.init(top: 0, leading: 0, bottom: isPanel ? 40 : 00, trailing: 0))
            

        }
        
        .animation(.easeInOut(duration: 0.4), value: self.isPanel)
        .frame(maxHeight: .infinity, alignment: .top)
    }
    
    var body: some View {
        ZStack {
            Text("contentView")
            topPanelView
        }
        .drawingGroup()
        .background(.secondAccent, ignoresSafeAreaEdges: .bottom)
        .background(.mainAccent, ignoresSafeAreaEdges: .top)
        .edgesIgnoringSafeArea(.bottom)
        
    }
}



#Preview {
    ContentView()
}
