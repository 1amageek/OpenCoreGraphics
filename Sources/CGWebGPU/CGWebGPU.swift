//
//  CGWebGPU.swift
//  CGWebGPU
//
//  Bridge module that connects OpenCoreGraphics to SwiftWebGPU for GPU-accelerated rendering
//
//  Usage:
//  ```swift
//  import OpenCoreGraphics
//  import CGWebGPU
//  import SwiftWebGPU
//
//  // Create renderer
//  let renderer = try await CGWebGPURenderer.create()
//
//  // Build a path using CoreGraphics API
//  let path = CGMutablePath()
//  path.move(to: CGPoint(x: 100, y: 100))
//  path.addLine(to: CGPoint(x: 200, y: 100))
//  path.addLine(to: CGPoint(x: 150, y: 200))
//  path.closeSubpath()
//
//  // Render using WebGPU
//  renderer.fillPath(path, color: .red, to: textureView)
//  ```
//

#if !canImport(CoreGraphics)

@_exported import OpenCoreGraphics

// Re-export all public types
public typealias Renderer = CGWebGPURenderer
public typealias ContextRenderer = CGWebGPUContextRenderer
public typealias Vertex = CGWebGPUVertex
public typealias VertexBatch = CGWebGPUVertexBatch
public typealias Tessellator = PathTessellator
public typealias Shaders = CGWebGPUShaders

#endif
