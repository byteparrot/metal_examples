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

func rotationMatrix(_ angle: Float, _ axis: vector_float3) -> matrix_float4x4 {
    let x = vector_float4(axis.x * axis.x + (1 - axis.x * axis.x) * cos(angle),
                          axis.x * axis.y * (1 - cos(angle)) - axis.z * sin(angle),
                          axis.x * axis.z * (1 - cos(angle)) + axis.y * sin(angle), 0)
    let y = vector_float4(axis.x * axis.y * (1 - cos(angle)) + axis.z * sin(angle),
                          axis.y * axis.y + (1 - axis.y * axis.y) * cos(angle),
                          axis.y * axis.z * (1 - cos(angle)) - axis.x * sin(angle), 0)
    let z = vector_float4(axis.x * axis.z * (1 - cos(angle)) - axis.y * sin(angle),
                          axis.y * axis.z * (1 - cos(angle)) + axis.x * sin(angle),
                          axis.z * axis.z + (1 - axis.z * axis.z) * cos(angle), 0)
    let w = vector_float4(0, 0, 0, 1)
    return matrix_float4x4(columns:(x, y, z, w))
}

func projectionMatrix(near: Float, far: Float, aspect: Float, fovy: Float) -> matrix_float4x4 {
    let scaleY = 1 / tan(fovy * 0.5)
    let scaleX = scaleY / aspect
    let scaleZ = -(far + near) / (far - near)
    let scaleW = -2 * far * near / (far - near)
    let X = vector_float4(scaleX, 0, 0, 0)
    let Y = vector_float4(0, scaleY, 0, 0)
    let Z = vector_float4(0, 0, scaleZ, -1)
    let W = vector_float4(0, 0, scaleW, 0)
    return matrix_float4x4(columns:(X, Y, Z, W))
}
