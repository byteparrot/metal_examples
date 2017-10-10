//
// Created by Johannes Lugstein on 10/04/2017.
// Copyright (c) 2017 Johannes Lugstein. All rights reserved.
//

import MetalKit
import CoreMotion

public class MetalView : MTKView {

    var commandQueue: MTLCommandQueue!
    var computePipelineState: MTLComputePipelineState!
    
    var oldTime: CFTimeInterval!
    var deltaTime: Float!
    
    
    var timer: Float = 0
    var pos: float2!
    var rot = float3(0,0,0)
    
    var timerBuffer: MTLBuffer!
    var touchBuffer: MTLBuffer!
    var rotationBuffer: MTLBuffer!

    let motionManager = CMMotionManager()
    
    required public init(coder: NSCoder) {
        super.init(coder: coder)
        self.framebufferOnly = false    // compute kernel functions need to execute pixelbased read/write operations so by setting framebufferonly to false this is enabled
        oldTime = CACurrentMediaTime()
        pos = float2(Float(drawableSize.width/4),Float(drawableSize.height/4))
        
        initMetalObjects()
        
        
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.02;
            
            motionManager.startDeviceMotionUpdates(to: OperationQueue.current!, withHandler: {(data,error) in
                if let myData = data {
                    self.rot = float3(Float(myData.attitude.pitch),Float(myData.attitude.roll),Float(myData.attitude.yaw))
                }
            } )
        }
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
    func initMetalObjects(){
        device = MTLCreateSystemDefaultDevice() // initialize the metal device
        let library = device!.newDefaultLibrary()!  // a shader library is needed
        let kernel = library.makeFunction(name: "compute")! // the compute function from the shaderfile is added to the library
        computePipelineState = try! device!.makeComputePipelineState(function: kernel)  // A handle to for a compute function is created
        commandQueue = device?.makeCommandQueue() // make the Command Queue
        timerBuffer = device!.makeBuffer(length: MemoryLayout<Float>.size, options: []) // New buffer to store the current time since start
        touchBuffer = device!.makeBuffer(length: MemoryLayout<float2>.size, options: [])
        rotationBuffer = device!.makeBuffer(length: MemoryLayout<float3>.size, options: [])
        
    }
    
    /**
     * The update function updates the timer variable and puts it into the timerbuffer
     */
    func update() {

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
    override public func draw(_ rect: CGRect) {
        update()
        // make command buffer that stores all the commands
        let commandBuffer = commandQueue.makeCommandBuffer()
        
        // no renderpass desciptor neede - the computecommandencoder only needs a texture to work with
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()
        commandEncoder.setComputePipelineState(computePipelineState)
        commandEncoder.setTexture(currentDrawable?.texture, at: 0)  // draw to the texture of the currentview
        commandEncoder.setBuffer(timerBuffer, offset: 0, at: 1)
        commandEncoder.setBuffer(touchBuffer, offset: 0, at: 2)
        commandEncoder.setBuffer(rotationBuffer, offset: 0, at: 3)
        let threadGroupCount = MTLSizeMake(8, 8, 1)
        let threadGroups = MTLSizeMake((currentDrawable?.texture.width)! / threadGroupCount.width, (currentDrawable?.texture.height)! / threadGroupCount.height, 1)
        commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)  // Compute function is enqueued
        commandEncoder.endEncoding() // translate the api commands into hardware commands and detach them from the buffer
        
        commandBuffer.present((currentDrawable)!) // set the drawable of the buffer to present onto
        commandBuffer.commit()  // commit the buffer to be executed
    }
}
