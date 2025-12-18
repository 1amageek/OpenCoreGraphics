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

/// WebGPU-based implementation of `CGContextStatefulRendererDelegate`.
///
/// This class receives drawing commands from `CGContext` and renders them using WebGPU.
/// It reads colors, line properties, and other parameters passed directly from the context.
///
/// As a stateful renderer delegate, this class receives the full drawing state including
/// clipping paths and shadow parameters for proper rendering.
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
public final class CGWebGPUContextRenderer: CGContextStatefulRendererDelegate, @unchecked Sendable {

    // MARK: - Properties

    /// The WebGPU device
    private let device: GPUDevice

    /// The GPU queue for submitting commands
    private let queue: GPUQueue

    /// Render pipelines for different blend modes
    private var pipelines: [CGBlendMode: GPURenderPipeline] = [:]

    /// Shader module (shared by all pipelines)
    private var shaderModule: GPUShaderModule?

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
        shaderModule = device.createShaderModule(descriptor: GPUShaderModuleDescriptor(
            code: CGWebGPUShaders.simple2D,
            label: "CGWebGPUContextRenderer Shader"
        ))

        // Create pipelines for commonly used blend modes
        let supportedModes: [CGBlendMode] = [
            .normal, .copy, .sourceIn, .sourceOut, .sourceAtop,
            .destinationOver, .destinationIn, .destinationOut, .destinationAtop,
            .xor, .plusLighter, .darken, .lighten
        ]

