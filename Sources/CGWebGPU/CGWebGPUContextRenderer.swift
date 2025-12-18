//
//  CGWebGPUContextRenderer.swift
//  CGWebGPU
//
//  WebGPU-based implementation of CGContextRendererDelegate
//

#if !canImport(CoreGraphics)
import Foundation
import OpenCoreGraphics
import SwiftWebGPU
import JavaScriptKit

/// WebGPU-based implementation of `CGContextRendererDelegate`.
///
/// This class receives drawing commands from `CGContext` and renders them using WebGPU.
/// It reads colors, line properties, and other parameters passed directly from the context.
///
/// ## Usage
///
/// ```swift
/// // Create the WebGPU renderer
/// let contextRenderer = try await CGWebGPUContextRenderer.create()
/// contextRenderer?.setup()
///
/// // Create a CGContext and connect the renderer
/// let context = CGContext(...)!
/// context.rendererDelegate = contextRenderer
///
/// // Set the render target
/// contextRenderer?.setRenderTarget(canvasTextureView)
///
/// // Draw using standard CoreGraphics API - automatically rendered via WebGPU
/// context.setFillColor(.red)
/// context.addRect(CGRect(x: 100, y: 100, width: 200, height: 150))
/// context.fillPath()
/// ```
public final class CGWebGPUContextRenderer: CGContextRendererDelegate, @unchecked Sendable {

    // MARK: - Properties

    /// The WebGPU device
    private let device: GPUDevice

    /// The GPU queue for submitting commands
    private let queue: GPUQueue

    /// Render pipeline for basic 2D shapes
    private var basicPipeline: GPURenderPipeline?

    /// Path tessellator for converting paths to triangles
    private var tessellator: PathTessellator

    /// The texture format for rendering
    private let textureFormat: GPUTextureFormat

    /// Current render target
    private weak var renderTarget: GPUTextureView?

    /// Viewport dimensions
    public var viewportWidth: CGFloat {
        didSet { tessellator.viewportWidth = viewportWidth }
    }
    public var viewportHeight: CGFloat {
        didSet { tessellator.viewportHeight = viewportHeight }
    }

    // MARK: - Initialization

    /// Creates a new context renderer with the given WebGPU device.
    ///
    /// - Parameters:
    ///   - device: The WebGPU device to use for rendering.
    ///   - textureFormat: The texture format for the render target.
    ///   - viewportWidth: Width of the viewport in pixels.
    ///   - viewportHeight: Height of the viewport in pixels.
    public init(
        device: GPUDevice,
        textureFormat: GPUTextureFormat,
        viewportWidth: CGFloat = 800,
        viewportHeight: CGFloat = 600
    ) {
        self.device = device
        self.queue = device.queue
        self.textureFormat = textureFormat
        self.viewportWidth = viewportWidth
        self.viewportHeight = viewportHeight
        self.tessellator = PathTessellator(
            flatness: 0.5,
            viewportWidth: viewportWidth,
            viewportHeight: viewportHeight
        )
    }

    // MARK: - Setup

