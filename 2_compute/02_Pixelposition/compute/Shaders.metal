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
    int width = output.get_width();
    int height = output.get_height();
    float red = float(gid.x) / float(width);
    float blue = float(gid.y) / float(height);
    float4 color = float4(red,0.5,blue,1);
    output.write(color, gid);
}
