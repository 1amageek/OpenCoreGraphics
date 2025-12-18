//
//  Vertex.swift
//  CGWebGPU
//
//  Bridge between OpenCoreGraphics and SwiftWebGPU
//

import Foundation

/// Vertex structure for 2D rendering with color
/// Matches the layout expected by WebGPU shaders
public struct CGWebGPUVertex: Sendable {
    /// Position in normalized device coordinates (-1 to 1)
    public var x: Float
    public var y: Float

    /// RGBA color components (0 to 1)
    public var r: Float
    public var g: Float
    public var b: Float
    public var a: Float

    public init(x: Float, y: Float, r: Float, g: Float, b: Float, a: Float) {
        self.x = x
        self.y = y
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    /// Size of vertex in bytes (for GPU buffer stride)
    public static var stride: Int {
        return MemoryLayout<CGWebGPUVertex>.stride
    }

    /// Size of vertex in bytes
    public static var size: Int {
        return MemoryLayout<CGWebGPUVertex>.size
    }
}

/// A batch of vertices ready for GPU rendering
public struct CGWebGPUVertexBatch: Sendable {
    public var vertices: [CGWebGPUVertex]

    public init(vertices: [CGWebGPUVertex] = []) {
        self.vertices = vertices
    }

    /// Total size in bytes
    public var byteSize: Int {
        return vertices.count * CGWebGPUVertex.stride
    }

    /// Get raw bytes for GPU upload
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        return try vertices.withUnsafeBytes(body)
    }

    /// Convert to flat Float array for efficient GPU transfer via JSTypedArray
    public func toFloatArray() -> [Float] {
        var floatData: [Float] = []
        floatData.reserveCapacity(vertices.count * 6)  // x, y, r, g, b, a
        for v in vertices {
            floatData.append(v.x)
            floatData.append(v.y)
            floatData.append(v.r)
            floatData.append(v.g)
            floatData.append(v.b)
            floatData.append(v.a)
        }
        return floatData
    }
}
