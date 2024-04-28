//
//  test.swift
//  Brain
//
//  Created by Owen O'Malley on 2/3/24.
//

import SwiftUI

public enum SheetViewGestureState {
    case inactive
    case active(translationHeight : CGFloat)
    
    var isActive: Bool {
        switch self {
        case .inactive:
            return false
        case .active:
            return true
        }
    }
    
    var translationHeight: CGFloat {
        switch self {
        case .inactive:
            return .zero
        case .active(let height):
            return height
        }
    }
}

struct SheetView<Content: View>: View {
    @Binding var isOpen: Bool
    let maxHeight: CGFloat
    let minHeight : CGFloat
    let content: Content
    
    private let snapDistance : CGFloat
    
    @GestureState private var gestureState: SheetViewGestureState = .inactive
    private var gestureIsOpen : Bool {
        if self.isOpen {
            return abs(self.gestureState.translationHeight) < self.snapDistance
        } else {
            return abs(self.gestureState.translationHeight) > self.snapDistance
        }
    }
    
    private let radius: CGFloat = 16
    private let indicatorHeight: CGFloat = 6
    private let indicatorWidth: CGFloat = 60
    private let snapRatio: CGFloat = 0.25

    private var baseOffset: CGFloat {
        self.isOpen ? self.maxHeight - self.minHeight : 0
    }

    init(isOpen: Binding<Bool>,
         maxHeightFraction: CGFloat,
         minHeight : CGFloat,
         @ViewBuilder content: () -> Content) {
        #if os(macOS)
            self.maxHeight = (NSScreen.main?.frame.height ?? 400) * maxHeightFraction 
        #elseif os(iOS)
            self.maxHeight = UIScreen.main.bounds.height * maxHeightFraction
        #endif
        self.minHeight = minHeight
        self.content = content()
        self._isOpen = isOpen
        
        self.snapDistance = maxHeight * self.snapRatio
    }
    
    var indicator: some View {
        RoundedRectangle(cornerRadius: self.radius)
            .fill(.gray)
            .frame(
                width: self.indicatorWidth,
                height: self.indicatorHeight
        ).onTapGesture {
            withAnimation(.easeInOut(duration: 0.4)) {
                self.isOpen.toggle()
            }
        }
    }
    
    var dragGesture : some Gesture {
        DragGesture()
            .updating(self.$gestureState) { value, state, _ in
                state = .active(translationHeight: value.translation.height)
            }
            .onEnded { value in
                
                let adjValue = value.translation.height
                
                guard abs(adjValue) > self.snapDistance else {
                    return
                }
                self.isOpen = adjValue > 0
            }
    }
    
    var body: some View {
            ZStack(alignment: .bottom) {
                self.content
                    .frame(height: self.minHeight + Self.clamp(self.baseOffset + self.gestureState.translationHeight, in: 0...self.maxHeight), alignment: .center )
                self.indicator
                    .offset(y: -15)
            }
            .frame(maxWidth: .infinity)
        //.frame(height: self.minHeight + Self.clamp(self.baseOffset + self.gestureState.translationHeight, in: 0...self.maxHeight), alignment: .bottom)
            .background {
                ZStack {
                    
                    UnevenRoundedRectangle(cornerRadii: .init(topLeading: 0,
                                                                bottomLeading: 60,
                                                                bottomTrailing: 60,
                                                                topTrailing: 0),
                                            style: .continuous)
                    .fill(.mainAccent)
                    .padding(.top, Self.clamp(self.baseOffset + self.gestureState.translationHeight, in: 0...self.maxHeight) + 60)
                    
                    
                    .outerShadow(darkShadow: .darkShadow,
                                    lightShadow: nil,
                                    offset: 10,
                                    radius: 10)

                    
                    UnevenRoundedRectangle(cornerRadii: .init(topLeading: 0,
                                                                bottomLeading: 60,
                                                                bottomTrailing: 60,
                                                                topTrailing: 0),
                                            style: .continuous)
                    .fill(.mainAccent)
                        
                    }
                }
            .animation(.interactiveSpring, value: self.gestureState.translationHeight)
            .gesture(self.dragGesture)
            .onChange(of: self.gestureIsOpen) { oldValue, newValue in
                print(self.gestureIsOpen)
                
                
            }
    }
    
    private static func clamp<T: Comparable>(_ value: T, in range: ClosedRange<T>) -> T {
        return min(max(value, range.lowerBound), range.upperBound)
    }

}

#Preview {
    SheetView(isOpen: .constant(false), maxHeightFraction: 0.5, minHeight: 200) {
        ZStack {
            //RoundedRectangle(cornerRadius: 0).fill(Color.red)
            Text("fuck")
        }.frame(maxHeight: .infinity)
    }//.edgesIgnoringSafeArea(.all)
}
