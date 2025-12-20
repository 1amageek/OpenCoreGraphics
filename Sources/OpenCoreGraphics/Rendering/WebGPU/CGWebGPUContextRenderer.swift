//
//  CGWebGPUContextRenderer.swift
//  CGWebGPU
//
//  WebGPU-based implementation of CGContextRendererDelegate
//

#if arch(wasm32)
import Foundation
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
/// This renderer is configured automatically by CGContext on WASM architecture.
/// Users interact with the standard CoreGraphics API without needing to configure
/// the renderer directly.
///
/// ## Usage
///
/// ```swift
/// // On WASM, CGContext automatically uses WebGPU for rendering
/// let context = CGContext(...)!
///
/// // Draw using standard CoreGraphics API
/// context.setFillColor(.red)
/// context.addRect(CGRect(x: 100, y: 100, width: 200, height: 150))
/// context.fillPath()
/// ```
internal final class CGWebGPUContextRenderer: CGContextStatefulRendererDelegate, @unchecked Sendable {

    // MARK: - Properties

    /// The WebGPU device
    private let device: GPUDevice

    /// The GPU queue for submitting commands
    private let queue: GPUQueue

    /// The texture format for rendering
    private let textureFormat: GPUTextureFormat

    /// The depth/stencil texture format
    private let depthStencilFormat: GPUTextureFormat = .depth24plusStencil8

    /// Current render target
    private weak var renderTarget: GPUTextureView?

    /// Path tessellator for converting paths to triangles
    private var tessellator: PathTessellator

    // MARK: - Internal Components (per ARCHITECTURE.md)

    /// Pipeline registry for caching and managing render pipelines
    private var pipelineRegistry: PipelineRegistry

    /// Texture manager for CGImage texture caching
    private var textureManager: TextureManager

    /// Buffer pool for efficient vertex buffer allocation
    private var bufferPool: BufferPool

    /// Geometry cache for tessellation result caching
    private var geometryCache: GeometryCache

    /// Sampler for texture operations
    private var linearSampler: GPUSampler?

    // MARK: - Offscreen Textures

    /// Stencil texture for clipping
    private var stencilTexture: GPUTexture?
    private var stencilTextureView: GPUTextureView?

    /// Offscreen texture for shadow mask
    private var shadowMaskTexture: GPUTexture?
    private var shadowMaskTextureView: GPUTextureView?

    /// Intermediate texture for blur passes
    private var blurIntermediateTexture: GPUTexture?
    private var blurIntermediateTextureView: GPUTextureView?

    // MARK: - Internal Render Target (for makeImage support)

    /// Internal render texture with CopySrc usage for GPU readback
    private var internalRenderTexture: GPUTexture?
    private var internalRenderTextureView: GPUTextureView?

    /// Blit pipeline for copying internal texture to external target
    private var blitPipeline: GPURenderPipeline?

    // MARK: - MSAA (Multi-Sample Anti-Aliasing) Textures

    /// MSAA render texture (multisampled)
    private var msaaRenderTexture: GPUTexture?
    private var msaaRenderTextureView: GPUTextureView?

    /// MSAA stencil texture (multisampled)
    private var msaaStencilTexture: GPUTexture?
    private var msaaStencilTextureView: GPUTextureView?

    /// Sample count for MSAA. 1 = no MSAA, 4 = 4x MSAA.
    private let msaaSampleCount: Int = 4

    /// Viewport dimensions
    var viewportWidth: CGFloat {
        didSet {
            tessellator.viewportWidth = viewportWidth
            recreateOffscreenTexturesIfNeeded()
        }
    }
    var viewportHeight: CGFloat {
        didSet {
            tessellator.viewportHeight = viewportHeight
            recreateOffscreenTexturesIfNeeded()
        }
    }

    // MARK: - Initialization

    /// Creates a new context renderer using the globally initialized WebGPU device.
    ///
    /// **Important**: `setupGraphicsContext()` must be called before creating any CGContext.
    /// This initializes WebGPU and stores the device globally.
    ///
    /// - Parameters:
    ///   - width: Width of the viewport in pixels.
    ///   - height: Height of the viewport in pixels.
    init(width: Int, height: Int) {
        // Get device from JavaScript global (set by setupGraphicsContext())
        let deviceJS = JSObject.global.__cgDevice
        guard !deviceJS.isUndefined && !deviceJS.isNull else {
            fatalError("WebGPU not initialized. Call setupGraphicsContext() before using CGContext.")
        }

        let device = GPUDevice(from: deviceJS.object!)
        self.device = device
        self.queue = device.queue
        self.textureFormat = .bgra8unorm
        self.viewportWidth = CGFloat(width)
        self.viewportHeight = CGFloat(height)

        // Initialize components
        self.tessellator = PathTessellator(
            flatness: 0.5,
            viewportWidth: CGFloat(width),
            viewportHeight: CGFloat(height)
        )
        self.pipelineRegistry = PipelineRegistry(device: device, textureFormat: textureFormat)
        self.textureManager = TextureManager(device: device)
        self.bufferPool = BufferPool(device: device)
        self.geometryCache = GeometryCache()
    }

    /// Creates a new context renderer with the given WebGPU device.
    ///
    /// - Parameters:
    ///   - device: The WebGPU device to use for rendering.
    ///   - textureFormat: The texture format for the render target.
    ///   - viewportWidth: Width of the viewport in pixels.
    ///   - viewportHeight: Height of the viewport in pixels.
    init(
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

        // Initialize components
        self.tessellator = PathTessellator(
            flatness: 0.5,
            viewportWidth: viewportWidth,
            viewportHeight: viewportHeight
        )
        self.pipelineRegistry = PipelineRegistry(device: device, textureFormat: textureFormat)
        self.textureManager = TextureManager(device: device)
        self.bufferPool = BufferPool(device: device)
        self.geometryCache = GeometryCache()
    }

    // MARK: - Setup

    /// Initialize rendering pipelines. Must be called before rendering.
    func setup() {
        // Warm up the pipeline registry (pre-creates commonly used pipelines)
        pipelineRegistry.warmUp()

        // Create linear sampler for texture sampling
        linearSampler = device.createSampler(descriptor: GPUSamplerDescriptor(
            addressModeU: .clampToEdge,
            addressModeV: .clampToEdge,
            magFilter: .linear,
            minFilter: .linear,
            label: "CGWebGPU Linear Sampler"
        ))

        // Create initial offscreen textures
        recreateOffscreenTexturesIfNeeded()
    }