        for mode in supportedModes {
            pipelines[mode] = createPipeline(for: mode)
        }
    }

    /// Creates a render pipeline for the specified blend mode.
    private func createPipeline(for blendMode: CGBlendMode) -> GPURenderPipeline? {
        guard let module = shaderModule else { return nil }

        let blendState = createBlendState(for: blendMode)

        return device.createRenderPipeline(descriptor: GPURenderPipelineDescriptor(
            vertex: GPUVertexState(
                module: module,
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
                module: module,
                entryPoint: "fs_main",
                targets: [
                    GPUColorTargetState(
                        format: textureFormat,
                        blend: blendState
                    )
                ]
            ),
            label: "CGWebGPU Pipeline (\(blendMode))"
        ))
    }

    /// Creates the WebGPU blend state for a CGBlendMode.
    ///
    /// Some blend modes (multiply, screen, overlay, etc.) require custom fragment shaders
    /// and are not directly supported by WebGPU blend state alone. For these modes,
    /// we fall back to normal alpha blending.
    private func createBlendState(for mode: CGBlendMode) -> GPUBlendState {
        switch mode {
        case .normal:
            // Standard alpha blending: src * srcAlpha + dst * (1 - srcAlpha)
            return GPUBlendState(
                color: GPUBlendComponent(srcFactor: .srcAlpha, dstFactor: .oneMinusSrcAlpha, operation: .add),
                alpha: GPUBlendComponent(srcFactor: .one, dstFactor: .oneMinusSrcAlpha, operation: .add)
            )

        case .copy:
            // Just copy source: src
            return GPUBlendState(
                color: GPUBlendComponent(srcFactor: .one, dstFactor: .zero, operation: .add),
                alpha: GPUBlendComponent(srcFactor: .one, dstFactor: .zero, operation: .add)
            )

        case .sourceIn:
            // src * dstAlpha
            return GPUBlendState(
                color: GPUBlendComponent(srcFactor: .dstAlpha, dstFactor: .zero, operation: .add),
                alpha: GPUBlendComponent(srcFactor: .dstAlpha, dstFactor: .zero, operation: .add)
            )

        case .sourceOut:
            // src * (1 - dstAlpha)
            return GPUBlendState(
                color: GPUBlendComponent(srcFactor: .oneMinusDstAlpha, dstFactor: .zero, operation: .add),
                alpha: GPUBlendComponent(srcFactor: .oneMinusDstAlpha, dstFactor: .zero, operation: .add)
            )

        case .sourceAtop:
            // src * dstAlpha + dst * (1 - srcAlpha)
            return GPUBlendState(
                color: GPUBlendComponent(srcFactor: .dstAlpha, dstFactor: .oneMinusSrcAlpha, operation: .add),
                alpha: GPUBlendComponent(srcFactor: .dstAlpha, dstFactor: .oneMinusSrcAlpha, operation: .add)
            )

        case .destinationOver:
            // src * (1 - dstAlpha) + dst
            return GPUBlendState(
                color: GPUBlendComponent(srcFactor: .oneMinusDstAlpha, dstFactor: .one, operation: .add),
                alpha: GPUBlendComponent(srcFactor: .oneMinusDstAlpha, dstFactor: .one, operation: .add)
            )

        case .destinationIn:
            // dst * srcAlpha
            return GPUBlendState(
                color: GPUBlendComponent(srcFactor: .zero, dstFactor: .srcAlpha, operation: .add),
                alpha: GPUBlendComponent(srcFactor: .zero, dstFactor: .srcAlpha, operation: .add)
            )

        case .destinationOut:
            // dst * (1 - srcAlpha)
            return GPUBlendState(
                color: GPUBlendComponent(srcFactor: .zero, dstFactor: .oneMinusSrcAlpha, operation: .add),
                alpha: GPUBlendComponent(srcFactor: .zero, dstFactor: .oneMinusSrcAlpha, operation: .add)
            )

        case .destinationAtop:
            // src * (1 - dstAlpha) + dst * srcAlpha
            return GPUBlendState(
                color: GPUBlendComponent(srcFactor: .oneMinusDstAlpha, dstFactor: .srcAlpha, operation: .add),
                alpha: GPUBlendComponent(srcFactor: .oneMinusDstAlpha, dstFactor: .srcAlpha, operation: .add)
            )

        case .xor:
            // src * (1 - dstAlpha) + dst * (1 - srcAlpha)
            return GPUBlendState(
                color: GPUBlendComponent(srcFactor: .oneMinusDstAlpha, dstFactor: .oneMinusSrcAlpha, operation: .add),
                alpha: GPUBlendComponent(srcFactor: .oneMinusDstAlpha, dstFactor: .oneMinusSrcAlpha, operation: .add)
            )

        case .plusLighter:
            // src + dst (additive)
            return GPUBlendState(
                color: GPUBlendComponent(srcFactor: .one, dstFactor: .one, operation: .add),
                alpha: GPUBlendComponent(srcFactor: .one, dstFactor: .one, operation: .add)
            )

        case .darken:
            // min(src, dst)
            return GPUBlendState(
                color: GPUBlendComponent(srcFactor: .one, dstFactor: .one, operation: .min),
                alpha: GPUBlendComponent(srcFactor: .one, dstFactor: .one, operation: .min)
            )

        case .lighten:
            // max(src, dst)
            return GPUBlendState(
                color: GPUBlendComponent(srcFactor: .one, dstFactor: .one, operation: .max),
                alpha: GPUBlendComponent(srcFactor: .one, dstFactor: .one, operation: .max)
            )

        // Modes that require custom shaders - fall back to normal blending
        case .multiply, .screen, .overlay, .colorDodge, .colorBurn,
             .softLight, .hardLight, .difference, .exclusion,
             .hue, .saturation, .color, .luminosity, .plusDarker, .clear:
            // These modes cannot be implemented with WebGPU blend state alone.
            // A full implementation would require custom fragment shaders.
            return GPUBlendState(
                color: GPUBlendComponent(srcFactor: .srcAlpha, dstFactor: .oneMinusSrcAlpha, operation: .add),
                alpha: GPUBlendComponent(srcFactor: .one, dstFactor: .oneMinusSrcAlpha, operation: .add)
            )

        @unknown default:
            return GPUBlendState(
                color: GPUBlendComponent(srcFactor: .srcAlpha, dstFactor: .oneMinusSrcAlpha, operation: .add),
                alpha: GPUBlendComponent(srcFactor: .one, dstFactor: .oneMinusSrcAlpha, operation: .add)
            )
        }
    }

    /// Gets or creates the pipeline for a specific blend mode.
    private func getPipeline(for blendMode: CGBlendMode) -> GPURenderPipeline? {
        if let existing = pipelines[blendMode] {
            return existing
        }

        // Create on demand for modes not pre-created
        let pipeline = createPipeline(for: blendMode)
        if let pipeline = pipeline {
            pipelines[blendMode] = pipeline
        }
        return pipeline
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
        guard let target = renderTarget,
              let pipeline = getPipeline(for: blendMode) else { return }

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
        guard let target = renderTarget,
              let pipeline = getPipeline(for: blendMode) else { return }

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
        guard let target = renderTarget,
              let pipeline = getPipeline(for: .copy) else { return }

        // Create a rectangle path for the clear area
        let clearPath = CGPath(rect: rect)

        // Use transparent color with copy blend mode to clear the area
        let transparentColor = CGColor(red: 0, green: 0, blue: 0, alpha: 0)
        let batch = tessellator.tessellateFill(clearPath, color: transparentColor)
        guard !batch.vertices.isEmpty else { return }

        renderBatch(batch, to: target, pipeline: pipeline)
    }

    /// Draws an image in the specified rectangle.
    ///
    /// - Important: Full texture-based image rendering requires additional infrastructure:
    ///   - Texture pipeline with bind groups
    ///   - Texture upload from CGImage pixel data
    ///   - Sampler configuration based on interpolationQuality
    ///
    ///   Current implementation draws a placeholder rectangle representing the image bounds.
    ///   The placeholder uses a checkerboard pattern to indicate image placement.
    ///
    /// - Parameters:
    ///   - image: The image to draw.
    ///   - rect: The destination rectangle.
    ///   - alpha: The global alpha value.
    ///   - blendMode: The blend mode for compositing.
    ///   - interpolationQuality: The interpolation quality for scaling.
    public func draw(
        image: CGImage,
        in rect: CGRect,
        alpha: CGFloat,
        blendMode: CGBlendMode,
        interpolationQuality: CGInterpolationQuality
    ) {
        guard let target = renderTarget,
              let pipeline = getPipeline(for: blendMode) else { return }

        // Create a checkerboard pattern as placeholder for image
        let vertices = createImagePlaceholderVertices(
            rect: rect,
            alpha: alpha
        )
        guard !vertices.isEmpty else { return }

        let batch = CGWebGPUVertexBatch(vertices: vertices)
        renderBatch(batch, to: target, pipeline: pipeline)
    }

    public func drawLinearGradient(
        _ gradient: CGGradient,
        start: CGPoint,
        end: CGPoint,
        options: CGGradientDrawingOptions
    ) {
        guard let target = renderTarget,
              let pipeline = getPipeline(for: .normal) else { return }

        let vertices = createLinearGradientVertices(
            gradient: gradient,
            start: start,
            end: end,
            options: options,
            alpha: 1.0
        )
        guard !vertices.isEmpty else { return }

        let batch = CGWebGPUVertexBatch(vertices: vertices)
        renderBatch(batch, to: target, pipeline: pipeline)
    }

    public func drawRadialGradient(
        _ gradient: CGGradient,
        startCenter: CGPoint,
        startRadius: CGFloat,
        endCenter: CGPoint,
        endRadius: CGFloat,
        options: CGGradientDrawingOptions
    ) {
        guard let target = renderTarget,
              let pipeline = getPipeline(for: .normal) else { return }

        let vertices = createRadialGradientVertices(
            gradient: gradient,
            startCenter: startCenter,
            startRadius: startRadius,
            endCenter: endCenter,
            endRadius: endRadius,
            options: options,
            alpha: 1.0
        )
        guard !vertices.isEmpty else { return }

        let batch = CGWebGPUVertexBatch(vertices: vertices)
        renderBatch(batch, to: target, pipeline: pipeline)
    }

    // MARK: - CGContextStatefulRendererDelegate

    public func fill(
        path: CGPath,
        color: CGColor,
        alpha: CGFloat,
        blendMode: CGBlendMode,
        rule: CGPathFillRule,
        state: CGDrawingState
    ) {
        guard let target = renderTarget,
              let pipeline = getPipeline(for: blendMode) else { return }

        // TODO: Apply clipping from state.clipPaths
        // TODO: Draw shadow if state.hasShadow

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
        blendMode: CGBlendMode,
        state: CGDrawingState
    ) {
        guard let target = renderTarget,
              let pipeline = getPipeline(for: blendMode) else { return }

        // TODO: Apply clipping from state.clipPaths
        // TODO: Draw shadow if state.hasShadow

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

    public func clear(rect: CGRect, state: CGDrawingState) {
        guard let target = renderTarget,
              let pipeline = getPipeline(for: .copy) else { return }

        // TODO: Apply clipping from state.clipPaths

        // Create a rectangle path for the clear area
        let clearPath = CGPath(rect: rect)

        // Use transparent color with copy blend mode to clear the area
        let transparentColor = CGColor(red: 0, green: 0, blue: 0, alpha: 0)
        let batch = tessellator.tessellateFill(clearPath, color: transparentColor)
        guard !batch.vertices.isEmpty else { return }

        renderBatch(batch, to: target, pipeline: pipeline)
    }

    /// Draws an image in the specified rectangle with full drawing state.
    ///
    /// See the non-state version for implementation notes about texture support.
    public func draw(
        image: CGImage,
        in rect: CGRect,
        alpha: CGFloat,
        blendMode: CGBlendMode,
        interpolationQuality: CGInterpolationQuality,
        state: CGDrawingState
    ) {
        guard let target = renderTarget,
              let pipeline = getPipeline(for: blendMode) else { return }

        // TODO: Apply clipping from state.clipPaths using stencil buffer
        // TODO: Draw shadow if state.hasShadow

        // Create a checkerboard pattern as placeholder for image
        let vertices = createImagePlaceholderVertices(
            rect: rect,
            alpha: alpha
        )
        guard !vertices.isEmpty else { return }

        let batch = CGWebGPUVertexBatch(vertices: vertices)
        renderBatch(batch, to: target, pipeline: pipeline)
    }

    public func drawLinearGradient(
        _ gradient: CGGradient,
        start: CGPoint,
        end: CGPoint,
        options: CGGradientDrawingOptions,
        state: CGDrawingState
    ) {
        guard let target = renderTarget,
              let pipeline = getPipeline(for: .normal) else { return }

        // TODO: Apply clipping from state.clipPaths using stencil buffer

        let vertices = createLinearGradientVertices(
            gradient: gradient,
            start: start,
            end: end,
            options: options,
            alpha: 1.0
        )
        guard !vertices.isEmpty else { return }

        let batch = CGWebGPUVertexBatch(vertices: vertices)
        renderBatch(batch, to: target, pipeline: pipeline)
    }

    public func drawRadialGradient(
        _ gradient: CGGradient,
        startCenter: CGPoint,
        startRadius: CGFloat,
        endCenter: CGPoint,
        endRadius: CGFloat,
        options: CGGradientDrawingOptions,
        state: CGDrawingState
    ) {
        guard let target = renderTarget,
              let pipeline = getPipeline(for: .normal) else { return }

        // TODO: Apply clipping from state.clipPaths using stencil buffer

        let vertices = createRadialGradientVertices(
            gradient: gradient,
            startCenter: startCenter,
            startRadius: startRadius,
            endCenter: endCenter,
            endRadius: endRadius,
            options: options,
            alpha: 1.0
        )
        guard !vertices.isEmpty else { return }

        let batch = CGWebGPUVertexBatch(vertices: vertices)
        renderBatch(batch, to: target, pipeline: pipeline)
    }

    // MARK: - Shading Drawing

    public func drawShading(
        _ shading: CGShading,
        alpha: CGFloat,
        blendMode: CGBlendMode
    ) {
        guard let target = renderTarget,
              let pipeline = getPipeline(for: blendMode) else { return }

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

        // Handle extendStart: extend shading before start point
        if shading.extendStart, let firstStop = colorStops.first {
            let firstColor = applyAlpha(firstStop.color, alpha: alpha)
            // Extend from a point far before start to start
            let extendStart = CGPoint(x: start.x - dx, y: start.y - dy)

            let v0 = CGPoint(x: extendStart.x - perpX, y: extendStart.y - perpY)
            let v1 = CGPoint(x: extendStart.x + perpX, y: extendStart.y + perpY)
            let v2 = CGPoint(x: start.x + perpX, y: start.y + perpY)
            let v3 = CGPoint(x: start.x - perpX, y: start.y - perpY)

            vertices.append(createVertex(v0, color: firstColor))
            vertices.append(createVertex(v1, color: firstColor))
            vertices.append(createVertex(v2, color: firstColor))
            vertices.append(createVertex(v0, color: firstColor))
            vertices.append(createVertex(v2, color: firstColor))
            vertices.append(createVertex(v3, color: firstColor))
        }

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

        // Handle extendEnd: extend shading after end point
        if shading.extendEnd, let lastStop = colorStops.last {
            let lastColor = applyAlpha(lastStop.color, alpha: alpha)
            // Extend from end to a point far after end
            let extendEnd = CGPoint(x: end.x + dx, y: end.y + dy)

            let v0 = CGPoint(x: end.x - perpX, y: end.y - perpY)
            let v1 = CGPoint(x: end.x + perpX, y: end.y + perpY)
            let v2 = CGPoint(x: extendEnd.x + perpX, y: extendEnd.y + perpY)
            let v3 = CGPoint(x: extendEnd.x - perpX, y: extendEnd.y - perpY)

            vertices.append(createVertex(v0, color: lastColor))
            vertices.append(createVertex(v1, color: lastColor))
            vertices.append(createVertex(v2, color: lastColor))
            vertices.append(createVertex(v0, color: lastColor))
            vertices.append(createVertex(v2, color: lastColor))
            vertices.append(createVertex(v3, color: lastColor))
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
        let startCenter = shading.startPoint
        let endCenter = shading.endPoint
        let startRadius = shading.startRadius
        let endRadius = shading.endRadius

        // Handle extendStart: fill the center circle with the first color
        if shading.extendStart, let firstStop = colorStops.first, startRadius > 0 {
            let firstColor = applyAlpha(firstStop.color, alpha: alpha)

            // Fill center circle with first color
            for j in 0..<segments {
                let angle0 = CGFloat(j) * 2 * .pi / CGFloat(segments)
                let angle1 = CGFloat(j + 1) * 2 * .pi / CGFloat(segments)

                let p0 = startCenter
                let p1 = CGPoint(x: startCenter.x + startRadius * cos(angle0),
                                y: startCenter.y + startRadius * sin(angle0))
                let p2 = CGPoint(x: startCenter.x + startRadius * cos(angle1),
                                y: startCenter.y + startRadius * sin(angle1))

                vertices.append(createVertex(p0, color: firstColor))
                vertices.append(createVertex(p1, color: firstColor))
                vertices.append(createVertex(p2, color: firstColor))
            }
        }

        // Create ring segments for each color stop pair
        for i in 0..<(colorStops.count - 1) {
            let t0 = colorStops[i].location
            let t1 = colorStops[i + 1].location
            let color0 = applyAlpha(colorStops[i].color, alpha: alpha)
            let color1 = applyAlpha(colorStops[i + 1].color, alpha: alpha)

            // Interpolate centers and radii
            let center0 = CGPoint(
                x: startCenter.x + (endCenter.x - startCenter.x) * t0,
                y: startCenter.y + (endCenter.y - startCenter.y) * t0
            )
            let center1 = CGPoint(
                x: startCenter.x + (endCenter.x - startCenter.x) * t1,
                y: startCenter.y + (endCenter.y - startCenter.y) * t1
            )
            let radius0 = startRadius + (endRadius - startRadius) * t0
            let radius1 = startRadius + (endRadius - startRadius) * t1

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

        // Handle extendEnd: extend beyond the end radius
        if shading.extendEnd, let lastStop = colorStops.last {
            let lastColor = applyAlpha(lastStop.color, alpha: alpha)
            let extendRadius = endRadius + max(viewportWidth, viewportHeight)

            // Extend from end radius to a much larger radius
            for j in 0..<segments {
                let angle0 = CGFloat(j) * 2 * .pi / CGFloat(segments)
                let angle1 = CGFloat(j + 1) * 2 * .pi / CGFloat(segments)

                let cos0 = cos(angle0)
                let sin0 = sin(angle0)
                let cos1 = cos(angle1)
                let sin1 = sin(angle1)

                let inner0 = CGPoint(x: endCenter.x + endRadius * cos0, y: endCenter.y + endRadius * sin0)
                let inner1 = CGPoint(x: endCenter.x + endRadius * cos1, y: endCenter.y + endRadius * sin1)
                let outer0 = CGPoint(x: endCenter.x + extendRadius * cos0, y: endCenter.y + extendRadius * sin0)
                let outer1 = CGPoint(x: endCenter.x + extendRadius * cos1, y: endCenter.y + extendRadius * sin1)

                vertices.append(createVertex(inner0, color: lastColor))
                vertices.append(createVertex(inner1, color: lastColor))
                vertices.append(createVertex(outer1, color: lastColor))

                vertices.append(createVertex(inner0, color: lastColor))
                vertices.append(createVertex(outer1, color: lastColor))
                vertices.append(createVertex(outer0, color: lastColor))
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

    // MARK: - Gradient Vertex Creation

    private func createLinearGradientVertices(
        gradient: CGGradient,
        start: CGPoint,
        end: CGPoint,
        options: CGGradientDrawingOptions,
        alpha: CGFloat
    ) -> [CGWebGPUVertex] {
        var vertices: [CGWebGPUVertex] = []

        // Get color stops from gradient
        guard let colors = gradient.colors,
              let locations = gradient.locations,
              colors.count > 0 else { return [] }

        // Calculate gradient direction
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = sqrt(dx * dx + dy * dy)
        guard length > 0 else { return [] }

        // Perpendicular vector (normalized) * large width to cover viewport
        let perpX = -dy / length * viewportWidth
        let perpY = dx / length * viewportWidth

        // Handle drawsBeforeStartLocation option
        if options.contains(.drawsBeforeStartLocation), colors.count > 0 {
            let firstColor = applyAlpha(colors[0], alpha: alpha)
            // Extend from a point far before start to start
            let extendStart = CGPoint(x: start.x - dx, y: start.y - dy)

            let v0 = CGPoint(x: extendStart.x - perpX, y: extendStart.y - perpY)
            let v1 = CGPoint(x: extendStart.x + perpX, y: extendStart.y + perpY)
            let v2 = CGPoint(x: start.x + perpX, y: start.y + perpY)
            let v3 = CGPoint(x: start.x - perpX, y: start.y - perpY)

            vertices.append(createVertex(v0, color: firstColor))
            vertices.append(createVertex(v1, color: firstColor))
            vertices.append(createVertex(v2, color: firstColor))
            vertices.append(createVertex(v0, color: firstColor))
            vertices.append(createVertex(v2, color: firstColor))
            vertices.append(createVertex(v3, color: firstColor))
        }

        // Create segments for each color stop pair
        for i in 0..<(colors.count - 1) {
            let t0 = locations[i]
            let t1 = locations[i + 1]
            let color0 = applyAlpha(colors[i], alpha: alpha)
            let color1 = applyAlpha(colors[i + 1], alpha: alpha)

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

        // Handle drawsAfterEndLocation option
        if options.contains(.drawsAfterEndLocation), colors.count > 0 {
            let lastColor = applyAlpha(colors[colors.count - 1], alpha: alpha)
            // Extend from end to a point far after end
            let extendEnd = CGPoint(x: end.x + dx, y: end.y + dy)

            let v0 = CGPoint(x: end.x - perpX, y: end.y - perpY)
            let v1 = CGPoint(x: end.x + perpX, y: end.y + perpY)
            let v2 = CGPoint(x: extendEnd.x + perpX, y: extendEnd.y + perpY)
            let v3 = CGPoint(x: extendEnd.x - perpX, y: extendEnd.y - perpY)

            vertices.append(createVertex(v0, color: lastColor))
            vertices.append(createVertex(v1, color: lastColor))
            vertices.append(createVertex(v2, color: lastColor))
            vertices.append(createVertex(v0, color: lastColor))
            vertices.append(createVertex(v2, color: lastColor))
            vertices.append(createVertex(v3, color: lastColor))
        }

        return vertices
    }

    private func createRadialGradientVertices(
        gradient: CGGradient,
        startCenter: CGPoint,
        startRadius: CGFloat,
        endCenter: CGPoint,
        endRadius: CGFloat,
        options: CGGradientDrawingOptions,
        alpha: CGFloat
    ) -> [CGWebGPUVertex] {
        var vertices: [CGWebGPUVertex] = []

        // Get color stops from gradient
        guard let colors = gradient.colors,
              let locations = gradient.locations,
              colors.count > 0 else { return [] }

        let segments = 32  // Number of segments around the circle

        // Handle drawsBeforeStartLocation option
        if options.contains(.drawsBeforeStartLocation), startRadius > 0 {
            let firstColor = applyAlpha(colors[0], alpha: alpha)

            // Fill center circle with first color
            for j in 0..<segments {
                let angle0 = CGFloat(j) * 2 * .pi / CGFloat(segments)
                let angle1 = CGFloat(j + 1) * 2 * .pi / CGFloat(segments)

                let p0 = startCenter
                let p1 = CGPoint(x: startCenter.x + startRadius * cos(angle0),
                                y: startCenter.y + startRadius * sin(angle0))
                let p2 = CGPoint(x: startCenter.x + startRadius * cos(angle1),
                                y: startCenter.y + startRadius * sin(angle1))

                vertices.append(createVertex(p0, color: firstColor))
                vertices.append(createVertex(p1, color: firstColor))
                vertices.append(createVertex(p2, color: firstColor))
            }
        }

        // Create ring segments for each color stop pair
        for i in 0..<(colors.count - 1) {
            let t0 = locations[i]
            let t1 = locations[i + 1]
            let color0 = applyAlpha(colors[i], alpha: alpha)
            let color1 = applyAlpha(colors[i + 1], alpha: alpha)

            // Interpolate centers and radii
            let center0 = CGPoint(
                x: startCenter.x + (endCenter.x - startCenter.x) * t0,
                y: startCenter.y + (endCenter.y - startCenter.y) * t0
            )
            let center1 = CGPoint(
                x: startCenter.x + (endCenter.x - startCenter.x) * t1,
                y: startCenter.y + (endCenter.y - startCenter.y) * t1
            )
            let radius0 = startRadius + (endRadius - startRadius) * t0
            let radius1 = startRadius + (endRadius - startRadius) * t1

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

        // Handle drawsAfterEndLocation option
        if options.contains(.drawsAfterEndLocation) {
            let lastColor = applyAlpha(colors[colors.count - 1], alpha: alpha)
            let extendRadius = endRadius + max(viewportWidth, viewportHeight)

            // Extend from end radius to a much larger radius
            for j in 0..<segments {
                let angle0 = CGFloat(j) * 2 * .pi / CGFloat(segments)
                let angle1 = CGFloat(j + 1) * 2 * .pi / CGFloat(segments)

                let cos0 = cos(angle0)
                let sin0 = sin(angle0)
                let cos1 = cos(angle1)
                let sin1 = sin(angle1)

                let inner0 = CGPoint(x: endCenter.x + endRadius * cos0, y: endCenter.y + endRadius * sin0)
                let inner1 = CGPoint(x: endCenter.x + endRadius * cos1, y: endCenter.y + endRadius * sin1)
                let outer0 = CGPoint(x: endCenter.x + extendRadius * cos0, y: endCenter.y + extendRadius * sin0)
                let outer1 = CGPoint(x: endCenter.x + extendRadius * cos1, y: endCenter.y + extendRadius * sin1)

                vertices.append(createVertex(inner0, color: lastColor))
                vertices.append(createVertex(inner1, color: lastColor))
                vertices.append(createVertex(outer1, color: lastColor))

                vertices.append(createVertex(inner0, color: lastColor))
                vertices.append(createVertex(outer1, color: lastColor))
                vertices.append(createVertex(outer0, color: lastColor))
            }
        }

        return vertices
    }

    // MARK: - Pattern Drawing

    /// Fills a path with a pattern.
    ///
    /// - Important: This is a simplified implementation. Currently, pattern rendering
    ///   is limited because `CGPattern.renderCell()` creates a CGContext without a
    ///   rendererDelegate, so drawing operations in the pattern callback don't produce
    ///   output. As a result:
    ///   - For uncolored patterns: Uses the provided colorComponents as a solid fill
    ///   - For colored patterns: Falls back to a default gray color
    ///
    ///   A full implementation would require either:
    ///   1. A software rasterizer in CGContext
    ///   2. GPU-based pattern tiling using the pattern's bounds, xStep, yStep properties
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
        guard let target = renderTarget,
              let pipeline = getPipeline(for: blendMode) else { return }

        // Determine the fill color based on pattern type
        let patternColor: CGColor

        if !pattern.isColored {
            // Uncolored pattern: use provided color components
            if let components = colorComponents, !components.isEmpty {
                patternColor = CGColor(
                    red: components.count > 0 ? components[0] : 0,
                    green: components.count > 1 ? components[1] : 0,
                    blue: components.count > 2 ? components[2] : 0,
                    alpha: components.count > 3 ? components[3] : 1
                )
            } else {
                patternColor = .black
            }
        } else {
            // Colored pattern: since renderCell() doesn't work properly,
            // we fall back to a placeholder color
            // TODO: Implement proper GPU-based pattern tiling
            patternColor = CGColor(gray: 0.5, alpha: 1.0)
        }

        let effectiveColor = applyAlpha(patternColor, alpha: alpha)
        let batch = tessellator.tessellateFill(path, color: effectiveColor)
        guard !batch.vertices.isEmpty else { return }
        renderBatch(batch, to: target, pipeline: pipeline)
    }

    /// Strokes a path with a pattern.
    ///
    /// - Important: This has the same limitations as `fillWithPattern`.
    ///   See that method's documentation for details.
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
        guard let target = renderTarget,
              let pipeline = getPipeline(for: blendMode) else { return }

        // Determine the stroke color based on pattern type
        let patternColor: CGColor

        if !pattern.isColored {
            // Uncolored pattern: use provided color components
            if let components = colorComponents, !components.isEmpty {
                patternColor = CGColor(
                    red: components.count > 0 ? components[0] : 0,
                    green: components.count > 1 ? components[1] : 0,
                    blue: components.count > 2 ? components[2] : 0,
                    alpha: components.count > 3 ? components[3] : 1
                )
            } else {
                patternColor = .black
            }
        } else {
            // Colored pattern: placeholder color
            // TODO: Implement proper GPU-based pattern tiling
            patternColor = CGColor(gray: 0.5, alpha: 1.0)
        }

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

    // MARK: - Image Placeholder

    /// Creates a checkerboard pattern as a placeholder for image rendering.
    ///
    /// This provides visual feedback that an image would be drawn at this location.
    /// Full texture-based rendering requires additional infrastructure.
    private func createImagePlaceholderVertices(
        rect: CGRect,
        alpha: CGFloat
    ) -> [CGWebGPUVertex] {
        var vertices: [CGWebGPUVertex] = []

        // Checkerboard colors
        let lightColor = applyAlpha(CGColor(gray: 0.8, alpha: 1.0), alpha: alpha)
        let darkColor = applyAlpha(CGColor(gray: 0.6, alpha: 1.0), alpha: alpha)

        // Create a checkerboard pattern with 4x4 cells
        let cellWidth = rect.width / 4
        let cellHeight = rect.height / 4

        for row in 0..<4 {
            for col in 0..<4 {
                let isLight = (row + col) % 2 == 0
                let color = isLight ? lightColor : darkColor

                let x = rect.minX + CGFloat(col) * cellWidth
                let y = rect.minY + CGFloat(row) * cellHeight

                // Four corners of the cell
                let v0 = CGPoint(x: x, y: y)
                let v1 = CGPoint(x: x + cellWidth, y: y)
                let v2 = CGPoint(x: x + cellWidth, y: y + cellHeight)
                let v3 = CGPoint(x: x, y: y + cellHeight)

                // Two triangles for the cell
                vertices.append(createVertex(v0, color: color))
                vertices.append(createVertex(v1, color: color))
                vertices.append(createVertex(v2, color: color))

                vertices.append(createVertex(v0, color: color))
                vertices.append(createVertex(v2, color: color))
                vertices.append(createVertex(v3, color: color))
            }
        }

        return vertices
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
