//
//  CGWebGPURenderer.swift
//  CGWebGPU
//
//  Main renderer that bridges OpenCoreGraphics and SwiftWebGPU
//

#if arch(wasm32)
import Foundation
import SwiftWebGPU
import JavaScriptKit

/// Renderer that draws OpenCoreGraphics content using WebGPU
public final class CGWebGPURenderer: @unchecked Sendable {

    // MARK: - Properties

    /// The WebGPU device
    public let device: GPUDevice

    /// The GPU queue for submitting commands
    public let queue: GPUQueue

    /// Render pipeline for basic 2D shapes
    private var basicPipeline: GPURenderPipeline?

    /// Tessellator for converting paths to triangles
    public var tessellator: PathTessellator

    /// Canvas context for rendering
    private var canvasContext: GPUCanvasContext?

    /// Preferred texture format
    private let textureFormat: GPUTextureFormat

    /// Viewport dimensions
    public var viewportWidth: CGFloat {
        didSet { tessellator.viewportWidth = viewportWidth }
    }
    public var viewportHeight: CGFloat {
        didSet { tessellator.viewportHeight = viewportHeight }
    }

    // MARK: - Initialization

    /// Creates a new renderer with the given WebGPU device
    public init(device: GPUDevice, textureFormat: GPUTextureFormat, viewportWidth: CGFloat = 800, viewportHeight: CGFloat = 600) {
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

    /// Initialize rendering pipelines
    public func setup() {
        // Create shader module
        let shaderModule = device.createShaderModule(descriptor: GPUShaderModuleDescriptor(
            code: CGWebGPUShaders.simple2D,
            label: "CGWebGPU Basic 2D Shader"
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
            label: "CGWebGPU Basic Pipeline"
        ))
    }

    /// Configure canvas context for rendering
    public func configureCanvas(_ context: GPUCanvasContext) {
        self.canvasContext = context
        context.configure(GPUCanvasConfiguration(
            device: device,
            format: textureFormat,
            alphaMode: .premultiplied
        ))
    }

    // MARK: - Rendering

    /// Render a CGContext's recorded operations to the canvas
    public func render(
        context: CGContext,
        clearColor: CGColor = .white
    ) {
        guard let canvasContext = canvasContext,
              let pipeline = basicPipeline else {
            return
        }

        // Get render target
        let texture = canvasContext.getCurrentTexture()
        let textureView = texture.createView()

        // Extract clear color
        let clearComponents = clearColor.components ?? [1, 1, 1, 1]
        let gpuClearColor = GPUColor(
            r: Double(clearComponents[0]),
            g: Double(clearComponents.count > 1 ? clearComponents[1] : clearComponents[0]),
            b: Double(clearComponents.count > 2 ? clearComponents[2] : clearComponents[0]),
            a: Double(clearComponents.count > 3 ? clearComponents[3] : 1)
        )

        // Create command encoder
        let encoder = device.createCommandEncoder(descriptor: GPUCommandEncoderDescriptor(
            label: "CGWebGPU Render Encoder"
        ))

        // Begin render pass
        let renderPass = encoder.beginRenderPass(descriptor: GPURenderPassDescriptor(
            colorAttachments: [
                GPURenderPassColorAttachment(
                    view: textureView,
                    clearValue: gpuClearColor,
                    loadOp: .clear,
                    storeOp: .store
                )
            ]
        ))

        renderPass.setPipeline(pipeline)

        // Get current path from context and render it
        if let path = context.path, !path.isEmpty {
            // Tessellate and render fill
            let fillColor = CGColor(red: 1, green: 0, blue: 0, alpha: 1) // TODO: get from context
            let fillBatch = tessellator.tessellateFill(path, color: fillColor)

            if !fillBatch.vertices.isEmpty {
                let buffer = createVertexBuffer(from: fillBatch)
                renderPass.setVertexBuffer(0, buffer: buffer)
                renderPass.draw(vertexCount: UInt32(fillBatch.vertices.count))
            }
        }

        renderPass.end()

        // Submit
        queue.submit([encoder.finish()])
    }

    /// Render a path with fill
    public func fillPath(
        _ path: CGPath,
        color: CGColor,
        to textureView: GPUTextureView,
        clearColor: CGColor? = nil
    ) {
        guard let pipeline = basicPipeline else { return }

        let batch = tessellator.tessellateFill(path, color: color)
        guard !batch.vertices.isEmpty else { return }

        let buffer = createVertexBuffer(from: batch)

        // Create command encoder
        let encoder = device.createCommandEncoder()

        // Render pass descriptor
        var colorAttachment = GPURenderPassColorAttachment(
            view: textureView,
            loadOp: clearColor != nil ? .clear : .load,
            storeOp: .store
        )

        if let clearColor = clearColor {
            let c = clearColor.components ?? [0, 0, 0, 1]
            colorAttachment.clearValue = GPUColor(
                r: Double(c[0]),
                g: Double(c.count > 1 ? c[1] : c[0]),
                b: Double(c.count > 2 ? c[2] : c[0]),
                a: Double(c.count > 3 ? c[3] : 1)
            )
        }

        let renderPass = encoder.beginRenderPass(descriptor: GPURenderPassDescriptor(
            colorAttachments: [colorAttachment]
        ))

        renderPass.setPipeline(pipeline)
        renderPass.setVertexBuffer(0, buffer: buffer)
        renderPass.draw(vertexCount: UInt32(batch.vertices.count))
        renderPass.end()

        queue.submit([encoder.finish()])
    }

    /// Render a path with stroke
    public func strokePath(
        _ path: CGPath,
        color: CGColor,
        lineWidth: CGFloat,
        to textureView: GPUTextureView,
        clearColor: CGColor? = nil
    ) {
        guard let pipeline = basicPipeline else { return }

        let batch = tessellator.tessellateStroke(path, color: color, lineWidth: lineWidth)
        guard !batch.vertices.isEmpty else { return }

        let buffer = createVertexBuffer(from: batch)

        let encoder = device.createCommandEncoder()

        var colorAttachment = GPURenderPassColorAttachment(
            view: textureView,
            loadOp: clearColor != nil ? .clear : .load,
            storeOp: .store
        )

        if let clearColor = clearColor {
            let c = clearColor.components ?? [0, 0, 0, 1]
            colorAttachment.clearValue = GPUColor(
                r: Double(c[0]),
                g: Double(c.count > 1 ? c[1] : c[0]),
                b: Double(c.count > 2 ? c[2] : c[0]),
                a: Double(c.count > 3 ? c[3] : 1)
            )
        }

        let renderPass = encoder.beginRenderPass(descriptor: GPURenderPassDescriptor(
            colorAttachments: [colorAttachment]
        ))

        renderPass.setPipeline(pipeline)
        renderPass.setVertexBuffer(0, buffer: buffer)
        renderPass.draw(vertexCount: UInt32(batch.vertices.count))
        renderPass.end()

        queue.submit([encoder.finish()])
    }

    /// Render a rectangle with fill
    public func fillRect(_ rect: CGRect, color: CGColor, to textureView: GPUTextureView, clearColor: CGColor? = nil) {
        let path = CGPath(rect: rect)
        fillPath(path, color: color, to: textureView, clearColor: clearColor)
    }

    /// Render an ellipse with fill
    public func fillEllipse(in rect: CGRect, color: CGColor, to textureView: GPUTextureView, clearColor: CGColor? = nil) {
        let path = CGPath(ellipseIn: rect)
        fillPath(path, color: color, to: textureView, clearColor: clearColor)
    }

    // MARK: - Buffer Management

    private func createVertexBuffer(from batch: CGWebGPUVertexBatch) -> GPUBuffer {
        let buffer = device.createBuffer(descriptor: GPUBufferDescriptor(
            size: UInt64(max(batch.byteSize, 1)),
            usage: [.vertex, .copyDst],
            label: "CGWebGPU Vertex Buffer"
        ))

        // Write vertex data to buffer using efficient JSTypedArray transfer
        writeVertexData(to: buffer, batch: batch)

        return buffer
    }

    private func writeVertexData(to buffer: GPUBuffer, batch: CGWebGPUVertexBatch) {
        guard !batch.vertices.isEmpty else { return }

        // Convert to flat Float array and use JSTypedArray for efficient bulk transfer
        let floatData = batch.toFloatArray()
        let jsTypedArray = JSTypedArray<Float32>(floatData)
        queue.writeBuffer(buffer, bufferOffset: 0, data: jsTypedArray.jsObject)
    }
}

// MARK: - Convenience Initializer

extension CGWebGPURenderer {

    /// Create a renderer from GPU singleton
    public static func create() async throws -> CGWebGPURenderer? {
        guard let gpu = GPU.shared else {
            print("WebGPU is not supported")
            return nil
        }

        guard let adapter = await gpu.requestAdapter() else {
            print("Failed to get GPU adapter")
            return nil
        }

        let device = try await adapter.requestDevice()

        let renderer = CGWebGPURenderer(
            device: device,
            textureFormat: gpu.preferredCanvasFormat
        )
        renderer.setup()

        return renderer
    }
}

#endif