    /// Initialize rendering pipelines. Must be called before rendering.
    public func setup() {
        // Create shader module
        let shaderModule = device.createShaderModule(descriptor: GPUShaderModuleDescriptor(
            code: CGWebGPUShaders.simple2D,
            label: "CGWebGPUContextRenderer Shader"
        ))

        // Create render pipeline
        basicPipeline = device.createRenderPipeline(descriptor: GPURenderPipelineDescriptor(
            vertex: GPUVertexState(
                module: shaderModule,
                entryPoint: "vs_main",
                buffers: [
                    GPUVertexBufferLayout(
                        arrayStride: UInt64(CGWebGPUVertex.stride),
                        attributes: [
                            GPUVertexAttribute(
                                format: .float32x2,
                                offset: 0,
                                shaderLocation: 0  // position
                            ),
                            GPUVertexAttribute(
                                format: .float32x4,
                                offset: UInt64(MemoryLayout<Float>.stride * 2),
                                shaderLocation: 1  // color
                            )
                        ]
                    )
                ]
            ),
            primitive: GPUPrimitiveState(
                topology: .triangleList,
                cullMode: .none
            ),
            fragment: GPUFragmentState(
                module: shaderModule,
                entryPoint: "fs_main",
                targets: [
                    GPUColorTargetState(
                        format: textureFormat,
                        blend: GPUBlendState(
                            color: GPUBlendComponent(
                                srcFactor: .srcAlpha,
                                dstFactor: .oneMinusSrcAlpha,
                                operation: .add
                            ),
                            alpha: GPUBlendComponent(
                                srcFactor: .one,
                                dstFactor: .oneMinusSrcAlpha,
                                operation: .add
                            )
                        )
                    )
                ]
            ),
            label: "CGWebGPUContextRenderer Pipeline"
        ))
    }

    // MARK: - Render Target

    /// Set the render target texture view.
    ///
    /// - Parameter textureView: The texture view to render to.
    public func setRenderTarget(_ textureView: GPUTextureView?) {
        self.renderTarget = textureView
    }

    // MARK: - CGContextRendererDelegate

    public func fill(
        path: CGPath,
        color: CGColor,
        alpha: CGFloat,
        blendMode: CGBlendMode,
        rule: CGPathFillRule
    ) {
        guard let target = renderTarget, let pipeline = basicPipeline else { return }

        // Apply alpha to color
        let effectiveColor = applyAlpha(color, alpha: alpha)

        // Tessellate the path
        let batch = tessellator.tessellateFill(path, color: effectiveColor)
        guard !batch.vertices.isEmpty else { return }

        // Render
        renderBatch(batch, to: target, pipeline: pipeline)
    }

    public func stroke(
        path: CGPath,
        color: CGColor,
        lineWidth: CGFloat,
        lineCap: CGLineCap,
        lineJoin: CGLineJoin,
        miterLimit: CGFloat,
        dashPhase: CGFloat,
        dashLengths: [CGFloat],
        alpha: CGFloat,
        blendMode: CGBlendMode
    ) {
        guard let target = renderTarget, let pipeline = basicPipeline else { return }

        // Apply alpha to color
        let effectiveColor = applyAlpha(color, alpha: alpha)

        // Convert line cap/join types
        let cap = convertLineCap(lineCap)
        let join = convertLineJoin(lineJoin)

        // Tessellate the stroke
        let batch = tessellator.tessellateStroke(
            path,
            color: effectiveColor,
            lineWidth: lineWidth,
            lineCap: cap,
            lineJoin: join,
            miterLimit: miterLimit
        )
        guard !batch.vertices.isEmpty else { return }

        // Render
        renderBatch(batch, to: target, pipeline: pipeline)
    }

    public func clear(rect: CGRect) {
        // TODO: Implement clear with transparent color
    }

    public func draw(
        image: CGImage,
        in rect: CGRect,
        alpha: CGFloat,
        blendMode: CGBlendMode,
        interpolationQuality: CGInterpolationQuality
    ) {
        // TODO: Implement image rendering with texture sampling
    }

    public func drawLinearGradient(
        _ gradient: CGGradient,
        start: CGPoint,
        end: CGPoint,
        options: CGGradientDrawingOptions
    ) {
        // TODO: Implement gradient rendering with specialized shader
    }

    public func drawRadialGradient(
        _ gradient: CGGradient,
        startCenter: CGPoint,
        startRadius: CGFloat,
        endCenter: CGPoint,
        endRadius: CGFloat,
        options: CGGradientDrawingOptions
    ) {
        // TODO: Implement radial gradient rendering with specialized shader
    }

    // MARK: - Shading Drawing

