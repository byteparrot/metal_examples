//
//  Shaders.metal
//  themetalproject
//
//  Created by Johannes Lugstein on 10/04/2017.
//  Copyright © 2017 Johannes Lugstein. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

float random (float2 uv);
float noise (float2 uv);

/**
 * This kernel function is executed for every single pixel
 * Parameters here are the output texture and the position of the current pixel
 */
kernel void compute(texture2d<float, access::write> output [[texture(0)]],
                    uint2 gid [[thread_position_in_grid]])
{
    int width = output.get_width();
    int height = output.get_height();
    
    float2 uv = float2(gid) / width; // use coords from 0-1 instead of absolute positions
    
    // move the coords to the middle of the texture instead of the upper left corner
    uv.x -= 0.5;
    uv.y -= (height+0.0) / width / 2;

    float color = 3 - (6 * length(uv));
    float2 coord = float2(atan2(uv.x,uv.y), length(uv));
    color += noise(coord * 1000);
    
    float4 pixel = float4( color, color*0.4, color*0.15 , 1.0);
    output.write(pixel, gid);

}

/*
 * https://thebookofshaders.com/10/
 */
float random (float2 uv) {
    return fract(sin(dot(uv.xy, float2(12.9898,78.233))) * 43758.5453123);
}

// https://thebookofshaders.com/10/
// 2D Noise based on Morgan McGuire @morgan3d
// https://www.shadertoy.com/view/4dS3Wd
float noise (float2 uv) {
    float2 i = floor(uv);
    float2 f = fract(uv);
    
    // Four corners in 2D of a tile
    float a = random(i);
    float b = random(i + float2(1.0, 0.0));
    float c = random(i + float2(0.0, 1.0));
    float d = random(i + float2(1.0, 1.0));
    
    // Smooth Interpolation
    
    // Cubic Hermine Curve.  Same as SmoothStep()
    float2 u = f*f*(3.0-2.0*f);
    // u = smoothstep(0.,1.,f);
    
    // Mix 4 coorners porcentages
    return mix(a, b, u.x) +
    (c - a)* u.y * (1.0 - u.x) +
    (d - b) * u.x * u.y;
}
