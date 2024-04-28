//
//  KarenRender.swift
//  Brain
//
//  Created by Owen O'Malley on 4/21/24.
//

import SwiftUI
import MetalKit

class KarenRenderer: NSObject, MTKViewDelegate {
    
    var parent: KarenView
    var metalDevice: MTLDevice!
    var metalCommandQueue: MTLCommandQueue!
    let pipelineState: MTLRenderPipelineState
    
    var fftBuffer : [Float]
    
    init(_ parent: KarenView, fftBuffer : inout [Float]) {
        
        self.parent = parent
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            self.metalDevice = metalDevice
        }
        self.metalCommandQueue = metalDevice.makeCommandQueue()
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        let library = metalDevice.makeDefaultLibrary()
        pipelineDescriptor.vertexFunction = library?.makeFunction(name: "vertexShader")
        pipelineDescriptor.fragmentFunction = library?.makeFunction(name: "fragmentShader")
        pipelineDescriptor.colorAttachments[0].pixelFormat = .rgba16Float
        
        do {
            try pipelineState = metalDevice.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError()
        }
        
        self.fftBuffer = fftBuffer

        super.init()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    func draw(in view: MTKView) {
        
        guard let drawable = view.currentDrawable else {
            return
        }
        
        var vertices : [Vertex] = []
        
        for (idx, value) in fftBuffer.enumerated() {
            let x : Float = 2 * Float(idx)/Float(fftBuffer.count) - 1.0
            let y : Float = Float.random(in: -0.5...0.5)
            print(x, value)
            vertices.append(Vertex(position: [x, value], color: [1, 1, 0, 1]))
        }
        
        let vertexBuffer = metalDevice.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride, options: [])!
        
        let commandBuffer = metalCommandQueue.makeCommandBuffer()
        
        let renderPassDescriptor = view.currentRenderPassDescriptor
        renderPassDescriptor?.colorAttachments[0].clearColor = MTLClearColorMake(0, 0.5, 0.5, 1.0)
        renderPassDescriptor?.colorAttachments[0].loadAction = .clear
        renderPassDescriptor?.colorAttachments[0].storeAction = .store
        
        let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor!)
        
        renderEncoder?.setRenderPipelineState(pipelineState)
        renderEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder?.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: fftBuffer.count)
        
        renderEncoder?.endEncoding()
        
        commandBuffer?.present(drawable)
        commandBuffer?.commit()
    }
}

#Preview {
    KarenView()
}
