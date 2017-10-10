//
//  MetalView.swift
//  graphics
//
//  Created by Johannes Lugstein on 19/04/2017.
//  Copyright © 2017 Johannes Lugstein. All rights reserved.
//

import MetalKit

class MetalView: MTKView {
    required init (coder: NSCoder) {
        super.init (coder: coder)
        initMetalObjects ()
    }
    
    func initMetalObjects () {
        device = MTLCreateSystemDefaultDevice () // initialize the metal device
        if device == nil {
            fatalError ("Your system does not have a GPU with metal support!")
        }
        print ("Your system has the following GPU:\(device!.name!)")
    }
}