    public func drawShading(
        _ shading: CGShading,
        alpha: CGFloat,
        blendMode: CGBlendMode
    ) {
        guard let target = renderTarget, let pipeline = basicPipeline else { return }

        // Generate color stops from the shading function
        let colorStops = shading.generateColorStops(steps: 64)
        guard !colorStops.isEmpty else { return }

        // For now, we'll render the shading as a series of triangles
        // spanning the viewport. This is a simplified implementation.
        // A full implementation would use a specialized shader.

        var vertices: [CGWebGPUVertex] = []

        switch shading.type {
        case .axial:
            // Create a quad covering the viewport with interpolated colors
            vertices = createAxialShadingVertices(shading: shading, colorStops: colorStops, alpha: alpha)

        case .radial:
            // Create concentric ring segments for radial shading
            vertices = createRadialShadingVertices(shading: shading, colorStops: colorStops, alpha: alpha)
        }

        guard !vertices.isEmpty else { return }

        let batch = CGWebGPUVertexBatch(vertices: vertices)
        renderBatch(batch, to: target, pipeline: pipeline)
    }

    private func createAxialShadingVertices(
        shading: CGShading,
        colorStops: [(location: CGFloat, color: CGColor)],
        alpha: CGFloat
    ) -> [CGWebGPUVertex] {
        var vertices: [CGWebGPUVertex] = []

        let start = shading.startPoint
        let end = shading.endPoint

        // Calculate perpendicular direction for width
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = sqrt(dx * dx + dy * dy)
        guard length > 0 else { return [] }

        // Perpendicular vector (normalized) * large width to cover viewport
        let perpX = -dy / length * viewportWidth
        let perpY = dx / length * viewportWidth

        // Create quad strips for each color segment
        for i in 0..<(colorStops.count - 1) {
            let t0 = colorStops[i].location
            let t1 = colorStops[i + 1].location
            let color0 = applyAlpha(colorStops[i].color, alpha: alpha)
            let color1 = applyAlpha(colorStops[i + 1].color, alpha: alpha)

            // Points along the gradient axis
            let p0 = CGPoint(x: start.x + dx * t0, y: start.y + dy * t0)
            let p1 = CGPoint(x: start.x + dx * t1, y: start.y + dy * t1)

            // Four corners of the quad
            let v0 = CGPoint(x: p0.x - perpX, y: p0.y - perpY)
            let v1 = CGPoint(x: p0.x + perpX, y: p0.y + perpY)
            let v2 = CGPoint(x: p1.x + perpX, y: p1.y + perpY)
            let v3 = CGPoint(x: p1.x - perpX, y: p1.y - perpY)

            // Two triangles for the quad
            vertices.append(createVertex(v0, color: color0))
            vertices.append(createVertex(v1, color: color0))
            vertices.append(createVertex(v2, color: color1))

            vertices.append(createVertex(v0, color: color0))
            vertices.append(createVertex(v2, color: color1))
            vertices.append(createVertex(v3, color: color1))
        }

        return vertices
    }

