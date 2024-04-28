//
//  SearchBar.swift
//  Brain
//
//  Created by Owen O'Malley on 2/6/24.
//

import SwiftUI

struct SearchBar: View {
    
    @Binding var text : String
    @Binding var isOpen : Bool
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.gray).font(Font.body.weight(.bold))
            if isOpen {
                TextField("Search...", text: $text).foregroundColor(.gray)
                    .opacity(isOpen ? 0.8 : 0.0)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 30).fill(.mainAccent)
            .innerShadow(RoundedRectangle(cornerRadius: 30),
                         darkShadow: .darkShadow,
                         lightShadow: .lightShadow,
                         spread: 0.5,
                         radius: 3)
        )
    }
}

#Preview {
    ZStack {
        Color.mainAccent.ignoresSafeArea()
        SearchBar(text: .constant(""), isOpen: .constant(true))
    }
}