    /// Recreates offscreen textures when viewport size changes.
    private func recreateOffscreenTexturesIfNeeded() {
        let width = UInt32(max(1, viewportWidth))
        let height = UInt32(max(1, viewportHeight))

        // Check if current texture matches the viewport size
        if let existing = stencilTexture,
           existing.width == width && existing.height == height {
            return
        }

        // Create internal render texture with CopySrc for readback support
        internalRenderTexture = device.createTexture(descriptor: GPUTextureDescriptor(
            size: GPUExtent3D(width: width, height: height),
            format: textureFormat,
            usage: [.renderAttachment, .copySrc, .textureBinding],
            label: "CGWebGPU Internal Render Texture"
        ))
        internalRenderTextureView = internalRenderTexture?.createView()

        // Create new stencil texture
        stencilTexture = device.createTexture(descriptor: GPUTextureDescriptor(
            size: GPUExtent3D(width: width, height: height),
            format: depthStencilFormat,
            usage: [.renderAttachment],
            label: "CGWebGPU Stencil Texture"
        ))
        stencilTextureView = stencilTexture?.createView()

        // Create shadow mask texture
        shadowMaskTexture = device.createTexture(descriptor: GPUTextureDescriptor(
            size: GPUExtent3D(width: width, height: height),
            format: textureFormat,
            usage: [.renderAttachment, .textureBinding],
            label: "CGWebGPU Shadow Mask Texture"
        ))
        shadowMaskTextureView = shadowMaskTexture?.createView()

        // Create blur intermediate texture
        blurIntermediateTexture = device.createTexture(descriptor: GPUTextureDescriptor(
            size: GPUExtent3D(width: width, height: height),
            format: textureFormat,
            usage: [.renderAttachment, .textureBinding],
            label: "CGWebGPU Blur Intermediate Texture"
        ))
        blurIntermediateTextureView = blurIntermediateTexture?.createView()

        // Create MSAA render texture (multisampled)
        msaaRenderTexture = device.createTexture(descriptor: GPUTextureDescriptor(
            size: GPUExtent3D(width: width, height: height),
            format: textureFormat,
            usage: [.renderAttachment],
            sampleCount: UInt32(msaaSampleCount),
            label: "CGWebGPU MSAA Render Texture"
        ))
        msaaRenderTextureView = msaaRenderTexture?.createView()

        // Create MSAA stencil texture (multisampled)
        msaaStencilTexture = device.createTexture(descriptor: GPUTextureDescriptor(
            size: GPUExtent3D(width: width, height: height),
            format: depthStencilFormat,
            usage: [.renderAttachment],
            sampleCount: UInt32(msaaSampleCount),
            label: "CGWebGPU MSAA Stencil Texture"
        ))
        msaaStencilTextureView = msaaStencilTexture?.createView()
    }

    // MARK: - Pipeline Access (via PipelineRegistry)

    /// Gets the pipeline for a specific blend mode.
    private func getPipeline(for blendMode: CGBlendMode) -> GPURenderPipeline? {
        return pipelineRegistry.getPipeline(for: blendMode)
    }

    /// Gets the clipped pipeline for a specific blend mode.
    private func getClippedPipeline(for blendMode: CGBlendMode) -> GPURenderPipeline? {
        return pipelineRegistry.getClippedPipeline(for: blendMode)
    }

    /// Gets the stencil write pipeline.
    private func getStencilWritePipeline() -> GPURenderPipeline? {
        return pipelineRegistry.getPipeline(.stencilWrite)
    }

    /// Gets the image pipeline.
    private func getImagePipeline() -> GPURenderPipeline? {
        return pipelineRegistry.getPipeline(.image)
    }

    /// Gets the pattern pipeline.
    private func getPatternPipeline() -> GPURenderPipeline? {
        return pipelineRegistry.getPipeline(.pattern)
    }

    /// Gets the blur horizontal pipeline.
    private func getBlurHorizontalPipeline() -> GPURenderPipeline? {
        return pipelineRegistry.getPipeline(.blurHorizontal)
    }

    /// Gets the blur vertical pipeline.
    private func getBlurVerticalPipeline() -> GPURenderPipeline? {
        return pipelineRegistry.getPipeline(.blurVertical)
    }

    /// Gets the shadow composite pipeline.
    private func getShadowCompositePipeline() -> GPURenderPipeline? {
        return pipelineRegistry.getPipeline(.shadowComposite)
    }

    // MARK: - Render Target

    /// Set the render target texture view.
    ///
    /// When set, rendering goes directly to the external target (e.g., canvas).
    /// When `nil`, rendering uses an internal texture that supports GPU readback
    /// via `makeImageAsync()`.
    ///
    /// - Parameter textureView: The texture view to render to, or `nil` for internal rendering.
    func setRenderTarget(_ textureView: GPUTextureView?) {
        self.renderTarget = textureView
    }

    /// Gets the effective render target.
    ///
    /// If an external render target is set, returns it.
    /// Otherwise, returns the internal texture (for GPU readback support).
    private var effectiveRenderTarget: GPUTextureView? {
        // If external target is set, use it
        if let target = renderTarget {
            return target
        }

        // Otherwise, fallback to internal texture
        if internalRenderTextureView == nil {
            recreateOffscreenTexturesIfNeeded()
        }
        return internalRenderTextureView
    }

    // MARK: - Frame Management

    /// Begins a new frame.
    ///
    /// Call this at the start of each frame to reset internal buffers.
    /// This advances the BufferPool's ring buffer to prevent GPU/CPU conflicts.
    func beginFrame() {
        bufferPool.advanceFrame()
    }

    // MARK: - CGContextRendererDelegate

    func fill(
        path: CGPath,
        color: CGColor,
        alpha: CGFloat,
        blendMode: CGBlendMode,
        rule: CGPathFillRule
    ) {
        guard let target = effectiveRenderTarget,
              let pipeline = getPipeline(for: blendMode) else { return }

        // Apply alpha to color
        let effectiveColor = applyAlpha(color, alpha: alpha)

        // Tessellate the path
        // Note: GeometryCache is available for future optimization of static paths
        let batch = tessellator.tessellateFill(path, color: effectiveColor)
        guard !batch.vertices.isEmpty else { return }

        // Render
        renderBatch(batch, to: target, pipeline: pipeline)
    }