    private func createRadialShadingVertices(
        shading: CGShading,
        colorStops: [(location: CGFloat, color: CGColor)],
        alpha: CGFloat
    ) -> [CGWebGPUVertex] {
        var vertices: [CGWebGPUVertex] = []

        let segments = 32  // Number of segments around the circle

        for i in 0..<(colorStops.count - 1) {
            let t0 = colorStops[i].location
            let t1 = colorStops[i + 1].location
            let color0 = applyAlpha(colorStops[i].color, alpha: alpha)
            let color1 = applyAlpha(colorStops[i + 1].color, alpha: alpha)

            // Interpolate centers and radii
            let center0 = CGPoint(
                x: shading.startPoint.x + (shading.endPoint.x - shading.startPoint.x) * t0,
                y: shading.startPoint.y + (shading.endPoint.y - shading.startPoint.y) * t0
            )
            let center1 = CGPoint(
                x: shading.startPoint.x + (shading.endPoint.x - shading.startPoint.x) * t1,
                y: shading.startPoint.y + (shading.endPoint.y - shading.startPoint.y) * t1
            )
            let radius0 = shading.startRadius + (shading.endRadius - shading.startRadius) * t0
            let radius1 = shading.startRadius + (shading.endRadius - shading.startRadius) * t1

            // Create ring segments
            for j in 0..<segments {
                let angle0 = CGFloat(j) * 2 * .pi / CGFloat(segments)
                let angle1 = CGFloat(j + 1) * 2 * .pi / CGFloat(segments)

                let cos0 = cos(angle0)
                let sin0 = sin(angle0)
                let cos1 = cos(angle1)
                let sin1 = sin(angle1)

                // Inner ring points
                let inner0 = CGPoint(x: center0.x + radius0 * cos0, y: center0.y + radius0 * sin0)
                let inner1 = CGPoint(x: center0.x + radius0 * cos1, y: center0.y + radius0 * sin1)

                // Outer ring points
                let outer0 = CGPoint(x: center1.x + radius1 * cos0, y: center1.y + radius1 * sin0)
                let outer1 = CGPoint(x: center1.x + radius1 * cos1, y: center1.y + radius1 * sin1)

                // Two triangles for the quad
                vertices.append(createVertex(inner0, color: color0))
                vertices.append(createVertex(inner1, color: color0))
                vertices.append(createVertex(outer1, color: color1))

                vertices.append(createVertex(inner0, color: color0))
                vertices.append(createVertex(outer1, color: color1))
                vertices.append(createVertex(outer0, color: color1))
            }
        }

        return vertices
    }

    private func createVertex(_ point: CGPoint, color: CGColor) -> CGWebGPUVertex {
        let components = color.components ?? [0, 0, 0, 1]
        let r = Float(components.count > 0 ? components[0] : 0)
        let g = Float(components.count > 1 ? components[1] : 0)
        let b = Float(components.count > 2 ? components[2] : 0)
        let a = Float(components.count > 3 ? components[3] : 1)

        // Convert to normalized device coordinates
        let ndcX = Float(point.x / viewportWidth) * 2 - 1
        let ndcY = Float(point.y / viewportHeight) * 2 - 1

        return CGWebGPUVertex(x: ndcX, y: ndcY, r: r, g: g, b: b, a: a)
    }

    // MARK: - Pattern Drawing

    public func fillWithPattern(
        path: CGPath,
        pattern: CGPattern,
        patternSpace: CGColorSpace,
        colorComponents: [CGFloat]?,
        patternPhase: CGSize,
        alpha: CGFloat,
        blendMode: CGBlendMode,
        rule: CGPathFillRule
    ) {
        guard let target = renderTarget, let pipeline = basicPipeline else { return }

        // For a simplified implementation, we'll use the pattern's base color
        // if it's an uncolored pattern, or render the pattern cell and tile it.

        // Render the pattern cell to get color information
        guard let cellImage = pattern.renderCell() else {
            // Fallback: use a default color
            let fallbackColor: CGColor
            if let components = colorComponents, !components.isEmpty {
                fallbackColor = CGColor(colorSpace: patternSpace, components: components) ?? .black
            } else {
                fallbackColor = .black
            }

            let effectiveColor = applyAlpha(fallbackColor, alpha: alpha)
            let batch = tessellator.tessellateFill(path, color: effectiveColor)
            guard !batch.vertices.isEmpty else { return }
            renderBatch(batch, to: target, pipeline: pipeline)
            return
        }

        // For now, we'll extract the average color from the pattern cell
        // A full implementation would use texture-based pattern rendering
        let patternColor = extractAverageColor(from: cellImage, pattern: pattern, colorComponents: colorComponents)
        let effectiveColor = applyAlpha(patternColor, alpha: alpha)

        let batch = tessellator.tessellateFill(path, color: effectiveColor)
        guard !batch.vertices.isEmpty else { return }
        renderBatch(batch, to: target, pipeline: pipeline)
    }

