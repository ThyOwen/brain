//
//  AsyncButtom.swift
//  Brain
//
//  Created by Owen O'Malley on 2/4/24.
//

import SwiftUI

struct UserButtonsParams : Identifiable {
    var action: () async throws -> Void
    let label : String
    
    let id = UUID()
}

struct AsyncButton: View {
    
    var action: () async throws -> Void
    
    var text: String
    
    @State private var isPerformingTask = false
    @State private var isCompleted = false
       
    var body: some View {
        Button(
            action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                    isPerformingTask = true
                }
                
                Task {
                    try await action()
                    // The task is complited
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                        isPerformingTask = false
                        isCompleted = true
                    }
                                    
                    // Go back to the inactive state of the button
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                            isCompleted = false
                        }
                    }
                }
            },
            
            label: {
                    Text(text)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                        
            }
        )
        .softButtonStyle(Circle(),
                         mainColor: .mainAccent,
                         darkShadowColor: .darkShadow,
                         lightShadowColor: .lightShadow,
                         pressedEffect: .hard)
        .bold()
        .disabled(isPerformingTask || isCompleted)
        
        .drawingGroup()
    }
}

#Preview {
    ZStack {
        Color.mainAccent.ignoresSafeArea()
        AsyncButton(action: action, text: "Try Me")
    }
}

func action() async throws  {
    try await Task.sleep(nanoseconds: 2 * 1_000_000_000)  // Three seconds
}


