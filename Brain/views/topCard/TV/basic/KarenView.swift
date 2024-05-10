//
//  KarenView.swift
//  Brain
//
//  Created by Owen O'Malley on 4/21/24.
//

import SwiftUI
import MetalKit

/*
struct KarenView: ViewRepresentable {
    

    func makeView(context: Context) -> MTKView {
        
        let mtkView = MTKView()
        mtkView.delegate = context.coordinator
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = true
        
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            mtkView.device = metalDevice
        }
        
        mtkView.framebufferOnly = false
        mtkView.drawableSize = mtkView.frame.size
        
        if let layer = mtkView.layer as? CAMetalLayer {
            // Enable EDR with a color space that supports values greater than SDR.
            if #available(iOS 16.0, *) {
                layer.wantsExtendedDynamicRangeContent = true
            }
            layer.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)
            // Ensure the render view supports pixel values in EDR.
            mtkView.colorPixelFormat = MTLPixelFormat.rgba16Float
        }
        return mtkView
    }
    
    func updateView(_ view: MTKView, context: Context) {
        
    }
}


#Preview {
    KarenView()
}

*/
