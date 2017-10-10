//
//  MetalView.swift
//  graphics
//
//  Created by Johannes Lugstein on 19/04/2017.
//  Copyright © 2017 Johannes Lugstein. All rights reserved.
//

import MetalKit

class MetalView: MTKView {
    
    var commandQueue : MTLCommandQueue!
    
    required init (coder: NSCoder) {
        super.init (coder: coder)
        initMetalObjects ()
    }

    /**
     * This is executed every single frame and uses the existing metal objects
     * to create the objects needed to render a single frame
     */
    override func draw(_ rect: CGRect) {
        // make command buffer that stores all the commands
        let commandBuffer = commandQueue?.makeCommandBuffer()
        
        // describe what to do in the current render pass
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = currentDrawable!.texture // set the input texture of the buffer to be the output texture from the buffer in the previous frame
        renderPassDescriptor.colorAttachments[0].loadAction = .clear // clear the texture ...
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 1, green: 0, blue: 0, alpha: 1) // ... by coloring it red
        
        let encoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        encoder?.endEncoding()  // translate the api commands into hardware commands and detach them from the buffer
        
        commandBuffer?.present(currentDrawable!)    // set the drawable of the buffer to present onto
        commandBuffer?.commit()                     // commit the buffer to be executed
    }
    
    /**
     * This is called once and it setups all the metal objects that
     * are needed the whole time the program is executed
     */
    func initMetalObjects () {
        device = MTLCreateSystemDefaultDevice ()    // initialize the metal device
        if device == nil {
            fatalError ("Your system does not have a GPU with metal support!")
        }
        commandQueue = device?.makeCommandQueue()   // make the Command Queue
    }

}