    public func strokeWithPattern(
        path: CGPath,
        pattern: CGPattern,
        patternSpace: CGColorSpace,
        colorComponents: [CGFloat]?,
        patternPhase: CGSize,
        lineWidth: CGFloat,
        lineCap: CGLineCap,
        lineJoin: CGLineJoin,
        miterLimit: CGFloat,
        dashPhase: CGFloat,
        dashLengths: [CGFloat],
        alpha: CGFloat,
        blendMode: CGBlendMode
    ) {
        guard let target = renderTarget, let pipeline = basicPipeline else { return }

        // Similar to fillWithPattern, simplified implementation
        guard let cellImage = pattern.renderCell() else {
            let fallbackColor: CGColor
            if let components = colorComponents, !components.isEmpty {
                fallbackColor = CGColor(colorSpace: patternSpace, components: components) ?? .black
            } else {
                fallbackColor = .black
            }

            let effectiveColor = applyAlpha(fallbackColor, alpha: alpha)
            let cap = convertLineCap(lineCap)
            let join = convertLineJoin(lineJoin)

            let batch = tessellator.tessellateStroke(
                path,
                color: effectiveColor,
                lineWidth: lineWidth,
                lineCap: cap,
                lineJoin: join,
                miterLimit: miterLimit
            )
            guard !batch.vertices.isEmpty else { return }
            renderBatch(batch, to: target, pipeline: pipeline)
            return
        }

        let patternColor = extractAverageColor(from: cellImage, pattern: pattern, colorComponents: colorComponents)
        let effectiveColor = applyAlpha(patternColor, alpha: alpha)

        let cap = convertLineCap(lineCap)
        let join = convertLineJoin(lineJoin)

        let batch = tessellator.tessellateStroke(
            path,
            color: effectiveColor,
            lineWidth: lineWidth,
            lineCap: cap,
            lineJoin: join,
            miterLimit: miterLimit
        )
        guard !batch.vertices.isEmpty else { return }
        renderBatch(batch, to: target, pipeline: pipeline)
    }

    private func extractAverageColor(
        from image: CGImage,
        pattern: CGPattern,
        colorComponents: [CGFloat]?
    ) -> CGColor {
        // For uncolored patterns, use the provided color components
        if !pattern.isColored, let components = colorComponents, !components.isEmpty {
            // Use alpha from pattern if available, otherwise use provided alpha
            return CGColor(
                red: components.count > 0 ? components[0] : 0,
                green: components.count > 1 ? components[1] : 0,
                blue: components.count > 2 ? components[2] : 0,
                alpha: components.count > 3 ? components[3] : 1
            )
        }

        // For colored patterns, extract average color from image
        // This is a simplified implementation - a proper one would sample the image
        guard let provider = image.dataProvider,
              let data = provider.data else {
            return .black
        }

        let width = image.width
        let height = image.height
        let bytesPerPixel = image.bitsPerPixel / 8

        guard width > 0, height > 0, bytesPerPixel >= 3 else {
            return .black
        }

        var totalR: CGFloat = 0
        var totalG: CGFloat = 0
        var totalB: CGFloat = 0
        var totalA: CGFloat = 0
        var count: CGFloat = 0

        // Sample a few pixels to get average color
        let stepX = max(1, width / 4)
        let stepY = max(1, height / 4)

        for y in stride(from: 0, to: height, by: stepY) {
            for x in stride(from: 0, to: width, by: stepX) {
                let offset = (y * image.bytesPerRow) + (x * bytesPerPixel)
                if offset + bytesPerPixel <= data.count {
                    let bytes = data.withUnsafeBytes { ptr -> [UInt8] in
                        let start = ptr.baseAddress!.advanced(by: offset)
                        return Array(UnsafeBufferPointer(start: start.assumingMemoryBound(to: UInt8.self), count: bytesPerPixel))
                    }

                    totalR += CGFloat(bytes[0]) / 255.0
                    totalG += CGFloat(bytes[1]) / 255.0
                    totalB += CGFloat(bytes[2]) / 255.0
                    if bytesPerPixel >= 4 {
                        totalA += CGFloat(bytes[3]) / 255.0
                    } else {
                        totalA += 1.0
                    }
                    count += 1
                }
            }
        }

        guard count > 0 else { return .black }

        return CGColor(
            red: totalR / count,
            green: totalG / count,
            blue: totalB / count,
            alpha: totalA / count
        )
    }

