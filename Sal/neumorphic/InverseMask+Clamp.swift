//
//  InverseMask.swift
//  Brain
//
//  Created by Owen O'Malley on 2/2/24.
//

import SwiftUI

extension View {
  func inverseMask<Mask>(_ mask: Mask) -> some View where Mask: View {
    self.mask(mask
      .foregroundColor(.black)
      .background(Color.white)
      .compositingGroup()
      .luminanceToAlpha()
    )
  }
}
