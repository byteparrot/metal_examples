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
    var vertexDescriptor = MTLVertexDescriptor()
    var uniformBuffer : MTLBuffer!
    var renderPipelineState : MTLRenderPipelineState!
    var depthStencilState: MTLDepthStencilState!
    
    var meshes: [MTKMesh]!
    var texture: MTLTexture!
    
    required init (coder: NSCoder) {
        super.init (coder: coder)
        self.colorPixelFormat = .bgra8Unorm
        initMetalObjects ()
        setupRenderPipeline()
        createModel()
        updateTransformations()
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
        
        // Setup Depth Stencil
        self.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = MTLCompareFunction.less
        descriptor.isDepthWriteEnabled = true
        depthStencilState = device?.makeDepthStencilState(descriptor: descriptor)
    }
    
    /**
     * This is called once and it setups render pipeline
     */
    func setupRenderPipeline () {
        // MTLLibrary needed for shaders stored in the Shaders.metal file
        let library = device!.newDefaultLibrary()!
        let vertexShader = library.makeFunction(name: "vertexShader")
        let fragmentShader = library.makeFunction(name: "fragmentShader")
        
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].format = MTLVertexFormat.float3 // position
        vertexDescriptor.attributes[1].offset = 12
        vertexDescriptor.attributes[1].format = MTLVertexFormat.uchar4 // color
        vertexDescriptor.attributes[2].offset = 16
        vertexDescriptor.attributes[2].format = MTLVertexFormat.half2 // texture
        vertexDescriptor.attributes[3].offset = 20
        vertexDescriptor.attributes[3].format = MTLVertexFormat.float // occlusion
        vertexDescriptor.layouts[0].stride = 24
        
        // To tell the render pass later to execute this shaders they have to be assigned to a MTLRenderPipelineState
        // However a MTLRenderPipelineState can only be obtained by a MTLRenderPipelineDescriptor
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexDescriptor = vertexDescriptor
        renderPipelineDescriptor.vertexFunction = vertexShader
        renderPipelineDescriptor.fragmentFunction = fragmentShader
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        renderPipelineDescriptor.depthAttachmentPixelFormat = self.depthStencilPixelFormat
        renderPipelineDescriptor.stencilAttachmentPixelFormat = self.depthStencilPixelFormat
        renderPipelineState = try! device!.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
    }
    
    /**
     * This is called once and it setups the vertices that should be drawn
     */
    func createModel () {
        
        // set up the asset initialization
        
        let desc = MTKModelIOVertexDescriptorFromMetal(vertexDescriptor)
        var attribute = desc.attributes[0] as! MDLVertexAttribute
        attribute.name = MDLVertexAttributePosition
        attribute = desc.attributes[1] as! MDLVertexAttribute
        attribute.name = MDLVertexAttributeColor
        attribute = desc.attributes[2] as! MDLVertexAttribute
        attribute.name = MDLVertexAttributeTextureCoordinate
        attribute = desc.attributes[3] as! MDLVertexAttribute
        attribute.name = MDLVertexAttributeOcclusionValue
        let mtkBufferAllocator = MTKMeshBufferAllocator(device: device!)
        guard let url = Bundle.main.url(forResource: "parrot", withExtension: "obj") else {
            fatalError("Resource not found.")
        }
        let asset = MDLAsset(url: url, vertexDescriptor: desc, bufferAllocator: mtkBufferAllocator)
        
        let loader = MTKTextureLoader(device: device!)
        guard let file = Bundle.main.path(forResource: "parrot", ofType: "png") else {
            fatalError("Resource not found.")
        }
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: file))
            
            texture = try loader.newTexture(with: data, options: [MTKTextureLoaderOptionOrigin: MTKTextureLoaderOriginFlippedVertically as NSObject])
            
        }
        catch let error {
            fatalError("\(error)")
        }
        
        // set up MetalKit mesh and submesh objects
        
        guard let mesh = asset.object(at: 0) as? MDLMesh else {
            fatalError("Mesh not found.")
        }
        mesh.generateAmbientOcclusionVertexColors(withQuality: 1, attenuationFactor: 0.98, objectsToConsider: [mesh], vertexAttributeNamed: MDLVertexAttributeOcclusionValue)
        do {
            meshes = try MTKMesh.newMeshes(from: asset, device: device!, sourceMeshes: nil)
        }
        catch let error {
            fatalError("\(error)")
        }
        
    }
    
    func updateTransformations() {
        // Make the different transformations
        let scaled = scalingMatrix(0.2)
        let rotatedX = rotationMatrix(-Float(Double.pi) / 16, float3(1, 0, 0))
        let rotatedY = rotationMatrix(Float(Double.pi) / 16, float3(0, 1, 0))
        let translated = translationMatrix(float3(0, -10, 0))
        let modelMatrix = matrix_multiply(matrix_multiply(matrix_multiply(translated, rotatedX), rotatedY), scaled)
        
        // offset the camera
        let cameraPosition = vector_float3(0, 0, -50)
        let viewMatrix = translationMatrix(cameraPosition)
        let aspectratio = Float(drawableSize.width / drawableSize.height)
        let projMatrix = projectionMatrix(near: 0.1, far: 100, aspect: aspectratio, fovy: 1)
        let modelViewProjectionMatrix = matrix_multiply(projMatrix, matrix_multiply(viewMatrix, modelMatrix))
        
        // the transformations are handed to the gpu in a MTLBuffer
        uniformBuffer = device!.makeBuffer(length: MemoryLayout<matrix_float4x4>.size, options: [])
        let modelUniform = Uniforms(modelViewProjectionMatrix)
        uniformBuffer.contents().storeBytes(of: modelUniform, toByteOffset: 0, as: Uniforms.self)
    }
    
    /**
     * This is executed every single frame and uses the existing metal objects
     * to create the objects needed to render a single frame
     */
    override func draw(_ rect: CGRect) {
        updateTransformations()
        
        // make command buffer that stores all the commands
        let commandBuffer = commandQueue?.makeCommandBuffer()
        
        // describe what to do in the current render pass
        let renderPassDescriptor = currentRenderPassDescriptor
        renderPassDescriptor?.colorAttachments[0].texture = currentDrawable!.texture // set the input texture of the buffer to be the output texture from the buffer in the previous frame
        renderPassDescriptor?.colorAttachments[0].loadAction = .clear // clear the texture ...
        renderPassDescriptor?.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1) // ... by coloring it black
        renderPassDescriptor?.colorAttachments[0].storeAction = .store
        
        renderPassDescriptor?.depthAttachment.loadAction = .clear
        renderPassDescriptor?.depthAttachment.clearDepth = 1.0
        renderPassDescriptor?.depthAttachment.storeAction = .dontCare
        
        let encoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor!)
        encoder?.setDepthStencilState(depthStencilState)
        encoder?.setRenderPipelineState(renderPipelineState)
        encoder?.setFrontFacing(.counterClockwise)
        encoder?.setCullMode(.back)
        encoder?.setVertexBuffer(uniformBuffer, offset: 0, at: 1)
        encoder?.setFragmentTexture(texture, at: 0)
        
        // set up Metal rendering and drawing of meshes
        
        guard let mesh = meshes?.first else {
            fatalError("Mesh not found.")
        }
        let vertexBuffer = mesh.vertexBuffers[0]
        encoder?.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, at: 0)
        guard let submesh = mesh.submeshes.first else {
            fatalError("Submesh not found.")
        }
        encoder?.drawIndexedPrimitives(type: submesh.primitiveType, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: submesh.indexBuffer.offset)
        
        encoder?.endEncoding()  // translate the api commands into hardware commands and detach them from the buffer
        
        commandBuffer?.present(currentDrawable!)    // set the drawable of the buffer to present onto
        commandBuffer?.commit()                     // commit the buffer to be executed
    }

}
