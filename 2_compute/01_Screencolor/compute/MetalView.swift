//
// Created by Johannes Lugstein on 10/04/2017.
// Copyright (c) 2017 Johannes Lugstein. All rights reserved.
//

import MetalKit

public class MetalView : MTKView {

    var commandQueue: MTLCommandQueue!
    var computePipelineState: MTLComputePipelineState!
    
    required public init(coder: NSCoder) {
        super.init(coder: coder)
        initMetalObjects()
    }
    
    /**
     * This is called once and it setups all the metal objects that
     * are needed the whole time the program is executed
     */
    func initMetalObjects(){
        self.framebufferOnly = false    // compute kernel functions need to execute pixelbased read/write operations so by setting framebufferonly to false this is enabled
        device = MTLCreateSystemDefaultDevice() // initialize the metal device
        let library = device!.newDefaultLibrary()!  // a shader library is needed
        let kernel = library.makeFunction(name: "compute")! // the compute function from the shaderfile is added to the library
        computePipelineState = try! device!.makeComputePipelineState(function: kernel)  // A handle to for a compute function is created
        commandQueue = device?.makeCommandQueue() // make the Command Queue
    }
    
    /**
     * This is executed every single frame and uses the existing metal objects
     * to create the objects needed to render a single frame
     */
    override public func draw(_ rect: CGRect) {
        // make command buffer that stores all the commands
        let commandBuffer = commandQueue.makeCommandBuffer()
        
        // no renderpass desciptor neede - the computecommandencoder only needs a texture to work with
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()
        commandEncoder.setComputePipelineState(computePipelineState)
        commandEncoder.setTexture(currentDrawable?.texture, at: 0)  // draw to the texture of the currentview
        let threadGroupCount = MTLSizeMake(8, 8, 1)
        let threadGroups = MTLSizeMake((currentDrawable?.texture.width)! / threadGroupCount.width, (currentDrawable?.texture.height)! / threadGroupCount.height, 1)
        commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)  // Compute function is enqueued
        commandEncoder.endEncoding() // translate the api commands into hardware commands and detach them from the buffer
        
        commandBuffer.present((currentDrawable)!) // set the drawable of the buffer to present onto
        commandBuffer.commit()  // commit the buffer to be executed
    }
}
