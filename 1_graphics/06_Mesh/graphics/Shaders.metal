//
//  Shaders.metal
//  themetalproject
//
//  Created by Johannes Lugstein on 10/04/2017.
//  Copyright © 2017 Johannes Lugstein. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float4 position [[attribute(0)]];
    float4 color [[attribute(1)]];
    float2 texCoords [[attribute(2)]];
    float occlusion [[attribute(3)]];
};
struct ColorInOut {
    float4 position [[position]];
    float4 color;
    float2 texCoords;
    float occlusion;
};
struct Uniforms {
    float4x4 modelViewProjectionMatrix;
};

// the vertex shader handles where the vertices are drawn related to the real position
vertex ColorInOut vertexShader(const VertexIn vertices [[stage_in]],
                               constant Uniforms &uniforms [[buffer(1)]],
                               uint vertexId [[vertex_id]]) {
    float4x4 mvpMatrix = uniforms.modelViewProjectionMatrix;
    float4 position = vertices.position;
    ColorInOut out;
    out.position = mvpMatrix * position;
    out.color = float4(1);
    out.texCoords = vertices.texCoords;
    out.occlusion = vertices.occlusion;
    return out;   // draw the vertices where they are
}

fragment half4 fragmentShader(ColorInOut fragments [[stage_in]],
                               texture2d<float> textures [[texture(0)]]) {
    float4 baseColor = fragments.color;
    float4 occlusion = fragments.occlusion;
    constexpr sampler samplers;
    float4 texture = textures.sample(samplers, fragments.texCoords);
    return half4(baseColor * occlusion * texture);
}

