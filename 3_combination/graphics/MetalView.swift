//
//  MetalView.swift
//  graphics
//
//  Created by Johannes Lugstein on 19/04/2017.
//  Copyright © 2017 Johannes Lugstein. All rights reserved.
//

import MetalKit
import CoreMotion

class MetalView: MTKView {
    
    var commandQueue : MTLCommandQueue!
    var vertexDescriptor = MTLVertexDescriptor()
    var uniformBuffer : MTLBuffer!
    var renderPipelineState : MTLRenderPipelineState!
    var depthStencilState: MTLDepthStencilState!
    
    var computePipelineState: MTLComputePipelineState!
    
    var oldTime: CFTimeInterval!
    var deltaTime: Float!
    
    let motionManager = CMMotionManager()
    
    var timer: Float = 0
    var pos: float2!
    var rot = float3(0,0,0)
    
    var timerBuffer: MTLBuffer!
    var touchBuffer: MTLBuffer!
    var rotationBuffer: MTLBuffer!
    
    var meshes: [MTKMesh]!
    var texture: MTLTexture!
    
    var currentRotation: float3!
    
    required init (coder: NSCoder) {
        super.init (coder: coder)
        self.colorPixelFormat = .bgra8Unorm
        self.framebufferOnly = false    // compute kernel functions need to execute pixelbased read/write operations so by setting framebufferonly to false this is enabled
        oldTime = CACurrentMediaTime()
        pos = float2(Float(drawableSize.width/4),Float(drawableSize.height/4))
        
        currentRotation = float3(-Float(Double.pi) / 16, Float(Double.pi) / 16, 0)
        
        if motionManager.isMagnetometerAvailable {
            motionManager.deviceMotionUpdateInterval = 0.02;
            
            motionManager.startDeviceMotionUpdates(to: OperationQueue.current!, withHandler: {(data,error) in
                if let myData = data {
                    self.rot = float3(Float(myData.attitude.pitch),Float(myData.attitude.roll),Float(myData.attitude.yaw))
                }
            } )
        }

        initMetalObjects ()
        setupRenderPipeline()
        createModel()
        updateTransformations()

    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            pos = float2(Float(touch.location(in: self).x),Float(touch.location(in: self).y))
        }
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
        
        let kernel = library.makeFunction(name: "compute")! // the compute function from the shaderfile is added to the library
        computePipelineState = try! device!.makeComputePipelineState(function: kernel)  // A handle to for a compute function is created
        timerBuffer = device!.makeBuffer(length: MemoryLayout<Float>.size, options: []) // New buffer to store the current time since start
        touchBuffer = device!.makeBuffer(length: MemoryLayout<float2>.size, options: [])
        rotationBuffer = device!.makeBuffer(length: MemoryLayout<float3>.size, options: [])
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
        
        currentRotation.y -= 1 / 100 * Float(Double.pi) / 4
        
        // Make the different transformations
        let scaled = scalingMatrix(0.2)
        let rotatedX = rotationMatrix(currentRotation.x, float3(1, 0, 0))
        let rotatedY = rotationMatrix(currentRotation.y, float3(0, 1, 0))
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
        
        let newTime = CACurrentMediaTime();
        deltaTime = Float(newTime - oldTime);
        timer += deltaTime
        
        timerBuffer.contents().storeBytes(of: timer, as: Float.self)
        touchBuffer.contents().storeBytes(of: pos, as: float2.self)
        rotationBuffer.contents().storeBytes(of: rot, as: float3.self)
        
        oldTime = newTime
    }
    
    /**
     * This is executed every single frame and uses the existing metal objects
     * to create the objects needed to render a single frame
     */
    override func draw(_ rect: CGRect) {
        updateTransformations()
        
        
        
        let computeCommandBuffer = commandQueue.makeCommandBuffer()
        
        // no renderpass desciptor neede - the computecommandencoder only needs a texture to work with
        let computeCommandEncoder = computeCommandBuffer.makeComputeCommandEncoder()
        computeCommandEncoder.setComputePipelineState(computePipelineState)
        computeCommandEncoder.setTexture(currentDrawable?.texture, at: 0)  // draw to the texture of the currentview
        computeCommandEncoder.setBuffer(timerBuffer, offset: 0, at: 1)
        computeCommandEncoder.setBuffer(touchBuffer, offset: 0, at: 2)
        computeCommandEncoder.setBuffer(rotationBuffer, offset: 0, at: 3)
        let threadGroupCount = MTLSizeMake(8, 8, 1)
        let threadGroups = MTLSizeMake((currentDrawable?.texture.width)! / threadGroupCount.width, (currentDrawable?.texture.height)! / threadGroupCount.height, 1)
        computeCommandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)  // Compute function is enqueued
        computeCommandEncoder.endEncoding() // translate the api commands into hardware commands and detach them from the buffer
        
        computeCommandBuffer.commit()  // commit the buffer to be executed
        
        
        
        // make command buffer that stores all the commands
        let renderCommandBuffer = commandQueue?.makeCommandBuffer()
        
        // describe what to do in the current render pass
        let renderPassDescriptor = currentRenderPassDescriptor
        renderPassDescriptor?.colorAttachments[0].texture = currentDrawable!.texture // set the input texture of the buffer to be the output texture from the buffer in the previous frame
        renderPassDescriptor?.colorAttachments[0].loadAction = .load // clear the texture ...
        renderPassDescriptor?.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1) // ... by coloring it black
        renderPassDescriptor?.colorAttachments[0].storeAction = .store
        
        renderPassDescriptor?.depthAttachment.loadAction = .clear
        renderPassDescriptor?.depthAttachment.clearDepth = 1.0
        renderPassDescriptor?.depthAttachment.storeAction = .dontCare
        
        let renderCommandEncoder = renderCommandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor!)
        renderCommandEncoder?.setDepthStencilState(depthStencilState)
        renderCommandEncoder?.setRenderPipelineState(renderPipelineState)
        renderCommandEncoder?.setFrontFacing(.counterClockwise)
        renderCommandEncoder?.setCullMode(.back)
        renderCommandEncoder?.setVertexBuffer(uniformBuffer, offset: 0, at: 1)
        renderCommandEncoder?.setFragmentTexture(texture, at: 0)
        
        // set up Metal rendering and drawing of meshes
        
        guard let mesh = meshes?.first else {
            fatalError("Mesh not found.")
        }
        let vertexBuffer = mesh.vertexBuffers[0]
        renderCommandEncoder?.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, at: 0)
        guard let submesh = mesh.submeshes.first else {
            fatalError("Submesh not found.")
        }
        renderCommandEncoder?.drawIndexedPrimitives(type: submesh.primitiveType, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: submesh.indexBuffer.offset)
        
        renderCommandEncoder?.endEncoding()  // translate the api commands into hardware commands and detach them from the buffer

        renderCommandBuffer?.present(currentDrawable!)    // set the drawable of the buffer to present onto
        renderCommandBuffer?.commit()                     // commit the buffer to be executed
    }

}