    // MARK: - Private Helpers

    private func renderBatch(_ batch: CGWebGPUVertexBatch, to textureView: GPUTextureView, pipeline: GPURenderPipeline) {
        let buffer = createVertexBuffer(from: batch)

        let encoder = device.createCommandEncoder()

        let colorAttachment = GPURenderPassColorAttachment(
            view: textureView,
            loadOp: .load,  // Don't clear, just add to existing content
            storeOp: .store
        )

        let renderPass = encoder.beginRenderPass(descriptor: GPURenderPassDescriptor(
            colorAttachments: [colorAttachment]
        ))

        renderPass.setPipeline(pipeline)
        renderPass.setVertexBuffer(0, buffer: buffer)
        renderPass.draw(vertexCount: UInt32(batch.vertices.count))
        renderPass.end()

        queue.submit([encoder.finish()])
    }

    private func createVertexBuffer(from batch: CGWebGPUVertexBatch) -> GPUBuffer {
        let buffer = device.createBuffer(descriptor: GPUBufferDescriptor(
            size: UInt64(max(batch.byteSize, 1)),
            usage: [.vertex, .copyDst],
            label: "CGWebGPUContextRenderer Vertex Buffer"
        ))

        guard !batch.vertices.isEmpty else { return buffer }

        let floatData = batch.toFloatArray()
        let jsTypedArray = JSTypedArray<Float32>(floatData)
        queue.writeBuffer(buffer, bufferOffset: 0, data: jsTypedArray.jsObject)

        return buffer
    }

    private func applyAlpha(_ color: CGColor, alpha: CGFloat) -> CGColor {
        guard alpha < 1.0 else { return color }

        let components = color.components ?? [0, 0, 0, 1]
        let colorAlpha = components.count > 3 ? components[3] : 1.0
        let newAlpha = colorAlpha * alpha

        if components.count >= 4 {
            return CGColor(
                red: components[0],
                green: components[1],
                blue: components[2],
                alpha: newAlpha
            )
        } else if components.count >= 2 {
            return CGColor(gray: components[0], alpha: newAlpha)
        } else {
            return color
        }
    }

    private func convertLineCap(_ cap: CGLineCap) -> StrokeGenerator.LineCap {
        switch cap {
        case .butt: return .butt
        case .round: return .round
        case .square: return .square
        }
    }

    private func convertLineJoin(_ join: CGLineJoin) -> StrokeGenerator.LineJoin {
        switch join {
        case .miter: return .miter
        case .round: return .round
        case .bevel: return .bevel
        }
    }
}

// MARK: - Convenience Factory

extension CGWebGPUContextRenderer {

    /// Create a context renderer from the GPU singleton.
    ///
    /// - Returns: A configured context renderer, or `nil` if WebGPU is not available.
    public static func create() async throws -> CGWebGPUContextRenderer? {
        guard let gpu = GPU.shared else {
            print("WebGPU is not supported")
            return nil
        }

        guard let adapter = try await gpu.requestAdapter() else {
            print("Failed to get GPU adapter")
            return nil
        }

        let device = try await adapter.requestDevice()

        let renderer = CGWebGPUContextRenderer(
            device: device,
            textureFormat: gpu.preferredCanvasFormat
        )
        renderer.setup()

        return renderer
    }
}

#endif
