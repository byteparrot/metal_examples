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
    var vertexBufffer : MTLBuffer!
    var indexBuffer : MTLBuffer!
    var uniformBuffer : MTLBuffer!
    var renderPipelineState : MTLRenderPipelineState!
    
    required init (coder: NSCoder) {
        super.init (coder: coder)
        initMetalObjects ()
        createModel()
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
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1) // ... by coloring it black
        
        let encoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        encoder?.setRenderPipelineState(renderPipelineState)
        encoder?.setVertexBuffer(vertexBufffer, offset: 0, at: 0)
        encoder?.setVertexBuffer(uniformBuffer, offset: 0, at: 1)
        encoder?.drawIndexedPrimitives(type: .triangle, indexCount: indexBuffer.length / MemoryLayout<UInt16>.size, indexType: MTLIndexType.uint16, indexBuffer: indexBuffer, indexBufferOffset: 0)
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
    
    /**
     * This is called once and it setups the vertices that should be drawn
     */
    func createModel () {
        // 3 vertices with x,y,z and w coordinates (same w means homogenous)
        let vertices = [
            Vertex(position: [-1.0, -1.0, 0.0,  1.0], color: [1, 0, 0, 1]),
            Vertex(position: [ 1.0, -1.0, 0.0,  1.0], color: [0, 1, 0, 1]),
            Vertex(position: [ 1.0,  1.0, 0.0,  1.0], color: [0, 0, 1, 1]),
            Vertex(position: [-1.0,  1.0, 0.0,  1.0], color: [1, 1, 1, 1])
        ]
        
        let indexes: [UInt16] = [
            0, 1, 2, 2, 3, 0
        ]
        
        // vertices are handed to the gpu in a MTLBuffer
        vertexBufffer = device?.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.size, options: [])
        indexBuffer = device!.makeBuffer(bytes: indexes, length: MemoryLayout<UInt16>.size * indexes.count , options: [])
        
        // Make the different transformations
        let scaled = scalingMatrix(0.5)
        let rotated = rotationMatrix(Float(Double.pi) / 4, float3(0, 0, 1))
        let translated = translationMatrix(float3(0, -0.2, 0))
        let aspectratio = Float(self.drawableSize.width / self.drawableSize.height)
        print(aspectratio)
        let aspectscale = scalingYMatrix(aspectratio)
        let modelViewProjectionMatrix = matrix_multiply(matrix_multiply(matrix_multiply(aspectscale, translated), rotated), scaled)
        
        // the transformations are handed to the gpu in a MTLBuffer
        uniformBuffer = device!.makeBuffer(length: MemoryLayout<matrix_float4x4>.size, options: [])
        let modelUniform = Uniforms(modelViewProjectionMatrix)
        uniformBuffer.contents().storeBytes(of: modelUniform, toByteOffset: 0, as: Uniforms.self)
        
        // MTLLibrary needed for shaders stored in the Shaders.metal file
        let library = device!.newDefaultLibrary()!
        let vertexShader = library.makeFunction(name: "vertexShader")
        let fragmentShader = library.makeFunction(name: "fragmentShader")
        
        // To tell the render pass later to execute this shaders they have to be assigned to a MTLRenderPipelineState
        // However a MTLRenderPipelineState can only be obtained by a MTLRenderPipelineDescriptor
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexFunction = vertexShader
        renderPipelineDescriptor.fragmentFunction = fragmentShader
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        renderPipelineState = try! device!.makeRenderPipelineState(descriptor: renderPipelineDescriptor)

    }

}