    func stroke(
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
        guard let target = effectiveRenderTarget,
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

    func clear(rect: CGRect) {
        guard let target = effectiveRenderTarget,
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
    func draw(
        image: CGImage,
        in rect: CGRect,
        alpha: CGFloat,
        blendMode: CGBlendMode,
        interpolationQuality: CGInterpolationQuality
    ) {
        guard let target = effectiveRenderTarget,
              let pipeline = getImagePipeline(),
              let sampler = linearSampler else { return }

        // Get or create texture view for the image (via TextureManager)
        guard let textureView = getOrCreateTextureView(for: image) else {
            // Fall back to placeholder if texture creation fails
            guard let fallbackPipeline = getPipeline(for: blendMode) else { return }
            let vertices = createImagePlaceholderVertices(rect: rect, alpha: alpha)
            guard !vertices.isEmpty else { return }
            let batch = CGWebGPUVertexBatch(vertices: vertices)
            renderBatch(batch, to: target, pipeline: fallbackPipeline)
            return
        }

        // Create quad vertices with texture coordinates
        let vertices = createImageQuadVertices(rect: rect)
        let vertexBuffer = createImageVertexBuffer(from: vertices)

        // Create uniform buffer for alpha
        let uniformBuffer = createImageUniformBuffer(alpha: alpha)

        // Create bind group
        let bindGroup = device.createBindGroup(descriptor: GPUBindGroupDescriptor(
            layout: pipeline.getBindGroupLayout(index: 0),
            entries: [
                GPUBindGroupEntry(binding: 0, resource: .sampler(sampler)),
                GPUBindGroupEntry(binding: 1, resource: .textureView(textureView)),
                GPUBindGroupEntry(binding: 2, resource: .bufferBinding(GPUBufferBinding(buffer: uniformBuffer)))
            ]
        ))

        // Render
        let encoder = device.createCommandEncoder()
        let colorAttachment = GPURenderPassColorAttachment(
            view: target,
            loadOp: .load,
            storeOp: .store
        )

        let renderPass = encoder.beginRenderPass(descriptor: GPURenderPassDescriptor(
            colorAttachments: [colorAttachment]
        ))

        renderPass.setPipeline(pipeline)
        renderPass.setBindGroup(0, bindGroup: bindGroup)
        renderPass.setVertexBuffer(0, buffer: vertexBuffer)
        renderPass.draw(vertexCount: 6)
        renderPass.end()

        queue.submit([encoder.finish()])
    }

    func drawLinearGradient(
        _ gradient: CGGradient,
        start: CGPoint,
        end: CGPoint,
        options: CGGradientDrawingOptions
    ) {
        guard let target = effectiveRenderTarget,
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

    func drawRadialGradient(
        _ gradient: CGGradient,
        startCenter: CGPoint,
        startRadius: CGFloat,
        endCenter: CGPoint,
        endRadius: CGFloat,
        options: CGGradientDrawingOptions
    ) {
        guard let target = effectiveRenderTarget,
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

    func fill(
        path: CGPath,
        color: CGColor,
        alpha: CGFloat,
        blendMode: CGBlendMode,
        rule: CGPathFillRule,
        state: CGDrawingState
    ) {
        guard let target = effectiveRenderTarget else { return }

        // Apply alpha to color
        let effectiveColor = applyAlpha(color, alpha: alpha)

        // Tessellate the path
        let batch = tessellator.tessellateFill(path, color: effectiveColor)
        guard !batch.vertices.isEmpty else { return }

        // Render shadow first if needed
        if state.hasShadow, let shadowColor = state.shadowColor {
            renderShadow(
                batch: batch,
                to: target,
                shadowColor: shadowColor,
                shadowOffset: state.shadowOffset,
                shadowBlur: state.shadowBlur,
                clipPaths: state.hasClipping ? state.clipPaths : []
            )
        }

        // Check if anti-aliasing (MSAA) is requested
        if state.shouldAntialias {
            // Use MSAA pipeline
            pipelineRegistry.setSampleCount(msaaSampleCount)

            if state.hasClipping {
                guard let clippedPipeline = getClippedPipeline(for: blendMode) else {
                    pipelineRegistry.setSampleCount(1)
                    return
                }
                renderBatchWithMSAAAndClipping(batch, to: target, clippedPipeline: clippedPipeline, clipPaths: state.clipPaths)
            } else {
                guard let pipeline = getPipeline(for: blendMode) else {
                    pipelineRegistry.setSampleCount(1)
                    return
                }
                renderBatchWithMSAA(batch, to: target, pipeline: pipeline)
            }

            pipelineRegistry.setSampleCount(1)
        } else {
            // Use non-MSAA pipeline
            if state.hasClipping {
                guard let clippedPipeline = getClippedPipeline(for: blendMode) else { return }
                renderBatchWithClipping(batch, to: target, pipeline: clippedPipeline, clipPaths: state.clipPaths)
            } else {
                guard let pipeline = getPipeline(for: blendMode) else { return }
                renderBatch(batch, to: target, pipeline: pipeline)
            }
        }
    }

    func stroke(
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
        guard let target = effectiveRenderTarget else { return }

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

        // Render shadow first if needed
        if state.hasShadow, let shadowColor = state.shadowColor {
            renderShadow(
                batch: batch,
                to: target,
                shadowColor: shadowColor,
                shadowOffset: state.shadowOffset,
                shadowBlur: state.shadowBlur,
                clipPaths: state.hasClipping ? state.clipPaths : []
            )
        }

        // Check if anti-aliasing (MSAA) is requested
        if state.shouldAntialias {
            // Use MSAA pipeline
            pipelineRegistry.setSampleCount(msaaSampleCount)

            if state.hasClipping {
                guard let clippedPipeline = getClippedPipeline(for: blendMode) else {
                    pipelineRegistry.setSampleCount(1)
                    return
                }
                renderBatchWithMSAAAndClipping(batch, to: target, clippedPipeline: clippedPipeline, clipPaths: state.clipPaths)
            } else {
                guard let pipeline = getPipeline(for: blendMode) else {
                    pipelineRegistry.setSampleCount(1)
                    return
                }
                renderBatchWithMSAA(batch, to: target, pipeline: pipeline)
            }

            pipelineRegistry.setSampleCount(1)
        } else {
            // Use non-MSAA pipeline
            if state.hasClipping {
                guard let clippedPipeline = getClippedPipeline(for: blendMode) else { return }
                renderBatchWithClipping(batch, to: target, pipeline: clippedPipeline, clipPaths: state.clipPaths)
            } else {
                guard let pipeline = getPipeline(for: blendMode) else { return }
                renderBatch(batch, to: target, pipeline: pipeline)
            }
        }
    }

    func clear(rect: CGRect, state: CGDrawingState) {
        guard let target = effectiveRenderTarget else { return }

        // Create a rectangle path for the clear area
        let clearPath = CGPath(rect: rect)

        // Use transparent color with copy blend mode to clear the area
        let transparentColor = CGColor(red: 0, green: 0, blue: 0, alpha: 0)
        let batch = tessellator.tessellateFill(clearPath, color: transparentColor)
        guard !batch.vertices.isEmpty else { return }

        // Check if clipping is needed
        if state.hasClipping {
            guard let clippedPipeline = getClippedPipeline(for: .copy) else { return }
            renderBatchWithClipping(batch, to: target, pipeline: clippedPipeline, clipPaths: state.clipPaths)
        } else {
            guard let pipeline = getPipeline(for: .copy) else { return }
            renderBatch(batch, to: target, pipeline: pipeline)
        }
    }

    /// Draws an image in the specified rectangle with full drawing state.
    ///
    /// Supports texture-based rendering with clipping and shadow effects.
    func draw(
        image: CGImage,
        in rect: CGRect,
        alpha: CGFloat,
        blendMode: CGBlendMode,
        interpolationQuality: CGInterpolationQuality,
        state: CGDrawingState
    ) {
        guard let target = effectiveRenderTarget else { return }

        // For shadow rendering, use placeholder approach for now
        // (Shadow needs the shape's alpha mask, which is complex with textures)
        if state.hasShadow, let shadowColor = state.shadowColor {
            let shadowVertices = createImagePlaceholderVertices(rect: rect, alpha: 1.0)
            if !shadowVertices.isEmpty {
                let shadowBatch = CGWebGPUVertexBatch(vertices: shadowVertices)
                renderShadow(
                    batch: shadowBatch,
                    to: target,
                    shadowColor: shadowColor,
                    shadowOffset: state.shadowOffset,
                    shadowBlur: state.shadowBlur,
                    clipPaths: state.hasClipping ? state.clipPaths : []
                )
            }
        }

        // Use texture-based rendering
        guard let pipeline = getImagePipeline(),
              let sampler = linearSampler else {
            // Fallback to placeholder
            let vertices = createImagePlaceholderVertices(rect: rect, alpha: alpha)
            guard !vertices.isEmpty else { return }
            let batch = CGWebGPUVertexBatch(vertices: vertices)
            if state.hasClipping {
                guard let clippedPipeline = getClippedPipeline(for: blendMode) else { return }
                renderBatchWithClipping(batch, to: target, pipeline: clippedPipeline, clipPaths: state.clipPaths)
            } else {
                guard let p = getPipeline(for: blendMode) else { return }
                renderBatch(batch, to: target, pipeline: p)
            }
            return
        }

        // Get or create texture view for the image (via TextureManager)
        guard let textureView = getOrCreateTextureView(for: image) else {
            // Fallback to placeholder
            let vertices = createImagePlaceholderVertices(rect: rect, alpha: alpha)
            guard !vertices.isEmpty else { return }
            let batch = CGWebGPUVertexBatch(vertices: vertices)
            if let p = getPipeline(for: blendMode) {
                renderBatch(batch, to: target, pipeline: p)
            }
            return
        }

        // Create resources for texture rendering
        let vertices = createImageQuadVertices(rect: rect)
        let vertexBuffer = createImageVertexBuffer(from: vertices)
        let uniformBuffer = createImageUniformBuffer(alpha: alpha)

        let bindGroup = device.createBindGroup(descriptor: GPUBindGroupDescriptor(
            layout: pipeline.getBindGroupLayout(index: 0),
            entries: [
                GPUBindGroupEntry(binding: 0, resource: .sampler(sampler)),
                GPUBindGroupEntry(binding: 1, resource: .textureView(textureView)),
                GPUBindGroupEntry(binding: 2, resource: .bufferBinding(GPUBufferBinding(buffer: uniformBuffer)))
            ]
        ))

        // Render the image
        let encoder = device.createCommandEncoder()
        let colorAttachment = GPURenderPassColorAttachment(
            view: target,
            loadOp: .load,
            storeOp: .store
        )

        let renderPass = encoder.beginRenderPass(descriptor: GPURenderPassDescriptor(
            colorAttachments: [colorAttachment]
        ))

        renderPass.setPipeline(pipeline)
        renderPass.setBindGroup(0, bindGroup: bindGroup)
        renderPass.setVertexBuffer(0, buffer: vertexBuffer)
        renderPass.draw(vertexCount: 6)
        renderPass.end()

        queue.submit([encoder.finish()])
    }

    func drawLinearGradient(
        _ gradient: CGGradient,
        start: CGPoint,
        end: CGPoint,
        options: CGGradientDrawingOptions,
        state: CGDrawingState
    ) {
        guard let target = effectiveRenderTarget else { return }

        let vertices = createLinearGradientVertices(
            gradient: gradient,
            start: start,
            end: end,
            options: options,
            alpha: 1.0
        )
        guard !vertices.isEmpty else { return }

        let batch = CGWebGPUVertexBatch(vertices: vertices)

        // Check if clipping is needed
        if state.hasClipping {
            guard let clippedPipeline = getClippedPipeline(for: .normal) else { return }
            renderBatchWithClipping(batch, to: target, pipeline: clippedPipeline, clipPaths: state.clipPaths)
        } else {
            guard let pipeline = getPipeline(for: .normal) else { return }
            renderBatch(batch, to: target, pipeline: pipeline)
        }
    }

    func drawRadialGradient(
        _ gradient: CGGradient,
        startCenter: CGPoint,
        startRadius: CGFloat,
        endCenter: CGPoint,
        endRadius: CGFloat,
        options: CGGradientDrawingOptions,
        state: CGDrawingState
    ) {
        guard let target = effectiveRenderTarget else { return }

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

        // Check if clipping is needed
        if state.hasClipping {
            guard let clippedPipeline = getClippedPipeline(for: .normal) else { return }
            renderBatchWithClipping(batch, to: target, pipeline: clippedPipeline, clipPaths: state.clipPaths)
        } else {
            guard let pipeline = getPipeline(for: .normal) else { return }
            renderBatch(batch, to: target, pipeline: pipeline)
        }
    }

    // MARK: - Shading Drawing

    func drawShading(
        _ shading: CGShading,
        alpha: CGFloat,
        blendMode: CGBlendMode
    ) {
        guard let target = effectiveRenderTarget,
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
        let colors = gradient.colors
        guard !colors.isEmpty,
              let locations = gradient.locations else { return [] }

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
        let colors = gradient.colors
        guard !colors.isEmpty,
              let locations = gradient.locations else { return [] }

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
    func fillWithPattern(
        path: CGPath,
        pattern: CGPattern,
        patternSpace: CGColorSpace,
        colorComponents: [CGFloat]?,
        patternPhase: CGSize,
        alpha: CGFloat,
        blendMode: CGBlendMode,
        rule: CGPathFillRule
    ) {
        guard let target = effectiveRenderTarget,
              let pipeline = getPatternPipeline() else { return }

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
            patternColor = CGColor(gray: 0.5, alpha: 1.0)
        }

        let effectiveColor = applyAlpha(patternColor, alpha: alpha)
        let batch = tessellator.tessellateFill(path, color: effectiveColor)
        guard !batch.vertices.isEmpty else { return }

        // Create pattern uniform buffer
        let patternUniforms = createPatternUniformBuffer(pattern: pattern)

        // Create bind group for pattern uniforms
        let bindGroup = device.createBindGroup(descriptor: GPUBindGroupDescriptor(
            layout: pipeline.getBindGroupLayout(index: 0),
            entries: [
                GPUBindGroupEntry(binding: 0, resource: .bufferBinding(GPUBufferBinding(buffer: patternUniforms)))
            ]
        ))

        // Render with pattern pipeline
        renderBatchWithPattern(batch, to: target, pipeline: pipeline, bindGroup: bindGroup)
    }

    /// Strokes a path with a pattern.
    ///
    /// Uses GPU-based pattern tiling for efficient rendering.
    func strokeWithPattern(
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
        guard let target = effectiveRenderTarget,
              let pipeline = getPatternPipeline() else { return }

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

        // Create pattern uniform buffer
        let patternUniforms = createPatternUniformBuffer(pattern: pattern)

        // Create bind group for pattern uniforms
        let bindGroup = device.createBindGroup(descriptor: GPUBindGroupDescriptor(
            layout: pipeline.getBindGroupLayout(index: 0),
            entries: [
                GPUBindGroupEntry(binding: 0, resource: .bufferBinding(GPUBufferBinding(buffer: patternUniforms)))
            ]
        ))

        // Render with pattern pipeline
        renderBatchWithPattern(batch, to: target, pipeline: pipeline, bindGroup: bindGroup)
    }

    // MARK: - Private Helpers

    private func renderBatch(_ batch: CGWebGPUVertexBatch, to textureView: GPUTextureView, pipeline: GPURenderPipeline) {
        guard let allocation = createVertexBufferAllocation(from: batch) else { return }

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
        renderPass.setVertexBuffer(0, buffer: allocation.buffer, offset: allocation.offset)
        renderPass.draw(vertexCount: UInt32(batch.vertices.count))
        renderPass.end()

        queue.submit([encoder.finish()])
    }

    /// Renders a batch with MSAA (multi-sample anti-aliasing).
    ///
    /// This method:
    /// 1. Renders to the MSAA texture (multisampled)
    /// 2. Automatically resolves to the target texture via resolveTarget
    private func renderBatchWithMSAA(
        _ batch: CGWebGPUVertexBatch,
        to textureView: GPUTextureView,
        pipeline: GPURenderPipeline
    ) {
        guard let msaaView = msaaRenderTextureView,
              let allocation = createVertexBufferAllocation(from: batch) else {
            // Fall back to non-MSAA rendering if MSAA textures are not available
            renderBatch(batch, to: textureView, pipeline: pipeline)
            return
        }

        let encoder = device.createCommandEncoder()

        // MSAA color attachment: render to MSAA texture, resolve to target
        let colorAttachment = GPURenderPassColorAttachment(
            view: msaaView,
            resolveTarget: textureView,
            loadOp: .load,
            storeOp: .discard  // Don't store MSAA texture, only the resolved result
        )

        let renderPass = encoder.beginRenderPass(descriptor: GPURenderPassDescriptor(
            colorAttachments: [colorAttachment]
        ))

        renderPass.setPipeline(pipeline)
        renderPass.setVertexBuffer(0, buffer: allocation.buffer, offset: allocation.offset)
        renderPass.draw(vertexCount: UInt32(batch.vertices.count))
        renderPass.end()

        queue.submit([encoder.finish()])
    }

    /// Renders a batch with MSAA and clipping applied using stencil buffer.
    ///
    /// - Note: The caller must have already set the sampleCount on pipelineRegistry
    ///   and obtained the clippedPipeline with MSAA enabled.
    private func renderBatchWithMSAAAndClipping(
        _ batch: CGWebGPUVertexBatch,
        to textureView: GPUTextureView,
        clippedPipeline: GPURenderPipeline,
        clipPaths: [CGPath]
    ) {
        guard let msaaView = msaaRenderTextureView,
              let msaaStencilView = msaaStencilTextureView,
              let stencilPipeline = getStencilWritePipeline(),
              !clipPaths.isEmpty else {
            // Fall back to non-MSAA clipping if MSAA textures are not available
            renderBatchWithClipping(batch, to: textureView, pipeline: clippedPipeline, clipPaths: clipPaths)
            return
        }

        let contentBuffer = createVertexBuffer(from: batch)
        let encoder = device.createCommandEncoder()

        // Pass 1: Clear stencil and render clip paths to MSAA stencil
        let stencilClearAttachment = GPURenderPassDepthStencilAttachment(
            view: msaaStencilView,
            depthClearValue: 1.0,
            depthLoadOp: .clear,
            depthStoreOp: .store,
            stencilClearValue: 0,
            stencilLoadOp: .clear,
            stencilStoreOp: .store
        )

        let colorLoadAttachment = GPURenderPassColorAttachment(
            view: msaaView,
            resolveTarget: textureView,
            loadOp: .load,
            storeOp: .discard
        )

        // First render pass: write clip paths to stencil
        let stencilPass = encoder.beginRenderPass(descriptor: GPURenderPassDescriptor(
            colorAttachments: [colorLoadAttachment],
            depthStencilAttachment: stencilClearAttachment
        ))

        stencilPass.setPipeline(stencilPipeline)

        // Tessellate and render each clip path
        for clipPath in clipPaths {
            let clipBatch = tessellator.tessellateFill(clipPath, color: .black)
            if !clipBatch.vertices.isEmpty {
                let clipBuffer = createVertexBuffer(from: clipBatch)
                stencilPass.setVertexBuffer(0, buffer: clipBuffer)
                stencilPass.setStencilReference(UInt32(clipPaths.count))
                stencilPass.draw(vertexCount: UInt32(clipBatch.vertices.count))
            }
        }

        stencilPass.end()

        // Pass 2: Render actual content with stencil test (using MSAA)
        let stencilTestAttachment = GPURenderPassDepthStencilAttachment(
            view: msaaStencilView,
            depthLoadOp: .load,
            depthStoreOp: .store,
            stencilLoadOp: .load,
            stencilStoreOp: .store
        )

        let colorStoreAttachment = GPURenderPassColorAttachment(
            view: msaaView,
            resolveTarget: textureView,
            loadOp: .load,
            storeOp: .discard
        )

        let contentPass = encoder.beginRenderPass(descriptor: GPURenderPassDescriptor(
            colorAttachments: [colorStoreAttachment],
            depthStencilAttachment: stencilTestAttachment
        ))

        // Use the passed clipped pipeline (already has correct blend mode and MSAA sample count)
        contentPass.setPipeline(clippedPipeline)
        contentPass.setVertexBuffer(0, buffer: contentBuffer)
        contentPass.setStencilReference(UInt32(clipPaths.count))
        contentPass.draw(vertexCount: UInt32(batch.vertices.count))
        contentPass.end()

        queue.submit([encoder.finish()])
    }

    /// Renders a batch with clipping applied using stencil buffer.
    ///
    /// This method:
    /// 1. Clears the stencil buffer
    /// 2. Renders all clip paths to stencil, incrementing the stencil value
    /// 3. Renders the actual content only where stencil equals the number of clip paths
    private func renderBatchWithClipping(
        _ batch: CGWebGPUVertexBatch,
        to textureView: GPUTextureView,
        pipeline: GPURenderPipeline,
        clipPaths: [CGPath]
    ) {
        guard let stencilView = stencilTextureView,
              let stencilPipeline = getStencilWritePipeline(),
              !clipPaths.isEmpty else {
            // Fall back to regular rendering if no stencil available
            renderBatch(batch, to: textureView, pipeline: pipeline)
            return
        }

        let contentBuffer = createVertexBuffer(from: batch)
        let encoder = device.createCommandEncoder()

        // Pass 1: Clear stencil and render clip paths
        let stencilClearAttachment = GPURenderPassDepthStencilAttachment(
            view: stencilView,
            depthClearValue: 1.0,
            depthLoadOp: .clear,
            depthStoreOp: .store,
            stencilClearValue: 0,
            stencilLoadOp: .clear,
            stencilStoreOp: .store
        )

        let colorLoadAttachment = GPURenderPassColorAttachment(
            view: textureView,
            loadOp: .load,
            storeOp: .store
        )

        // First render pass: write clip paths to stencil
        let stencilPass = encoder.beginRenderPass(descriptor: GPURenderPassDescriptor(
            colorAttachments: [colorLoadAttachment],
            depthStencilAttachment: stencilClearAttachment
        ))

        stencilPass.setPipeline(stencilPipeline)

        // Tessellate and render each clip path
        for clipPath in clipPaths {
            let clipBatch = tessellator.tessellateFill(clipPath, color: .black)
            if !clipBatch.vertices.isEmpty {
                let clipBuffer = createVertexBuffer(from: clipBatch)
                stencilPass.setVertexBuffer(0, buffer: clipBuffer)
                stencilPass.setStencilReference(UInt32(clipPaths.count))
                stencilPass.draw(vertexCount: UInt32(clipBatch.vertices.count))
            }
        }

        stencilPass.end()

        // Pass 2: Render actual content with stencil test
        let stencilTestAttachment = GPURenderPassDepthStencilAttachment(
            view: stencilView,
            depthLoadOp: .load,
            depthStoreOp: .store,
            stencilLoadOp: .load,
            stencilStoreOp: .store
        )

        let contentPass = encoder.beginRenderPass(descriptor: GPURenderPassDescriptor(
            colorAttachments: [colorLoadAttachment],
            depthStencilAttachment: stencilTestAttachment
        ))

        contentPass.setPipeline(pipeline)
        contentPass.setVertexBuffer(0, buffer: contentBuffer)
        contentPass.setStencilReference(UInt32(clipPaths.count))
        contentPass.draw(vertexCount: UInt32(batch.vertices.count))
        contentPass.end()

        queue.submit([encoder.finish()])
    }

    /// Renders a shadow for the given batch using multi-pass blur.
    ///
    /// This method:
    /// 1. Renders the shape to shadow mask texture
    /// 2. Applies horizontal Gaussian blur
    /// 3. Applies vertical Gaussian blur
    /// 4. Composites the blurred shadow to the target with offset and color
    private func renderShadow(
        batch: CGWebGPUVertexBatch,
        to textureView: GPUTextureView,
        shadowColor: CGColor,
        shadowOffset: CGSize,
        shadowBlur: CGFloat,
        clipPaths: [CGPath]
    ) {
        guard let shadowMaskView = shadowMaskTextureView,
              let blurIntermediateView = blurIntermediateTextureView,
              let blurHPipeline = getBlurHorizontalPipeline(),
              let blurVPipeline = getBlurVerticalPipeline(),
              let shadowPipeline = getShadowCompositePipeline(),
              let sampler = linearSampler,
              let normalPipeline = getPipeline(for: .copy) else { return }

        let encoder = device.createCommandEncoder()

        // Pass 1: Render shape to shadow mask
        let shadowBuffer = createVertexBuffer(from: batch)
        let maskClearAttachment = GPURenderPassColorAttachment(
            view: shadowMaskView,
            clearValue: GPUColor(r: 0, g: 0, b: 0, a: 0),
            loadOp: .clear,
            storeOp: .store
        )

        let maskPass = encoder.beginRenderPass(descriptor: GPURenderPassDescriptor(
            colorAttachments: [maskClearAttachment]
        ))
        maskPass.setPipeline(normalPipeline)
        maskPass.setVertexBuffer(0, buffer: shadowBuffer)
        maskPass.draw(vertexCount: UInt32(batch.vertices.count))
        maskPass.end()

        // Only apply blur if shadowBlur > 0
        if shadowBlur > 0 {
            // Pass 2: Horizontal blur (shadow mask → intermediate)
            let blurUniforms = createBlurUniformBuffer(blurRadius: shadowBlur)
            let hBlurBindGroup = device.createBindGroup(descriptor: GPUBindGroupDescriptor(
                layout: blurHPipeline.getBindGroupLayout(index: 0),
                entries: [
                    GPUBindGroupEntry(binding: 0, resource: .sampler(sampler)),
                    GPUBindGroupEntry(binding: 1, resource: .textureView(shadowMaskView)),
                    GPUBindGroupEntry(binding: 2, resource: .bufferBinding(GPUBufferBinding(buffer: blurUniforms)))
                ]
            ))

            let hBlurAttachment = GPURenderPassColorAttachment(
                view: blurIntermediateView,
                clearValue: GPUColor(r: 0, g: 0, b: 0, a: 0),
                loadOp: .clear,
                storeOp: .store
            )

            let hBlurPass = encoder.beginRenderPass(descriptor: GPURenderPassDescriptor(
                colorAttachments: [hBlurAttachment]
            ))
            hBlurPass.setPipeline(blurHPipeline)
            hBlurPass.setBindGroup(0, bindGroup: hBlurBindGroup)
            hBlurPass.draw(vertexCount: 6)
            hBlurPass.end()

            // Pass 3: Vertical blur (intermediate → shadow mask)
            let vBlurBindGroup = device.createBindGroup(descriptor: GPUBindGroupDescriptor(
                layout: blurVPipeline.getBindGroupLayout(index: 0),
                entries: [
                    GPUBindGroupEntry(binding: 0, resource: .sampler(sampler)),
                    GPUBindGroupEntry(binding: 1, resource: .textureView(blurIntermediateView)),
                    GPUBindGroupEntry(binding: 2, resource: .bufferBinding(GPUBufferBinding(buffer: blurUniforms)))
                ]
            ))

            let vBlurAttachment = GPURenderPassColorAttachment(
                view: shadowMaskView,
                clearValue: GPUColor(r: 0, g: 0, b: 0, a: 0),
                loadOp: .clear,
                storeOp: .store
            )

            let vBlurPass = encoder.beginRenderPass(descriptor: GPURenderPassDescriptor(
                colorAttachments: [vBlurAttachment]
            ))
            vBlurPass.setPipeline(blurVPipeline)
            vBlurPass.setBindGroup(0, bindGroup: vBlurBindGroup)
            vBlurPass.draw(vertexCount: 6)
            vBlurPass.end()
        }

        // Pass 4: Composite shadow to target
        let shadowUniforms = createShadowUniformBuffer(
            shadowColor: shadowColor,
            offset: shadowOffset
        )

        let shadowBindGroup = device.createBindGroup(descriptor: GPUBindGroupDescriptor(
            layout: shadowPipeline.getBindGroupLayout(index: 0),
            entries: [
                GPUBindGroupEntry(binding: 0, resource: .sampler(sampler)),
                GPUBindGroupEntry(binding: 1, resource: .textureView(shadowMaskView)),
                GPUBindGroupEntry(binding: 2, resource: .bufferBinding(GPUBufferBinding(buffer: shadowUniforms)))
            ]
        ))

        let compositeAttachment = GPURenderPassColorAttachment(
            view: textureView,
            loadOp: .load,
            storeOp: .store
        )

        let compositePass = encoder.beginRenderPass(descriptor: GPURenderPassDescriptor(
            colorAttachments: [compositeAttachment]
        ))
        compositePass.setPipeline(shadowPipeline)
        compositePass.setBindGroup(0, bindGroup: shadowBindGroup)
        compositePass.draw(vertexCount: 6)
        compositePass.end()

        queue.submit([encoder.finish()])
    }

    /// Creates a uniform buffer for blur parameters.
    private func createBlurUniformBuffer(blurRadius: CGFloat) -> GPUBuffer {
        let texelSizeX = Float(1.0 / viewportWidth)
        let texelSizeY = Float(1.0 / viewportHeight)
        let radius = Float(blurRadius)

        let data: [Float] = [texelSizeX, texelSizeY, radius, 0.0]  // padding for alignment
        let buffer = device.createBuffer(descriptor: GPUBufferDescriptor(
            size: UInt64(data.count * MemoryLayout<Float>.stride),
            usage: [.uniform, .copyDst],
            label: "Blur Uniforms"
        ))

        let jsArray = JSTypedArray<Float32>(data)
        queue.writeBuffer(buffer, bufferOffset: 0, data: jsArray.jsObject)
        return buffer
    }

    /// Creates a uniform buffer for shadow composite parameters.
    private func createShadowUniformBuffer(shadowColor: CGColor, offset: CGSize) -> GPUBuffer {
        let components = shadowColor.components ?? [0, 0, 0, 0.5]
        let r = Float(components.count > 0 ? components[0] : 0)
        let g = Float(components.count > 1 ? components[1] : 0)
        let b = Float(components.count > 2 ? components[2] : 0)
        let a = Float(components.count > 3 ? components[3] : 0.5)

        // Normalize offset to texture coordinates
        let offsetX = Float(offset.width / viewportWidth)
        let offsetY = Float(offset.height / viewportHeight)

        let data: [Float] = [r, g, b, a, offsetX, offsetY, 0.0, 0.0]  // padding for alignment
        let buffer = device.createBuffer(descriptor: GPUBufferDescriptor(
            size: UInt64(data.count * MemoryLayout<Float>.stride),
            usage: [.uniform, .copyDst],
            label: "Shadow Uniforms"
        ))

        let jsArray = JSTypedArray<Float32>(data)
        queue.writeBuffer(buffer, bufferOffset: 0, data: jsArray.jsObject)
        return buffer
    }

    /// Creates a vertex buffer allocation from a batch (via BufferPool).
    ///
    /// - Parameter batch: The vertex batch to upload
    /// - Returns: Buffer allocation with buffer and offset, or nil if empty
    private func createVertexBufferAllocation(from batch: CGWebGPUVertexBatch) -> BufferPool.Allocation? {
        guard !batch.vertices.isEmpty else { return nil }

        let floatData = batch.toFloatArray()
        return bufferPool.acquireAndWrite(data: floatData)
    }

    /// Creates a vertex buffer from a batch (convenience method, offset at 0).
    ///
    /// For cases where we need a standalone buffer (not using the pool).
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

    /// Creates a uniform buffer for pattern parameters.
    private func createPatternUniformBuffer(pattern: CGPattern) -> GPUBuffer {
        // Convert to normalized device coordinates
        let boundsX = Float(pattern.bounds.origin.x / viewportWidth * 2.0)
        let boundsY = Float(pattern.bounds.origin.y / viewportHeight * 2.0)
        let boundsW = Float(pattern.bounds.width / viewportWidth * 2.0)
        let boundsH = Float(pattern.bounds.height / viewportHeight * 2.0)

        // Convert step to NDC
        let stepX = Float(pattern.xStep / viewportWidth * 2.0)
        let stepY = Float(pattern.yStep / viewportHeight * 2.0)

        let isColored: Float = pattern.isColored ? 1.0 : 0.0

        // Determine pattern type based on bounds aspect ratio
        // This is a heuristic - real patterns would need more info
        let patternType: Float = 1.0  // Default to checkerboard

        let data: [Float] = [
            boundsX, boundsY, boundsW, boundsH,  // bounds
            stepX, stepY,                          // step
            isColored,                             // isColored
            patternType                            // patternType
        ]

        let buffer = device.createBuffer(descriptor: GPUBufferDescriptor(
            size: UInt64(data.count * MemoryLayout<Float>.stride),
            usage: [.uniform, .copyDst],
            label: "Pattern Uniforms"
        ))

        let jsArray = JSTypedArray<Float32>(data)
        queue.writeBuffer(buffer, bufferOffset: 0, data: jsArray.jsObject)
        return buffer
    }

    /// Renders a batch with pattern pipeline and bind group.
    private func renderBatchWithPattern(
        _ batch: CGWebGPUVertexBatch,
        to textureView: GPUTextureView,
        pipeline: GPURenderPipeline,
        bindGroup: GPUBindGroup
    ) {
        let buffer = createVertexBuffer(from: batch)

        let encoder = device.createCommandEncoder()

        let colorAttachment = GPURenderPassColorAttachment(
            view: textureView,
            loadOp: .load,
            storeOp: .store
        )

        let renderPass = encoder.beginRenderPass(descriptor: GPURenderPassDescriptor(
            colorAttachments: [colorAttachment]
        ))

        renderPass.setPipeline(pipeline)
        renderPass.setBindGroup(0, bindGroup: bindGroup)
        renderPass.setVertexBuffer(0, buffer: buffer)
        renderPass.draw(vertexCount: UInt32(batch.vertices.count))
        renderPass.end()

        queue.submit([encoder.finish()])
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

    // MARK: - Image Rendering Helpers (via TextureManager)

    /// Gets or creates a GPU texture view for the given CGImage.
    private func getOrCreateTextureView(for image: CGImage) -> GPUTextureView? {
        return textureManager.getOrCreateTexture(for: image)
    }

    /// Extracts RGBA pixel data from a CGImage.
    ///
    /// This method handles various pixel formats and converts them to RGBA8.
    /// Note: Uses Swift native Data type, not CoreFoundation CFData.
    private func extractPixelData(from image: CGImage) -> [UInt8]? {
        guard let dataProvider = image.dataProvider,
              let data = dataProvider.data else { return nil }

        // Get image properties
        let width = image.width
        let height = image.height
        let bitsPerComponent = image.bitsPerComponent
        let bytesPerRow = image.bytesPerRow
        let bitmapInfo = image.bitmapInfo
        let alphaInfo = CGImageAlphaInfo(rawValue: bitmapInfo.rawValue & CGBitmapInfo.alphaInfoMask.rawValue)

        // Expected RGBA format
        let expectedBytes = width * height * 4

        // If the image is already in a compatible 8-bit format
        if bitsPerComponent == 8 && bytesPerRow == width * 4 {
            var result = [UInt8](repeating: 0, count: expectedBytes)

            // Copy data from Swift Data type
            data.withUnsafeBytes { buffer in
                guard let ptr = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
                let copyCount = min(data.count, expectedBytes)
                for i in 0..<copyCount {
                    result[i] = ptr[i]
                }
            }

            // Handle BGR to RGB conversion if needed
            if image.byteOrderInfo == .order32Little {
                // BGRA to RGBA
                for y in 0..<height {
                    for x in 0..<width {
                        let idx = (y * width + x) * 4
                        let b = result[idx]
                        let r = result[idx + 2]
                        result[idx] = r
                        result[idx + 2] = b
                    }
                }
            }

            // Handle alpha
            if alphaInfo == .noneSkipFirst || alphaInfo == .noneSkipLast {
                // Set alpha to 255 if no alpha channel
                for y in 0..<height {
                    for x in 0..<width {
                        let idx = (y * width + x) * 4 + 3
                        result[idx] = 255
                    }
                }
            }

            return result
        }

        // For other formats (different bit depths, row padding, etc.),
        // we need to re-render the image to get consistent RGBA8 data.
        // Create a bitmap context without a delegate to avoid recursion.
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }

        var result = [UInt8](repeating: 0, count: expectedBytes)

        // Create context and render the image
        result.withUnsafeMutableBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            let rawPointer = UnsafeMutableRawPointer(baseAddress)

            guard let context = CGContext(
                data: rawPointer,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
            ) else { return }

            // Important: Do NOT set rendererDelegate on this context
            // to avoid infinite recursion when drawing the image
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }

        return result
    }

    /// Creates quad vertices for image rendering with texture coordinates.
    private func createImageQuadVertices(rect: CGRect) -> [Float] {
        // Convert rect to NDC
        let left = Float(rect.minX / viewportWidth * 2.0 - 1.0)
        let right = Float(rect.maxX / viewportWidth * 2.0 - 1.0)
        let bottom = Float(rect.minY / viewportHeight * 2.0 - 1.0)
        let top = Float(rect.maxY / viewportHeight * 2.0 - 1.0)

        // Two triangles for a quad
        // Each vertex: position(2) + texCoord(2)
        return [
            // Triangle 1
            left, bottom, 0.0, 1.0,   // bottom-left
            right, bottom, 1.0, 1.0,  // bottom-right
            right, top, 1.0, 0.0,     // top-right

            // Triangle 2
            left, bottom, 0.0, 1.0,   // bottom-left
            right, top, 1.0, 0.0,     // top-right
            left, top, 0.0, 0.0       // top-left
        ]
    }

    /// Creates a vertex buffer for image quad vertices.
    private func createImageVertexBuffer(from vertices: [Float]) -> GPUBuffer {
        let buffer = device.createBuffer(descriptor: GPUBufferDescriptor(
            size: UInt64(vertices.count * MemoryLayout<Float>.stride),
            usage: [.vertex, .copyDst],
            label: "Image Vertex Buffer"
        ))

        let jsArray = JSTypedArray<Float32>(vertices)
        queue.writeBuffer(buffer, bufferOffset: 0, data: jsArray.jsObject)

        return buffer
    }

    /// Creates a uniform buffer for image alpha.
    private func createImageUniformBuffer(alpha: CGFloat) -> GPUBuffer {
        let data: [Float] = [Float(alpha), 0.0, 0.0, 0.0]  // alpha + padding

        let buffer = device.createBuffer(descriptor: GPUBufferDescriptor(
            size: UInt64(data.count * MemoryLayout<Float>.stride),
            usage: [.uniform, .copyDst],
            label: "Image Uniforms"
        ))

        let jsArray = JSTypedArray<Float32>(data)
        queue.writeBuffer(buffer, bufferOffset: 0, data: jsArray.jsObject)

        return buffer
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

    // MARK: - GPU Readback (makeImage)

    /// Creates an image from the current render target contents.
    ///
    /// This method performs a GPU readback operation to extract pixel data from
    /// the internal render texture and creates a CGImage from it.
    ///
    /// - Parameters:
    ///   - width: The width of the image in pixels.
    ///   - height: The height of the image in pixels.
    ///   - colorSpace: The color space for the resulting image.
    /// - Returns: A CGImage containing the rendered content, or nil if readback fails.
    func makeImage(width: Int, height: Int, colorSpace: CGColorSpace) async -> CGImage? {
        guard let texture = internalRenderTexture else {
            return nil
        }

        let textureWidth = Int(texture.width)
        let textureHeight = Int(texture.height)

        // Use the smaller of requested size and texture size
        let actualWidth = min(width, textureWidth)
        let actualHeight = min(height, textureHeight)

        guard actualWidth > 0, actualHeight > 0 else {
            return nil
        }

        // 4 bytes per pixel (RGBA or BGRA depending on textureFormat)
        let bytesPerPixel = 4
        // WebGPU requires bytesPerRow to be aligned to 256 bytes
        let unalignedBytesPerRow = actualWidth * bytesPerPixel
        let alignment = 256
        let bytesPerRow = ((unalignedBytesPerRow + alignment - 1) / alignment) * alignment
        let bufferSize = bytesPerRow * actualHeight

        // Create staging buffer for readback
        let stagingBuffer = device.createBuffer(descriptor: GPUBufferDescriptor(
            size: UInt64(bufferSize),
            usage: [.mapRead, .copyDst],
            label: "CGWebGPU Readback Buffer"
        ))

        // Create command encoder
        let encoder = device.createCommandEncoder()

        // Copy texture to buffer
        encoder.copyTextureToBuffer(
            source: GPUImageCopyTexture(
                texture: texture,
                mipLevel: 0,
                origin: GPUOrigin3D(x: 0, y: 0, z: 0),
                aspect: .all
            ),
            destination: GPUImageCopyBuffer(
                buffer: stagingBuffer,
                offset: 0,
                bytesPerRow: UInt32(bytesPerRow),
                rowsPerImage: UInt32(actualHeight)
            ),
            copySize: GPUExtent3D(
                width: UInt32(actualWidth),
                height: UInt32(actualHeight),
                depthOrArrayLayers: 1
            )
        )

        // Submit commands
        let commandBuffer = encoder.finish()
        queue.submit([commandBuffer])

        // Map the buffer for reading
        do {
            try await stagingBuffer.mapAsync(mode: .read)
        } catch {
            stagingBuffer.destroy()
            return nil
        }

        // Get the mapped range
        let mappedRange = stagingBuffer.getMappedRange()

        // Read pixel data from the ArrayBuffer
        let pixelData = readPixelDataFromArrayBuffer(
            mappedRange,
            width: actualWidth,
            height: actualHeight,
            bytesPerRow: bytesPerRow
        )

        // Unmap and destroy the buffer
        stagingBuffer.unmap()
        stagingBuffer.destroy()

        guard let pixelData = pixelData else {
            return nil
        }

        // Create CGImage from pixel data
        return createCGImage(
            from: pixelData,
            width: actualWidth,
            height: actualHeight,
            colorSpace: colorSpace
        )
    }

    /// Reads pixel data from a JavaScript ArrayBuffer and converts to RGBA if needed.
    ///
    /// The conversion depends on the texture format:
    /// - `bgra8unorm`: Converts BGRA to RGBA
    /// - `rgba8unorm`: Copies directly (no conversion needed)
    private func readPixelDataFromArrayBuffer(
        _ arrayBuffer: JSObject,
        width: Int,
        height: Int,
        bytesPerRow: Int
    ) -> Data? {
        let bytesPerPixel = 4
        let outputBytesPerRow = width * bytesPerPixel
        let totalBytes = outputBytesPerRow * height

        // Create a Uint8Array view of the ArrayBuffer
        let uint8Array = JSObject.global.Uint8Array.function!.new(arrayBuffer)

        var pixelData = Data(count: totalBytes)

        // Check if we need to convert BGRA to RGBA
        let needsConversion = (textureFormat == .bgra8unorm)

        // Copy pixel data, handling row stride
        for y in 0..<height {
            let srcRowOffset = y * bytesPerRow
            let dstRowOffset = y * outputBytesPerRow

            for x in 0..<width {
                let srcOffset = srcRowOffset + x * bytesPerPixel
                let dstOffset = dstRowOffset + x * bytesPerPixel

                if needsConversion {
                    // Read BGRA values and write as RGBA
                    let b = UInt8(uint8Array[srcOffset].number ?? 0)
                    let g = UInt8(uint8Array[srcOffset + 1].number ?? 0)
                    let r = UInt8(uint8Array[srcOffset + 2].number ?? 0)
                    let a = UInt8(uint8Array[srcOffset + 3].number ?? 0)

                    pixelData[dstOffset] = r
                    pixelData[dstOffset + 1] = g
                    pixelData[dstOffset + 2] = b
                    pixelData[dstOffset + 3] = a
                } else {
                    // RGBA format - copy directly
                    pixelData[dstOffset] = UInt8(uint8Array[srcOffset].number ?? 0)
                    pixelData[dstOffset + 1] = UInt8(uint8Array[srcOffset + 1].number ?? 0)
                    pixelData[dstOffset + 2] = UInt8(uint8Array[srcOffset + 2].number ?? 0)
                    pixelData[dstOffset + 3] = UInt8(uint8Array[srcOffset + 3].number ?? 0)
                }
            }
        }

        return pixelData
    }

    /// Creates a CGImage from RGBA pixel data.
    private func createCGImage(
        from data: Data,
        width: Int,
        height: Int,
        colorSpace: CGColorSpace
    ) -> CGImage? {
        let bitsPerComponent = 8
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bitsPerPixel = bitsPerComponent * bytesPerPixel

        let provider = CGDataProvider(data: data)

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerPixel,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }

    // MARK: - Present to External Target

    /// Presents the internal render texture to the external render target.
    ///
    /// Call this method after all drawing operations are complete to copy
    /// the rendered content from the internal texture to the external canvas texture.
    func present() {
        guard let internalView = internalRenderTextureView,
              let externalTarget = renderTarget else {
            return
        }

        // Use a simple full-screen blit to copy internal texture to external target
        guard let sampler = linearSampler,
              let pipeline = getImagePipeline() else {
            return
        }

        // Create a full-screen quad
        let vertices: [Float] = [
            // position    texCoord
            -1.0, -1.0,    0.0, 1.0,  // bottom-left
             1.0, -1.0,    1.0, 1.0,  // bottom-right
             1.0,  1.0,    1.0, 0.0,  // top-right
            -1.0, -1.0,    0.0, 1.0,  // bottom-left
             1.0,  1.0,    1.0, 0.0,  // top-right
            -1.0,  1.0,    0.0, 0.0   // top-left
        ]

        let vertexBuffer = device.createBuffer(descriptor: GPUBufferDescriptor(
            size: UInt64(vertices.count * MemoryLayout<Float>.stride),
            usage: [.vertex, .copyDst],
            label: "Blit Vertex Buffer"
        ))

        let jsArray = JSTypedArray<Float32>(vertices)
        queue.writeBuffer(vertexBuffer, bufferOffset: 0, data: jsArray.jsObject)

        // Create uniform buffer with alpha = 1.0
        let uniformBuffer = createImageUniformBuffer(alpha: 1.0)

        // Create bind group
        guard internalRenderTexture != nil else { return }
        let bindGroup = device.createBindGroup(descriptor: GPUBindGroupDescriptor(
            layout: pipeline.getBindGroupLayout(index: 0),
            entries: [
                GPUBindGroupEntry(binding: 0, resource: .sampler(sampler)),
                GPUBindGroupEntry(binding: 1, resource: .textureView(internalView)),
                GPUBindGroupEntry(binding: 2, resource: .bufferBinding(GPUBufferBinding(buffer: uniformBuffer)))
            ]
        ))

        // Create render pass
        let encoder = device.createCommandEncoder()
        let renderPass = encoder.beginRenderPass(descriptor: GPURenderPassDescriptor(
            colorAttachments: [
                GPURenderPassColorAttachment(
                    view: externalTarget,
                    clearValue: GPUColor.clear,
                    loadOp: .clear,
                    storeOp: .store
                )
            ]
        ))

        renderPass.setPipeline(pipeline)
        renderPass.setBindGroup(0, bindGroup: bindGroup)
        renderPass.setVertexBuffer(0, buffer: vertexBuffer)
        renderPass.draw(vertexCount: 6)
        renderPass.end()

        let commandBuffer = encoder.finish()
        queue.submit([commandBuffer])
    }

    /// Gets the internal render texture view for direct rendering.
    ///
    /// Use this when you want to render directly to the internal texture
    /// instead of the external render target.
    func getInternalRenderTarget() -> GPUTextureView? {
        // Ensure textures are created
        if internalRenderTextureView == nil {
            recreateOffscreenTexturesIfNeeded()
        }
        return internalRenderTextureView
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
