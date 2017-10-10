//
//  Math.swift
//  graphics
//
//  Created by Johannes Lugstein on 19/04/2017.
//  Copyright © 2017 Johannes Lugstein. All rights reserved.
//

import simd

struct Vertex {
    var position: vector_float4
    var color: vector_float4
}

struct Uniforms {
    var modelViewProjectionMatrix: matrix_float4x4
    init(_ modelViewProjectionMatrix : matrix_float4x4) {
        self.modelViewProjectionMatrix = modelViewProjectionMatrix
    }
}

func translationMatrix(_ position: float3) -> matrix_float4x4 {
    let x = vector_float4(1, 0, 0, 0)
    let y = vector_float4(0, 1, 0, 0)
    let z = vector_float4(0, 0, 1, 0)
    let w = vector_float4(position.x, position.y, position.z, 1)
    return matrix_float4x4(columns:(x, y, z, w))
}

func scalingMatrix(_ scale: Float) -> matrix_float4x4 {
    let x = vector_float4(scale, 0, 0, 0)
    let y = vector_float4(0, scale, 0, 0)
    let z = vector_float4(0, 0, scale, 0)
    let w = vector_float4(0, 0, 0, 1)
    return matrix_float4x4(columns:(x, y, z, w))
}

func scalingYMatrix(_ scale: Float) -> matrix_float4x4 {
    let x = vector_float4(1, 0, 0, 0)
    let y = vector_float4(0, scale, 0, 0)
    let z = vector_float4(0, 0, 1, 0)
    let w = vector_float4(0, 0, 0, 1)
    return matrix_float4x4(columns:(x, y, z, w))
}

func rotationMatrix(_ angle: Float, _ axis: vector_float3) -> matrix_float4x4 {
    var x = vector_float4(0, 0, 0, 0)
    x.x = axis.x * axis.x + (1 - axis.x * axis.x) * cos(angle)
    x.y = axis.x * axis.y * (1 - cos(angle)) - axis.z * sin(angle)
    x.z = axis.x * axis.z * (1 - cos(angle)) + axis.y * sin(angle)
    x.w = 0.0
    var y = vector_float4(0, 0, 0, 0)
    y.x = axis.x * axis.y * (1 - cos(angle)) + axis.z * sin(angle)
    y.y = axis.y * axis.y + (1 - axis.y * axis.y) * cos(angle)
    y.z = axis.y * axis.z * (1 - cos(angle)) - axis.x * sin(angle)
    y.w = 0.0
    var z = vector_float4(0, 0, 0, 0)
    z.x = axis.x * axis.z * (1 - cos(angle)) - axis.y * sin(angle)
    z.y = axis.y * axis.z * (1 - cos(angle)) + axis.x * sin(angle)
    z.z = axis.z * axis.z + (1 - axis.z * axis.z) * cos(angle)
    z.w = 0.0
    let w = vector_float4(0, 0, 0, 1)
    return matrix_float4x4(columns:(x, y, z, w))
}
