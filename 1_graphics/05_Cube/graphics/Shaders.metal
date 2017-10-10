//
//  Shaders.metal
//  themetalproject
//
//  Created by Johannes Lugstein on 10/04/2017.
//  Copyright © 2017 Johannes Lugstein. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct Vertex {
    float4 position [[position]];
    float4 color;
};
struct Fragment {
    float4 position [[position]];
    float4 color;
};
struct Uniforms {
    float4x4 modelViewProjectionMatrix;
};

// the vertex shader handles where the vertices are drawn related to the real position
vertex Vertex vertexShader(constant Vertex *vertices [[buffer(0)]],
                           constant Uniforms &uniforms [[buffer(1)]],
                           unsigned int vid [[vertex_id]]) {
    float4x4 matrix = uniforms.modelViewProjectionMatrix;
    Vertex in = vertices[vid];
    Vertex out;
    out.position = matrix * float4(in.position);
    out.color = in.color;
    return out;   // draw the vertices where they are
}

fragment float4 fragmentShader(Fragment frag [[stage_in]]) {
    return frag.color;  // set the fragment color
}
