//
//  Shaders.metal
//  themetalproject
//
//  Created by Johannes Lugstein on 10/04/2017.
//  Copyright © 2017 Johannes Lugstein. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

/**
 * This kernel function is executed for every single pixel
 * Parameters here are the output texture and the position of the current pixel
 */
kernel void compute(texture2d<float, access::write> output [[texture(0)]],
                    uint2 gid [[thread_position_in_grid]])
{
    float4 color = float4(0,1,0,1);
    output.write(color, gid);
}
