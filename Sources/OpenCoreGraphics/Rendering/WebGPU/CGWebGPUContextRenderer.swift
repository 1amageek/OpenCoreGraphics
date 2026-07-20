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
internal final class CGWebGPUContextRenderer: CGContextStatefulRendererDelegate, CGLayerRendererDelegate, @unchecked Sendable {

    private struct PatternCell {
        let pattern: CGPattern
        let context: CGContext
        let textureView: GPUTextureView
    }

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
    private var nearestSampler: GPUSampler?

    /// Callback-rendered pattern cells retained with their offscreen contexts.
    private var patternCells: [ObjectIdentifier: PatternCell] = [:]

    /// Prevents a pattern callback from recursively requesting its own cell.
    private var activePatternCells: Set<ObjectIdentifier> = []

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

    /// Device-sized texture containing the product of active image-mask clips.
    private var imageMaskTexture: GPUTexture?
    private var imageMaskTextureView: GPUTextureView?
    private var cachedImageMaskClips: [CGImageMaskClip]?

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

    /// Flag indicating that MSAA content needs to be resolved to the target texture
    private var needsMSAAResolve: Bool = false

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
        // Get device from Swift global (set by setupGraphicsContext())
        guard let device = getGlobalDevice() else {
            fatalError("WebGPU not initialized. Call setupGraphicsContext() before using CGContext.")
        }

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
        nearestSampler = device.createSampler(descriptor: GPUSamplerDescriptor(
            addressModeU: .clampToEdge,
            addressModeV: .clampToEdge,
            magFilter: .nearest,
            minFilter: .nearest,
            label: "CGWebGPU Nearest Sampler"
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

        imageMaskTexture = device.createTexture(descriptor: GPUTextureDescriptor(
            size: GPUExtent3D(width: width, height: height),
            format: .rgba8unorm,
            usage: [.textureBinding, .copyDst],
            label: "CGWebGPU Image Mask Clip Texture"
        ))
        imageMaskTextureView = imageMaskTexture?.createView()
        cachedImageMaskClips = nil

        // Create MSAA render texture (multisampled)
        msaaRenderTexture = device.createTexture(descriptor: GPUTextureDescriptor(
            size: GPUExtent3D(width: width, height: height),
            sampleCount: UInt32(msaaSampleCount),
            format: textureFormat,
            usage: [.renderAttachment],
            label: "CGWebGPU MSAA Render Texture"
        ))
        msaaRenderTextureView = msaaRenderTexture?.createView()

        // Create MSAA stencil texture (multisampled)
        msaaStencilTexture = device.createTexture(descriptor: GPUTextureDescriptor(
            size: GPUExtent3D(width: width, height: height),
            sampleCount: UInt32(msaaSampleCount),
            format: depthStencilFormat,
            usage: [.renderAttachment],
            label: "CGWebGPU MSAA Stencil Texture"
        ))
        msaaStencilTextureView = msaaStencilTexture?.createView()
        clearInternalRenderTarget()
    }

    private func clearInternalRenderTarget() {
        guard let target = internalRenderTextureView else { return }

        let encoder = device.createCommandEncoder()
        let renderPass = encoder.beginRenderPass(descriptor: GPURenderPassDescriptor(
            colorAttachments: [
                GPURenderPassColorAttachment(
                    view: target,
                    clearValue: GPUColor.clear,
                    loadOp: .clear,
                    storeOp: .store
                )
            ]
        ))
        renderPass.end()

        if let msaaTarget = msaaRenderTextureView {
            let msaaPass = encoder.beginRenderPass(descriptor: GPURenderPassDescriptor(
                colorAttachments: [
                    GPURenderPassColorAttachment(
                        view: msaaTarget,
                        clearValue: GPUColor.clear,
                        loadOp: .clear,
                        storeOp: .store
                    )
                ]
            ))
            msaaPass.end()
        }
        queue.submit([encoder.finish()])
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

    private func getMaskedPipeline(for blendMode: CGBlendMode, pathClipped: Bool) -> GPURenderPipeline? {
        return pipelineRegistry.getPipeline(.maskedBlend(blendMode, pathClipped))
    }

    /// Gets the stencil write pipeline.
    private func getStencilWritePipeline() -> GPURenderPipeline? {
        return pipelineRegistry.getPipeline(.stencilWrite)
    }

    /// Gets the image pipeline for a specific drawing state.
    private func getImagePipeline(for blendMode: CGBlendMode = .normal, clipped: Bool = false) -> GPURenderPipeline? {
        return pipelineRegistry.getPipeline(.image(blendMode, clipped))
    }

    private func getMaskedImagePipeline(for blendMode: CGBlendMode, pathClipped: Bool) -> GPURenderPipeline? {
        return pipelineRegistry.getPipeline(.maskedImage(blendMode, pathClipped))
    }

    /// Gets the pattern pipeline for the requested compositing and clip state.
    private func getPatternPipeline(for blendMode: CGBlendMode, clipped: Bool) -> GPURenderPipeline? {
        return pipelineRegistry.getPipeline(.pattern(blendMode, clipped))
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
        let state = CGDrawingState()
        guard let target = effectiveRenderTarget,
              let pipeline = getPipeline(for: blendMode),
              let convertedColor = state.convertedColor(color),
              let effectiveColor = applyAlpha(convertedColor, alpha: alpha) else { return }

        // Tessellate the path
        // Note: GeometryCache is available for future optimization of static paths
        let batch = tessellator.tessellateFill(path, color: effectiveColor, rule: rule)
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
        let state = CGDrawingState()
        guard let target = effectiveRenderTarget,
              let pipeline = getPipeline(for: blendMode),
              let convertedColor = state.convertedColor(color),
              let effectiveColor = applyAlpha(convertedColor, alpha: alpha) else { return }

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
    func draw(
        image: CGImage,
        in rect: CGRect,
        alpha: CGFloat,
        blendMode: CGBlendMode,
        interpolationQuality: CGInterpolationQuality
    ) {
        let state = CGDrawingState()
        guard let target = effectiveRenderTarget,
              let textureView = getOrCreateTextureView(for: image, state: state) else { return }
        let effectiveInterpolationQuality = image.shouldInterpolate ? interpolationQuality : .none

        drawTexture(
            textureView,
            in: rect,
            alpha: alpha,
            blendMode: blendMode,
            interpolationQuality: effectiveInterpolationQuality,
            target: target,
            clipPaths: [],
            shouldAntialias: false
        )
    }

    func drawLinearGradient(
        _ gradient: CGGradient,
        start: CGPoint,
        end: CGPoint,
        options: CGGradientDrawingOptions
    ) {
        let state = CGDrawingState()
        guard let target = effectiveRenderTarget,
              let pipeline = getPipeline(for: .normal),
              let convertedGradient = state.convertedGradient(gradient) else { return }

        let vertices = createLinearGradientVertices(
            gradient: convertedGradient,
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
        let state = CGDrawingState()
        guard let target = effectiveRenderTarget,
              let pipeline = getPipeline(for: .normal),
              let convertedGradient = state.convertedGradient(gradient) else { return }

        let vertices = createRadialGradientVertices(
            gradient: convertedGradient,
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
        guard let target = effectiveRenderTarget,
              let convertedColor = state.convertedColor(color),
              let effectiveColor = applyAlpha(convertedColor, alpha: alpha) else { return }

        // Tessellate the path
        let batch = tessellator.tessellateFill(path, color: effectiveColor, rule: rule)
        guard !batch.vertices.isEmpty else { return }

        // Render shadow first if needed
        if state.hasShadow,
           let shadowColor = state.shadowColor,
           let convertedShadowColor = state.convertedColor(shadowColor) {
            renderShadow(
                batch: batch,
                to: target,
                shadowColor: convertedShadowColor,
                shadowOffset: state.shadowOffset,
                shadowBlur: state.shadowBlur,
                clipPaths: state.clipPaths,
                shouldAntialias: state.shouldAntialias
            )
        }
        renderStatefulBatch(batch, to: target, blendMode: blendMode, state: state)
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
        guard let target = effectiveRenderTarget,
              let convertedColor = state.convertedColor(color),
              let effectiveColor = applyAlpha(convertedColor, alpha: alpha) else { return }

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
        if state.hasShadow,
           let shadowColor = state.shadowColor,
           let convertedShadowColor = state.convertedColor(shadowColor) {
            renderShadow(
                batch: batch,
                to: target,
                shadowColor: convertedShadowColor,
                shadowOffset: state.shadowOffset,
                shadowBlur: state.shadowBlur,
                clipPaths: state.clipPaths,
                shouldAntialias: state.shouldAntialias
            )
        }
        renderStatefulBatch(batch, to: target, blendMode: blendMode, state: state)
    }

    func clear(rect: CGRect, state: CGDrawingState) {
        guard let target = effectiveRenderTarget else { return }

        // Create a rectangle path for the clear area
        let clearPath = CGPath(rect: rect)

        // Use transparent color with copy blend mode to clear the area
        let transparentColor = CGColor(red: 0, green: 0, blue: 0, alpha: 0)
        let batch = tessellator.tessellateFill(clearPath, color: transparentColor)
        guard !batch.vertices.isEmpty else { return }

        renderStatefulBatch(batch, to: target, blendMode: .copy, state: state)
    }

    /// Draws an image in the specified rectangle with full drawing state.
    ///
    /// Supports texture-based rendering with clipping.
    func draw(
        image: CGImage,
        in rect: CGRect,
        alpha: CGFloat,
        blendMode: CGBlendMode,
        interpolationQuality: CGInterpolationQuality,
        state: CGDrawingState
    ) {
        guard let target = effectiveRenderTarget,
              let textureView = getOrCreateTextureView(for: image, state: state) else { return }
        let effectiveInterpolationQuality = image.shouldInterpolate ? interpolationQuality : .none

        if state.hasShadow,
           let shadowColor = state.shadowColor,
           let convertedShadowColor = state.convertedColor(shadowColor) {
            renderTextureShadow(
                textureView: textureView,
                in: rect,
                alpha: alpha,
                interpolationQuality: effectiveInterpolationQuality,
                to: target,
                shadowColor: convertedShadowColor,
                shadowOffset: state.shadowOffset,
                shadowBlur: state.shadowBlur,
                shouldAntialias: state.shouldAntialias
            )
        }

        drawTexture(
            textureView,
            in: rect,
            alpha: alpha,
            blendMode: blendMode,
            interpolationQuality: effectiveInterpolationQuality,
            target: target,
            clipPaths: state.clipPaths,
            imageMaskClips: state.imageMaskClips,
            shouldAntialias: state.shouldAntialias
        )
    }

    func draw(
        layer: CGLayer,
        in rect: CGRect,
        alpha: CGFloat,
        blendMode: CGBlendMode,
        interpolationQuality: CGInterpolationQuality,
        state: CGDrawingState
    ) {
        guard let target = effectiveRenderTarget,
              let sourceRenderer = layer.context?.rendererDelegate as? CGWebGPUContextRenderer else {
            return
        }
        sourceRenderer.resolveMSAAIfNeeded()
        guard let sourceTextureView = sourceRenderer.effectiveRenderTarget else { return }

        drawTexture(
            sourceTextureView,
            in: rect,
            alpha: alpha,
            blendMode: blendMode,
            interpolationQuality: interpolationQuality,
            target: target,
            clipPaths: state.clipPaths,
            imageMaskClips: state.imageMaskClips,
            shouldAntialias: state.shouldAntialias
        )
    }

    func drawLinearGradient(
        _ gradient: CGGradient,
        start: CGPoint,
        end: CGPoint,
        options: CGGradientDrawingOptions,
        state: CGDrawingState
    ) {
        guard let target = effectiveRenderTarget,
              let convertedGradient = state.convertedGradient(gradient) else { return }

        let vertices = createLinearGradientVertices(
            gradient: convertedGradient,
            start: start,
            end: end,
            options: options,
            alpha: 1.0
        )
        guard !vertices.isEmpty else { return }

        let batch = CGWebGPUVertexBatch(vertices: vertices)

        renderStatefulBatch(batch, to: target, blendMode: .normal, state: state)
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
        guard let target = effectiveRenderTarget,
              let convertedGradient = state.convertedGradient(gradient) else { return }

        let vertices = createRadialGradientVertices(
            gradient: convertedGradient,
            startCenter: startCenter,
            startRadius: startRadius,
            endCenter: endCenter,
            endRadius: endRadius,
            options: options,
            alpha: 1.0
        )
        guard !vertices.isEmpty else { return }

        let batch = CGWebGPUVertexBatch(vertices: vertices)

        renderStatefulBatch(batch, to: target, blendMode: .normal, state: state)
    }

    // MARK: - Shading Drawing

    func drawShading(
        _ shading: CGShading,
        alpha: CGFloat,
        blendMode: CGBlendMode
    ) {
        renderShading(shading, alpha: alpha, blendMode: blendMode, state: CGDrawingState())
    }

    func drawShading(
        _ shading: CGShading,
        alpha: CGFloat,
        blendMode: CGBlendMode,
        state: CGDrawingState
    ) {
        renderShading(shading, alpha: alpha, blendMode: blendMode, state: state)
    }

    private func renderShading(
        _ shading: CGShading,
        alpha: CGFloat,
        blendMode: CGBlendMode,
        state: CGDrawingState
    ) {
        guard let target = effectiveRenderTarget else { return }

        // Generate color stops from the shading function
        let sourceStops = shading.generateColorStops(steps: 64)
        guard !sourceStops.isEmpty else { return }
        var colorStops: [(location: CGFloat, color: CGColor)] = []
        colorStops.reserveCapacity(sourceStops.count)
        for stop in sourceStops {
            guard let color = state.convertedColor(stop.color) else { return }
            colorStops.append((location: stop.location, color: color))
        }

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
        renderStatefulBatch(batch, to: target, blendMode: blendMode, state: state)
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
            guard let firstColor = applyAlpha(firstStop.color, alpha: alpha) else { return [] }
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
            guard let color0 = applyAlpha(colorStops[i].color, alpha: alpha),
                  let color1 = applyAlpha(colorStops[i + 1].color, alpha: alpha) else {
                return []
            }

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
            guard let lastColor = applyAlpha(lastStop.color, alpha: alpha) else { return [] }
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
            guard let firstColor = applyAlpha(firstStop.color, alpha: alpha) else { return [] }

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
            guard let color0 = applyAlpha(colorStops[i].color, alpha: alpha),
                  let color1 = applyAlpha(colorStops[i + 1].color, alpha: alpha) else {
                return []
            }

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
            guard let lastColor = applyAlpha(lastStop.color, alpha: alpha) else { return [] }
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
            guard let firstColor = applyAlpha(colors[0], alpha: alpha) else { return [] }
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
            guard let color0 = applyAlpha(colors[i], alpha: alpha),
                  let color1 = applyAlpha(colors[i + 1], alpha: alpha) else {
                return []
            }

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
            guard let lastColor = applyAlpha(colors[colors.count - 1], alpha: alpha) else { return [] }
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
            guard let firstColor = applyAlpha(colors[0], alpha: alpha) else { return [] }

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
            guard let color0 = applyAlpha(colors[i], alpha: alpha),
                  let color1 = applyAlpha(colors[i + 1], alpha: alpha) else {
                return []
            }

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
            guard let lastColor = applyAlpha(colors[colors.count - 1], alpha: alpha) else { return [] }
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

    /// Fills a path with a callback-rendered pattern cell.
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
        renderPatternFill(
            path: path,
            pattern: pattern,
            patternSpace: patternSpace,
            colorComponents: colorComponents,
            patternPhase: patternPhase,
            alpha: alpha,
            blendMode: blendMode,
            rule: rule,
            state: CGDrawingState()
        )
    }

    func fillWithPattern(
        path: CGPath,
        pattern: CGPattern,
        patternSpace: CGColorSpace,
        colorComponents: [CGFloat]?,
        patternPhase: CGSize,
        alpha: CGFloat,
        blendMode: CGBlendMode,
        rule: CGPathFillRule,
        state: CGDrawingState
    ) {
        renderPatternFill(
            path: path,
            pattern: pattern,
            patternSpace: patternSpace,
            colorComponents: colorComponents,
            patternPhase: patternPhase,
            alpha: alpha,
            blendMode: blendMode,
            rule: rule,
            state: state
        )
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
        renderPatternStroke(
            path: path,
            pattern: pattern,
            patternSpace: patternSpace,
            colorComponents: colorComponents,
            patternPhase: patternPhase,
            lineWidth: lineWidth,
            lineCap: lineCap,
            lineJoin: lineJoin,
            miterLimit: miterLimit,
            alpha: alpha,
            blendMode: blendMode,
            state: CGDrawingState()
        )
    }

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
        blendMode: CGBlendMode,
        state: CGDrawingState
    ) {
        renderPatternStroke(
            path: path,
            pattern: pattern,
            patternSpace: patternSpace,
            colorComponents: colorComponents,
            patternPhase: patternPhase,
            lineWidth: lineWidth,
            lineCap: lineCap,
            lineJoin: lineJoin,
            miterLimit: miterLimit,
            alpha: alpha,
            blendMode: blendMode,
            state: state
        )
    }

    // MARK: - Private Helpers

    private func renderStatefulBatch(
        _ batch: CGWebGPUVertexBatch,
        to target: GPUTextureView,
        blendMode: CGBlendMode,
        state: CGDrawingState
    ) {
        let usesMSAA = state.shouldAntialias && renderTarget == nil
        let sampleCount = usesMSAA ? msaaSampleCount : 1
        pipelineRegistry.setSampleCount(sampleCount)
        defer { pipelineRegistry.setSampleCount(1) }

        let pipeline: GPURenderPipeline
        let bindGroup: GPUBindGroup?
        if state.hasImageMaskClipping {
            guard let maskTextureView = imageMaskTextureView(for: state.imageMaskClips),
                  let maskedPipeline = getMaskedPipeline(
                      for: blendMode,
                      pathClipped: state.hasPathClipping
                  ) else {
                return
            }
            pipeline = maskedPipeline
            bindGroup = device.createBindGroup(descriptor: GPUBindGroupDescriptor(
                layout: pipeline.getBindGroupLayout(index: 0),
                entries: [
                    GPUBindGroupEntry(binding: 0, resource: .textureView(maskTextureView))
                ]
            ))
        } else {
            let selectedPipeline = state.hasPathClipping
                ? getClippedPipeline(for: blendMode)
                : getPipeline(for: blendMode)
            guard let selectedPipeline = selectedPipeline else { return }
            pipeline = selectedPipeline
            bindGroup = nil
        }

        if usesMSAA {
            if state.hasPathClipping {
                renderBatchWithMSAAAndClipping(
                    batch,
                    to: target,
                    clippedPipeline: pipeline,
                    clipPaths: state.clipPaths,
                    bindGroup: bindGroup
                )
            } else {
                renderBatchWithMSAA(batch, to: target, pipeline: pipeline, bindGroup: bindGroup)
            }
        } else if state.hasPathClipping {
            renderBatchWithClipping(
                batch,
                to: target,
                pipeline: pipeline,
                clipPaths: state.clipPaths,
                bindGroup: bindGroup
            )
        } else {
            renderBatch(batch, to: target, pipeline: pipeline, bindGroup: bindGroup)
        }
    }

    private func renderPatternFill(
        path: CGPath,
        pattern: CGPattern,
        patternSpace: CGColorSpace,
        colorComponents: [CGFloat]?,
        patternPhase: CGSize,
        alpha: CGFloat,
        blendMode: CGBlendMode,
        rule: CGPathFillRule,
        state: CGDrawingState
    ) {
        guard let tint = patternTintColor(
            pattern: pattern,
            components: colorComponents,
            colorSpace: patternSpace,
            state: state
        ) else {
            return
        }
        let batch = tessellator.tessellateFill(path, color: tint, rule: rule)
        renderPatternBatch(
            batch,
            pattern: pattern,
            patternPhase: patternPhase,
            alpha: alpha,
            blendMode: blendMode,
            state: state
        )
    }

    private func renderPatternStroke(
        path: CGPath,
        pattern: CGPattern,
        patternSpace: CGColorSpace,
        colorComponents: [CGFloat]?,
        patternPhase: CGSize,
        lineWidth: CGFloat,
        lineCap: CGLineCap,
        lineJoin: CGLineJoin,
        miterLimit: CGFloat,
        alpha: CGFloat,
        blendMode: CGBlendMode,
        state: CGDrawingState
    ) {
        guard let tint = patternTintColor(
            pattern: pattern,
            components: colorComponents,
            colorSpace: patternSpace,
            state: state
        ) else {
            return
        }
        let batch = tessellator.tessellateStroke(
            path,
            color: tint,
            lineWidth: lineWidth,
            lineCap: convertLineCap(lineCap),
            lineJoin: convertLineJoin(lineJoin),
            miterLimit: miterLimit
        )
        renderPatternBatch(
            batch,
            pattern: pattern,
            patternPhase: patternPhase,
            alpha: alpha,
            blendMode: blendMode,
            state: state
        )
    }

    private func renderPatternBatch(
        _ batch: CGWebGPUVertexBatch,
        pattern: CGPattern,
        patternPhase: CGSize,
        alpha: CGFloat,
        blendMode: CGBlendMode,
        state: CGDrawingState
    ) {
        let usesMSAA = state.shouldAntialias && renderTarget == nil
        pipelineRegistry.setSampleCount(usesMSAA ? msaaSampleCount : 1)
        defer { pipelineRegistry.setSampleCount(1) }

        guard !batch.vertices.isEmpty,
              let target = effectiveRenderTarget,
              let sampler = pattern.tiling == .noDistortion ? nearestSampler : linearSampler,
              let cell = patternCell(for: pattern),
              let maskTextureView = imageMaskTextureView(for: state.imageMaskClips),
              let uniforms = createPatternUniformBuffer(
                  pattern: pattern,
                  patternPhase: patternPhase,
                  alpha: alpha,
                  state: state
              ) else {
            return
        }

        let clipped = state.hasPathClipping
        guard let pipeline = getPatternPipeline(for: blendMode, clipped: clipped) else { return }

        let renderTargetView: GPUTextureView
        let stencilView: GPUTextureView?
        if usesMSAA, let msaaView = msaaRenderTextureView {
            renderTargetView = msaaView
            stencilView = msaaStencilTextureView
        } else {
            renderTargetView = target
            stencilView = stencilTextureView
        }

        let bindGroup = device.createBindGroup(descriptor: GPUBindGroupDescriptor(
            layout: pipeline.getBindGroupLayout(index: 0),
            entries: [
                GPUBindGroupEntry(binding: 0, resource: .sampler(sampler)),
                GPUBindGroupEntry(binding: 1, resource: .textureView(cell.textureView)),
                GPUBindGroupEntry(binding: 2, resource: .bufferBinding(GPUBufferBinding(buffer: uniforms)))
            ]
        ))
        let maskBindGroup = device.createBindGroup(descriptor: GPUBindGroupDescriptor(
            layout: pipeline.getBindGroupLayout(index: 1),
            entries: [
                GPUBindGroupEntry(binding: 0, resource: .textureView(maskTextureView))
            ]
        ))

        renderBatchWithPattern(
            batch,
            to: renderTargetView,
            pipeline: pipeline,
            bindGroup: bindGroup,
            maskBindGroup: maskBindGroup,
            clipPaths: state.clipPaths,
            stencilView: stencilView
        )
        if usesMSAA {
            needsMSAAResolve = true
        }
    }

    private func patternTintColor(
        pattern: CGPattern,
        components: [CGFloat]?,
        colorSpace: CGColorSpace,
        state: CGDrawingState
    ) -> CGColor? {
        if pattern.isColored {
            // The cell supplies all visible color; the vertex tint is ignored by
            // the colored-pattern shader and only needs a valid destination shape.
            let components = Array(
                repeating: CGFloat.zero,
                count: state.destinationColorSpace.numberOfComponents
            ) + [1]
            return CGColor(space: state.destinationColorSpace, componentArray: components)
        }
        guard let baseSpace = colorSpace.baseColorSpace,
              let components,
              components.count == baseSpace.numberOfComponents + 1 else {
            return nil
        }
        let source = CGColor(space: baseSpace, componentArray: components)
        return state.convertedColor(source)
    }

    private func patternCell(for pattern: CGPattern) -> PatternCell? {
        let key = ObjectIdentifier(pattern)
        if let cached = patternCells[key] {
            return cached
        }
        guard !activePatternCells.contains(key),
              pattern.bounds.width > 0,
              pattern.bounds.height > 0 else {
            return nil
        }

        activePatternCells.insert(key)
        defer { activePatternCells.remove(key) }

        let width = max(1, Int(ceil(pattern.bounds.width)))
        let height = max(1, Int(ceil(pattern.bounds.height)))
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: width * 4,
                  space: colorSpace,
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
              ),
              let renderer = context.rendererDelegate as? CGWebGPUContextRenderer else {
            return nil
        }

        context.scaleBy(
            x: CGFloat(width) / pattern.bounds.width,
            y: CGFloat(height) / pattern.bounds.height
        )
        context.translateBy(x: -pattern.bounds.minX, y: -pattern.bounds.minY)
        context.clip(to: pattern.bounds)
        pattern.draw(in: context)

        renderer.resolveMSAAIfNeeded()
        guard let textureView = renderer.effectiveRenderTarget else { return nil }

        let cell = PatternCell(pattern: pattern, context: context, textureView: textureView)
        patternCells[key] = cell
        return cell
    }

    private func imageMaskTextureView(for clips: [CGImageMaskClip]) -> GPUTextureView? {
        if cachedImageMaskClips == clips {
            return imageMaskTextureView
        }
        guard let texture = imageMaskTexture,
              let textureView = imageMaskTextureView else {
            return nil
        }

        let width = Int(max(1, viewportWidth))
        let height = Int(max(1, viewportHeight))
        let pixelData: Data
        if clips.isEmpty {
            pixelData = Data(repeating: 255, count: width * height * 4)
        } else {
            guard let buffer = CGImageMaskBuffer(width: width, height: height, clips: clips) else {
                return nil
            }
            pixelData = buffer.rgba8
        }

        let bytes = [UInt8](pixelData)
        let typedArray = JSTypedArray<UInt8>(bytes)
        queue.writeTexture(
            destination: GPUImageCopyTexture(texture: texture),
            data: typedArray.jsObject,
            dataLayout: GPUImageDataLayout(
                offset: 0,
                bytesPerRow: UInt32(width * 4),
                rowsPerImage: UInt32(height)
            ),
            size: GPUExtent3D(width: UInt32(width), height: UInt32(height))
        )
        cachedImageMaskClips = clips
        return textureView
    }

    /// Resolves MSAA content to the internal render texture if there's pending MSAA content.
    private func resolveMSAAIfNeeded() {
        guard needsMSAAResolve,
              let msaaView = msaaRenderTextureView,
              let targetView = internalRenderTextureView else {
            return
        }

        let encoder = device.createCommandEncoder()

        // Create a resolve render pass that copies MSAA content to the target
        let colorAttachment = GPURenderPassColorAttachment(
            view: msaaView,
            resolveTarget: targetView,
            loadOp: .load,      // Load existing MSAA content
            storeOp: .discard   // Discard MSAA after resolve
        )

        let renderPass = encoder.beginRenderPass(descriptor: GPURenderPassDescriptor(
            colorAttachments: [colorAttachment]
        ))
        // Empty render pass - just triggers the resolve
        renderPass.end()

        queue.submit([encoder.finish()])
        needsMSAAResolve = false
    }

    private func renderBatch(
        _ batch: CGWebGPUVertexBatch,
        to textureView: GPUTextureView,
        pipeline: GPURenderPipeline,
        bindGroup: GPUBindGroup? = nil
    ) {
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
        if let bindGroup = bindGroup {
            renderPass.setBindGroup(0, bindGroup: bindGroup)
        }
        renderPass.setVertexBuffer(0, buffer: allocation.buffer, offset: allocation.offset)
        renderPass.draw(vertexCount: UInt32(batch.vertices.count))
        renderPass.end()

        queue.submit([encoder.finish()])
    }

    private func renderImage(
        vertexBuffer: GPUBuffer,
        bindGroup: GPUBindGroup,
        vertexCount: UInt32,
        to textureView: GPUTextureView,
        pipeline: GPURenderPipeline,
        maskBindGroup: GPUBindGroup? = nil
    ) {
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
        if let maskBindGroup = maskBindGroup {
            renderPass.setBindGroup(1, bindGroup: maskBindGroup)
        }
        renderPass.setVertexBuffer(0, buffer: vertexBuffer)
        renderPass.draw(vertexCount: vertexCount)
        renderPass.end()

        queue.submit([encoder.finish()])
    }

    private func renderImageWithClipping(
        vertexBuffer: GPUBuffer,
        bindGroup: GPUBindGroup,
        vertexCount: UInt32,
        to textureView: GPUTextureView,
        pipeline: GPURenderPipeline,
        clipPaths: [CGClipPath],
        stencilView: GPUTextureView?,
        maskBindGroup: GPUBindGroup? = nil
    ) {
        guard let stencilView = stencilView,
              let stencilPipeline = getStencilWritePipeline(),
              !clipPaths.isEmpty else {
            renderImage(
                vertexBuffer: vertexBuffer,
                bindGroup: bindGroup,
                vertexCount: vertexCount,
                to: textureView,
                pipeline: pipeline,
                maskBindGroup: maskBindGroup
            )
            return
        }

        let encoder = device.createCommandEncoder()

        let stencilClearAttachment = GPURenderPassDepthStencilAttachment(
            view: stencilView,
            depthClearValue: 1.0,
            depthLoadOp: .clear,
            depthStoreOp: .store,
            stencilClearValue: 0,
            stencilLoadOp: .clear,
            stencilStoreOp: .store
        )

        let colorAttachment = GPURenderPassColorAttachment(
            view: textureView,
            loadOp: .load,
            storeOp: .store
        )

        let stencilPass = encoder.beginRenderPass(descriptor: GPURenderPassDescriptor(
            colorAttachments: [colorAttachment],
            depthStencilAttachment: stencilClearAttachment
        ))

        stencilPass.setPipeline(stencilPipeline)
        for (index, clipPath) in clipPaths.enumerated() {
            let clipBatch = tessellator.tessellateFill(clipPath.path, color: .black, rule: clipPath.rule)
            guard !clipBatch.vertices.isEmpty else { continue }
            let clipBuffer = createVertexBuffer(from: clipBatch)
            stencilPass.setVertexBuffer(0, buffer: clipBuffer)
            stencilPass.setStencilReference(UInt32(index))
            stencilPass.draw(vertexCount: UInt32(clipBatch.vertices.count))
        }
        stencilPass.end()

        let stencilTestAttachment = GPURenderPassDepthStencilAttachment(
            view: stencilView,
            depthLoadOp: .load,
            depthStoreOp: .store,
            stencilLoadOp: .load,
            stencilStoreOp: .store
        )

        let contentPass = encoder.beginRenderPass(descriptor: GPURenderPassDescriptor(
            colorAttachments: [colorAttachment],
            depthStencilAttachment: stencilTestAttachment
        ))

        contentPass.setPipeline(pipeline)
        contentPass.setBindGroup(0, bindGroup: bindGroup)
        if let maskBindGroup = maskBindGroup {
            contentPass.setBindGroup(1, bindGroup: maskBindGroup)
        }
        contentPass.setVertexBuffer(0, buffer: vertexBuffer)
        contentPass.setStencilReference(UInt32(clipPaths.count))
        contentPass.draw(vertexCount: vertexCount)
        contentPass.end()

        queue.submit([encoder.finish()])
    }

    /// Renders a batch with MSAA (multi-sample anti-aliasing).
    ///
    /// This method renders to the MSAA texture. The MSAA content is accumulated
    /// across multiple draw calls and resolved to the target only when makeImage is called.
    private func renderBatchWithMSAA(
        _ batch: CGWebGPUVertexBatch,
        to textureView: GPUTextureView,
        pipeline: GPURenderPipeline,
        bindGroup: GPUBindGroup? = nil
    ) {
        guard let msaaView = msaaRenderTextureView,
              let allocation = createVertexBufferAllocation(from: batch) else {
            // Fall back to non-MSAA rendering if MSAA textures are not available
            renderBatch(batch, to: textureView, pipeline: pipeline)
            return
        }

        let encoder = device.createCommandEncoder()

        // MSAA color attachment: render to MSAA texture, keep content for accumulation
        // Note: We don't resolve here - resolution happens in makeImage/resolveMSAA
        let colorAttachment = GPURenderPassColorAttachment(
            view: msaaView,
            loadOp: .load,
            storeOp: .store  // Store MSAA texture content for next draw
        )

        let renderPass = encoder.beginRenderPass(descriptor: GPURenderPassDescriptor(
            colorAttachments: [colorAttachment]
        ))

        renderPass.setPipeline(pipeline)
        if let bindGroup = bindGroup {
            renderPass.setBindGroup(0, bindGroup: bindGroup)
        }
        renderPass.setVertexBuffer(0, buffer: allocation.buffer, offset: allocation.offset)
        renderPass.draw(vertexCount: UInt32(batch.vertices.count))
        renderPass.end()

        queue.submit([encoder.finish()])

        // Mark that MSAA content needs to be resolved
        needsMSAAResolve = true
    }

    /// Renders a batch with MSAA and clipping applied using stencil buffer.
    ///
    /// - Note: The caller must have already set the sampleCount on pipelineRegistry
    ///   and obtained the clippedPipeline with MSAA enabled.
    private func renderBatchWithMSAAAndClipping(
        _ batch: CGWebGPUVertexBatch,
        to textureView: GPUTextureView,
        clippedPipeline: GPURenderPipeline,
        clipPaths: [CGClipPath],
        bindGroup: GPUBindGroup? = nil
    ) {
        guard let msaaView = msaaRenderTextureView,
              let msaaStencilView = msaaStencilTextureView,
              let stencilPipeline = getStencilWritePipeline(),
              !clipPaths.isEmpty else {
            // Fall back to non-MSAA clipping if MSAA textures are not available
            renderBatchWithClipping(
                batch,
                to: textureView,
                pipeline: clippedPipeline,
                clipPaths: clipPaths,
                bindGroup: bindGroup
            )
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
            loadOp: .load,
            storeOp: .store  // Store MSAA content for next pass
        )

        // First render pass: write clip paths to stencil
        let stencilPass = encoder.beginRenderPass(descriptor: GPURenderPassDescriptor(
            colorAttachments: [colorLoadAttachment],
            depthStencilAttachment: stencilClearAttachment
        ))

        stencilPass.setPipeline(stencilPipeline)

        // Tessellate and render each clip path
        for (index, clipPath) in clipPaths.enumerated() {
            let clipBatch = tessellator.tessellateFill(clipPath.path, color: .black, rule: clipPath.rule)
            if !clipBatch.vertices.isEmpty {
                let clipBuffer = createVertexBuffer(from: clipBatch)
                stencilPass.setVertexBuffer(0, buffer: clipBuffer)
                stencilPass.setStencilReference(UInt32(index))
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
            loadOp: .load,
            storeOp: .store  // Store MSAA content for accumulation
        )

        let contentPass = encoder.beginRenderPass(descriptor: GPURenderPassDescriptor(
            colorAttachments: [colorStoreAttachment],
            depthStencilAttachment: stencilTestAttachment
        ))

        // Use the passed clipped pipeline (already has correct blend mode and MSAA sample count)
        contentPass.setPipeline(clippedPipeline)
        if let bindGroup = bindGroup {
            contentPass.setBindGroup(0, bindGroup: bindGroup)
        }
        contentPass.setVertexBuffer(0, buffer: contentBuffer)
        contentPass.setStencilReference(UInt32(clipPaths.count))
        contentPass.draw(vertexCount: UInt32(batch.vertices.count))
        contentPass.end()

        queue.submit([encoder.finish()])

        // Mark that MSAA content needs to be resolved
        needsMSAAResolve = true
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
        clipPaths: [CGClipPath],
        bindGroup: GPUBindGroup? = nil
    ) {
        guard let stencilView = stencilTextureView,
              let stencilPipeline = getStencilWritePipeline(),
              !clipPaths.isEmpty else {
            // Fall back to regular rendering if no stencil available
            renderBatch(batch, to: textureView, pipeline: pipeline, bindGroup: bindGroup)
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
        for (index, clipPath) in clipPaths.enumerated() {
            let clipBatch = tessellator.tessellateFill(clipPath.path, color: .black, rule: clipPath.rule)
            if !clipBatch.vertices.isEmpty {
                let clipBuffer = createVertexBuffer(from: clipBatch)
                stencilPass.setVertexBuffer(0, buffer: clipBuffer)
                stencilPass.setStencilReference(UInt32(index))
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
        if let bindGroup = bindGroup {
            contentPass.setBindGroup(0, bindGroup: bindGroup)
        }
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
        clipPaths: [CGClipPath],
        shouldAntialias: Bool
    ) {
        pipelineRegistry.setSampleCount(1)
        guard let normalPipeline = getPipeline(for: .copy) else { return }
        let shadowBuffer = createVertexBuffer(from: batch)

        renderShadowMask(
            to: textureView,
            shadowColor: shadowColor,
            shadowOffset: shadowOffset,
            shadowBlur: shadowBlur,
            shouldAntialias: shouldAntialias
        ) { maskPass in
            maskPass.setPipeline(normalPipeline)
            maskPass.setVertexBuffer(0, buffer: shadowBuffer)
            maskPass.draw(vertexCount: UInt32(batch.vertices.count))
        }
    }

    /// Renders an image's actual alpha channel into the shadow mask before blur.
    /// Transparent source pixels therefore produce no shadow coverage.
    private func renderTextureShadow(
        textureView: GPUTextureView,
        in rect: CGRect,
        alpha: CGFloat,
        interpolationQuality: CGInterpolationQuality,
        to target: GPUTextureView,
        shadowColor: CGColor,
        shadowOffset: CGSize,
        shadowBlur: CGFloat,
        shouldAntialias: Bool
    ) {
        pipelineRegistry.setSampleCount(1)
        guard let pipeline = getImagePipeline(for: .copy),
              let sampler = interpolationQuality == .none ? nearestSampler : linearSampler else {
            return
        }

        let vertexBuffer = createImageVertexBuffer(from: createImageQuadVertices(rect: rect))
        let uniformBuffer = createImageUniformBuffer(alpha: alpha)
        let bindGroup = device.createBindGroup(descriptor: GPUBindGroupDescriptor(
            layout: pipeline.getBindGroupLayout(index: 0),
            entries: [
                GPUBindGroupEntry(binding: 0, resource: .sampler(sampler)),
                GPUBindGroupEntry(binding: 1, resource: .textureView(textureView)),
                GPUBindGroupEntry(binding: 2, resource: .bufferBinding(GPUBufferBinding(buffer: uniformBuffer)))
            ]
        ))

        renderShadowMask(
            to: target,
            shadowColor: shadowColor,
            shadowOffset: shadowOffset,
            shadowBlur: shadowBlur,
            shouldAntialias: shouldAntialias
        ) { maskPass in
            maskPass.setPipeline(pipeline)
            maskPass.setBindGroup(0, bindGroup: bindGroup)
            maskPass.setVertexBuffer(0, buffer: vertexBuffer)
            maskPass.draw(vertexCount: 6)
        }
    }

    /// Runs the shared mask, blur, and composite passes for every shadow source.
    private func renderShadowMask(
        to textureView: GPUTextureView,
        shadowColor: CGColor,
        shadowOffset: CGSize,
        shadowBlur: CGFloat,
        shouldAntialias: Bool,
        encodeMask: (GPURenderPassEncoder) -> Void
    ) {
        guard let shadowMaskView = shadowMaskTextureView,
              let blurIntermediateView = blurIntermediateTextureView,
              let blurHPipeline = getBlurHorizontalPipeline(),
              let blurVPipeline = getBlurVerticalPipeline(),
              let sampler = linearSampler,
              let shadowUniforms = createShadowUniformBuffer(
                shadowColor: shadowColor,
                offset: shadowOffset
              ) else { return }

        let usesMSAA = shouldAntialias && renderTarget == nil
        pipelineRegistry.setSampleCount(usesMSAA ? msaaSampleCount : 1)
        defer { pipelineRegistry.setSampleCount(1) }
        guard let shadowPipeline = getShadowCompositePipeline() else { return }
        let compositeTarget = usesMSAA ? msaaRenderTextureView ?? textureView : textureView

        let encoder = device.createCommandEncoder()

        // Pass 1: Render source alpha to shadow mask
        let maskClearAttachment = GPURenderPassColorAttachment(
            view: shadowMaskView,
            clearValue: GPUColor(r: 0, g: 0, b: 0, a: 0),
            loadOp: .clear,
            storeOp: .store
        )

        let maskPass = encoder.beginRenderPass(descriptor: GPURenderPassDescriptor(
            colorAttachments: [maskClearAttachment]
        ))
        encodeMask(maskPass)
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
        let shadowBindGroup = device.createBindGroup(descriptor: GPUBindGroupDescriptor(
            layout: shadowPipeline.getBindGroupLayout(index: 0),
            entries: [
                GPUBindGroupEntry(binding: 0, resource: .sampler(sampler)),
                GPUBindGroupEntry(binding: 1, resource: .textureView(shadowMaskView)),
                GPUBindGroupEntry(binding: 2, resource: .bufferBinding(GPUBufferBinding(buffer: shadowUniforms)))
            ]
        ))

        let compositeAttachment = GPURenderPassColorAttachment(
            view: compositeTarget,
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
        if usesMSAA {
            needsMSAAResolve = true
        }
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
    private func createShadowUniformBuffer(shadowColor: CGColor, offset: CGSize) -> GPUBuffer? {
        guard let components = shadowColor.components, components.count == 4 else { return nil }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        let a = Float(components[3])

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

    private func applyAlpha(_ color: CGColor, alpha: CGFloat) -> CGColor? {
        guard let colorSpace = color.colorSpace,
              var components = color.components,
              components.count == colorSpace.numberOfComponents + 1 else {
            return nil
        }
        components[components.count - 1] *= alpha
        return CGColor(space: colorSpace, componentArray: components)
    }

    /// Creates uniforms that map device coordinates back into pattern space.
    private func createPatternUniformBuffer(
        pattern: CGPattern,
        patternPhase: CGSize,
        alpha: CGFloat,
        state: CGDrawingState
    ) -> GPUBuffer? {
        let phaseTransform = CGAffineTransform(
            translationX: patternPhase.width,
            y: patternPhase.height
        )
        let patternToDevice = pattern.matrix
            .concatenating(phaseTransform)
            .concatenating(state.ctm)
        let determinant = patternToDevice.a * patternToDevice.d - patternToDevice.b * patternToDevice.c
        guard determinant != 0 else { return nil }
        let inverse = patternToDevice.inverted()

        let data: [Float] = [
            Float(inverse.a), Float(inverse.b), Float(inverse.c), Float(inverse.d),
            Float(inverse.tx), Float(inverse.ty),
            Float(viewportWidth), Float(viewportHeight),
            Float(pattern.bounds.minX), Float(pattern.bounds.minY),
            Float(pattern.bounds.width), Float(pattern.bounds.height),
            Float(abs(pattern.xStep)), Float(abs(pattern.yStep)),
            Float(alpha), pattern.isColored ? 1.0 : 0.0
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
        bindGroup: GPUBindGroup,
        maskBindGroup: GPUBindGroup,
        clipPaths: [CGClipPath],
        stencilView: GPUTextureView?
    ) {
        let buffer = createVertexBuffer(from: batch)

        guard !clipPaths.isEmpty else {
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
            renderPass.setBindGroup(1, bindGroup: maskBindGroup)
            renderPass.setVertexBuffer(0, buffer: buffer)
            renderPass.draw(vertexCount: UInt32(batch.vertices.count))
            renderPass.end()
            queue.submit([encoder.finish()])
            return
        }

        guard let stencilView = stencilView,
              let stencilPipeline = getStencilWritePipeline() else { return }

        let encoder = device.createCommandEncoder()
        let colorAttachment = GPURenderPassColorAttachment(
            view: textureView,
            loadOp: .load,
            storeOp: .store
        )

        let stencilPass = encoder.beginRenderPass(descriptor: GPURenderPassDescriptor(
            colorAttachments: [colorAttachment],
            depthStencilAttachment: GPURenderPassDepthStencilAttachment(
                view: stencilView,
                depthClearValue: 1.0,
                depthLoadOp: .clear,
                depthStoreOp: .store,
                stencilClearValue: 0,
                stencilLoadOp: .clear,
                stencilStoreOp: .store
            )
        ))

        stencilPass.setPipeline(stencilPipeline)
        for (index, clipPath) in clipPaths.enumerated() {
            let clipBatch = tessellator.tessellateFill(clipPath.path, color: .black, rule: clipPath.rule)
            guard !clipBatch.vertices.isEmpty else { continue }
            let clipBuffer = createVertexBuffer(from: clipBatch)
            stencilPass.setVertexBuffer(0, buffer: clipBuffer)
            stencilPass.setStencilReference(UInt32(index))
            stencilPass.draw(vertexCount: UInt32(clipBatch.vertices.count))
        }
        stencilPass.end()

        let contentPass = encoder.beginRenderPass(descriptor: GPURenderPassDescriptor(
            colorAttachments: [colorAttachment],
            depthStencilAttachment: GPURenderPassDepthStencilAttachment(
                view: stencilView,
                depthLoadOp: .load,
                depthStoreOp: .store,
                stencilLoadOp: .load,
                stencilStoreOp: .store
            )
        ))
        contentPass.setPipeline(pipeline)
        contentPass.setBindGroup(0, bindGroup: bindGroup)
        contentPass.setBindGroup(1, bindGroup: maskBindGroup)
        contentPass.setVertexBuffer(0, buffer: buffer)
        contentPass.setStencilReference(UInt32(clipPaths.count))
        contentPass.draw(vertexCount: UInt32(batch.vertices.count))
        contentPass.end()

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
    private func getOrCreateTextureView(
        for image: CGImage,
        state: CGDrawingState
    ) -> GPUTextureView? {
        return textureManager.getOrCreateTexture(
            for: image,
            destinationColorSpace: state.destinationColorSpace,
            intent: state.resolvedRenderingIntent(forSampledImage: true)
        )
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

    private func drawTexture(
        _ textureView: GPUTextureView,
        in rect: CGRect,
        alpha: CGFloat,
        blendMode: CGBlendMode,
        interpolationQuality: CGInterpolationQuality,
        target: GPUTextureView,
        clipPaths: [CGClipPath],
        imageMaskClips: [CGImageMaskClip] = [],
        shouldAntialias: Bool
    ) {
        let usesMSAA = shouldAntialias && renderTarget == nil
        pipelineRegistry.setSampleCount(usesMSAA ? msaaSampleCount : 1)
        defer { pipelineRegistry.setSampleCount(1) }

        let usesPathClipping = !clipPaths.isEmpty
        let usesImageMaskClipping = !imageMaskClips.isEmpty
        let selectedPipeline = usesImageMaskClipping
            ? getMaskedImagePipeline(for: blendMode, pathClipped: usesPathClipping)
            : getImagePipeline(for: blendMode, clipped: usesPathClipping)
        guard let pipeline = selectedPipeline,
              let sampler = interpolationQuality == .none ? nearestSampler : linearSampler else {
            return
        }

        let vertexBuffer = createImageVertexBuffer(from: createImageQuadVertices(rect: rect))
        let uniformBuffer = createImageUniformBuffer(alpha: alpha)
        let bindGroup = device.createBindGroup(descriptor: GPUBindGroupDescriptor(
            layout: pipeline.getBindGroupLayout(index: 0),
            entries: [
                GPUBindGroupEntry(binding: 0, resource: .sampler(sampler)),
                GPUBindGroupEntry(binding: 1, resource: .textureView(textureView)),
                GPUBindGroupEntry(binding: 2, resource: .bufferBinding(GPUBufferBinding(buffer: uniformBuffer)))
            ]
        ))
        let maskBindGroup: GPUBindGroup?
        if usesImageMaskClipping {
            guard let maskTextureView = imageMaskTextureView(for: imageMaskClips) else { return }
            maskBindGroup = device.createBindGroup(descriptor: GPUBindGroupDescriptor(
                layout: pipeline.getBindGroupLayout(index: 1),
                entries: [
                    GPUBindGroupEntry(binding: 0, resource: .textureView(maskTextureView))
                ]
            ))
        } else {
            maskBindGroup = nil
        }

        let renderTargetView: GPUTextureView
        let stencilView: GPUTextureView?
        if usesMSAA, let msaaView = msaaRenderTextureView {
            renderTargetView = msaaView
            stencilView = msaaStencilTextureView
        } else {
            renderTargetView = target
            stencilView = stencilTextureView
        }

        if usesPathClipping {
            renderImageWithClipping(
                vertexBuffer: vertexBuffer,
                bindGroup: bindGroup,
                vertexCount: 6,
                to: renderTargetView,
                pipeline: pipeline,
                clipPaths: clipPaths,
                stencilView: stencilView,
                maskBindGroup: maskBindGroup
            )
        } else {
            renderImage(
                vertexBuffer: vertexBuffer,
                bindGroup: bindGroup,
                vertexCount: 6,
                to: renderTargetView,
                pipeline: pipeline,
                maskBindGroup: maskBindGroup
            )
        }
        if usesMSAA {
            needsMSAAResolve = true
        }
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
        // WGSL aligns the vec3 field to 16 bytes, so ImageUniforms occupies
        // 32 bytes even though the alpha itself is a single float.
        let data: [Float] = [Float(alpha), 0, 0, 0, 0, 0, 0, 0]

        let buffer = device.createBuffer(descriptor: GPUBufferDescriptor(
            size: UInt64(data.count * MemoryLayout<Float>.stride),
            usage: [.uniform, .copyDst],
            label: "Image Uniforms"
        ))

        let jsArray = JSTypedArray<Float32>(data)
        queue.writeBuffer(buffer, bufferOffset: 0, data: jsArray.jsObject)

        return buffer
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
        // Resolve MSAA content to the internal render texture if needed
        resolveMSAAIfNeeded()

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
        resolveMSAAIfNeeded()

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

        guard let adapter = await gpu.requestAdapter() else {
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
