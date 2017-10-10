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
};

// the vertex shader handles where the vertices are drawn related to the real position
vertex Vertex vertexShader(constant Vertex *vertices [[buffer(0)]], unsigned int vid [[vertex_id]]) {
    return vertices[vid];   // draw the vertices where they are
}

fragment float4 fragmentShader() {
    return float4(0, 1, 0, 1);  // set this color to every fragment
}
