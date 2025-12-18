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
