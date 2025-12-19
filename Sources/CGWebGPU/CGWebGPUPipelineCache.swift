//
//  CGWebGPUPipelineCache.swift
//  CGWebGPU
//
//  Pipeline caching with pre-warming for optimal GPU performance.
//

#if arch(wasm32)
import Foundation
import OpenCoreGraphics
import SwiftWebGPU

/// Caches WebGPU render pipelines for efficient reuse.
///
/// Pipeline creation is expensive in WebGPU. This cache provides:
/// - Pre-warming of commonly used pipelines at initialization
/// - On-demand creation and caching for less common configurations
/// - Efficient lookup using `PipelineKey`
///
/// ## Pre-warming
///
/// At initialization, the cache pre-creates pipelines for:
/// - All Porter-Duff blend modes with normal rendering
/// - All Porter-Duff blend modes with stencil-based clipping
/// - Stencil write pipeline for clip path rendering
/// - Image, gradient, pattern, shadow, and blur pipelines
///
/// ## Usage
///
/// ```swift
/// let cache = CGWebGPUPipelineCache(device: device, textureFormat: format)
/// cache.warmUp()  // Pre-create all pipelines
///
/// // Later, during rendering:
/// if let pipeline = cache.getPipeline(for: .normal) {
///     renderPass.setPipeline(pipeline)
/// }
/// ```
public final class CGWebGPUPipelineCache: @unchecked Sendable {

    // MARK: - Types

    /// Pipeline types supported by the cache.
    public enum PipelineType: Hashable, Sendable {
        /// Standard blend mode pipeline
        case blend(CGBlendMode)

        /// Blend mode pipeline with stencil test for clipping
        case clipped(CGBlendMode)

        /// Pipeline for writing to stencil buffer
        case stencilWrite

        /// Pipeline for image/texture rendering
        case image

        /// Pipeline for pattern rendering
        case pattern

        /// Horizontal blur pass
        case blurHorizontal

        /// Vertical blur pass
        case blurVertical

        /// Shadow composite pass
        case shadowComposite

        /// Blit pipeline for copying textures
        case blit
    }

    // MARK: - Properties

    private let device: GPUDevice
    private let textureFormat: GPUTextureFormat
    private let depthStencilFormat: GPUTextureFormat = .depth24plusStencil8

    /// Cached pipelines
    private var pipelines: [PipelineType: GPURenderPipeline] = [:]

    /// Shader modules (shared across pipelines)
    private var shaderModules: [String: GPUShaderModule] = [:]

    /// Whether warm-up has been performed
    private var isWarmedUp: Bool = false

    // MARK: - Initialization

    /// Creates a new pipeline cache.
    ///
    /// - Parameters:
    ///   - device: The WebGPU device for creating pipelines
    ///   - textureFormat: The render target texture format
    public init(device: GPUDevice, textureFormat: GPUTextureFormat) {
        self.device = device
        self.textureFormat = textureFormat
    }

    // MARK: - Warm-up

    /// Pre-creates all commonly used pipelines.
    ///
    /// Call this method during initialization to avoid pipeline creation
    /// latency during rendering. This is especially important for the first
    /// few frames where pipeline compilation could cause stuttering.
    public func warmUp() {
        guard !isWarmedUp else { return }

        // Create shader modules
        createShaderModules()

        // Pre-warm blend mode pipelines
        let supportedModes: [CGBlendMode] = [
            .normal, .copy, .sourceIn, .sourceOut, .sourceAtop,
            .destinationOver, .destinationIn, .destinationOut, .destinationAtop,
            .xor, .plusLighter, .darken, .lighten
        ]

        for mode in supportedModes {
            pipelines[.blend(mode)] = createBlendPipeline(for: mode)
            pipelines[.clipped(mode)] = createClippedPipeline(for: mode)
        }

        // Create utility pipelines
        pipelines[.stencilWrite] = createStencilWritePipeline()
        pipelines[.image] = createImagePipeline()
        pipelines[.pattern] = createPatternPipeline()
        pipelines[.blurHorizontal] = createBlurHorizontalPipeline()
        pipelines[.blurVertical] = createBlurVerticalPipeline()
        pipelines[.shadowComposite] = createShadowCompositePipeline()

        isWarmedUp = true
    }

    // MARK: - Pipeline Access

    /// Gets a pipeline for the specified blend mode.
    ///
    /// - Parameter mode: The blend mode
    /// - Returns: The cached pipeline, or nil if creation failed
    public func getPipeline(for mode: CGBlendMode) -> GPURenderPipeline? {
        let key = PipelineType.blend(mode)
        if let existing = pipelines[key] {
            return existing
        }

        // Ensure shader modules are created
        ensureShaderModulesCreated()

        // Create on demand
        let pipeline = createBlendPipeline(for: mode)
        if let pipeline = pipeline {
            pipelines[key] = pipeline
        }
        return pipeline
    }

    /// Gets a clipped pipeline for the specified blend mode.
    ///
    /// - Parameter mode: The blend mode
    /// - Returns: The cached pipeline, or nil if creation failed
    public func getClippedPipeline(for mode: CGBlendMode) -> GPURenderPipeline? {
        let key = PipelineType.clipped(mode)
        if let existing = pipelines[key] {
            return existing
        }

        // Ensure shader modules are created
        ensureShaderModulesCreated()

        // Create on demand
        let pipeline = createClippedPipeline(for: mode)
        if let pipeline = pipeline {
            pipelines[key] = pipeline
        }
        return pipeline
    }

    /// Ensures shader modules are created (called lazily if warmUp was not called).
    private func ensureShaderModulesCreated() {
        if shaderModules.isEmpty {
            createShaderModules()
        }
    }

    /// Gets a specialized pipeline.
    ///
    /// - Parameter type: The pipeline type
    /// - Returns: The cached pipeline, or nil if not available
    public func getPipeline(_ type: PipelineType) -> GPURenderPipeline? {
        return pipelines[type]
    }

    // MARK: - Shader Modules

    private func createShaderModules() {
        // Basic 2D shader
        shaderModules["basic2D"] = device.createShaderModule(descriptor: GPUShaderModuleDescriptor(
            code: CGWebGPUShaders.simple2D,
            label: "Basic 2D Shader"
        ))

        // Image shader
        shaderModules["texture2D"] = device.createShaderModule(descriptor: GPUShaderModuleDescriptor(
            code: CGWebGPUShaders.texture2D,
            label: "Texture 2D Shader"
        ))

        // Pattern shader
        shaderModules["pattern"] = device.createShaderModule(descriptor: GPUShaderModuleDescriptor(
            code: CGWebGPUShaders.patternTiling,
            label: "Pattern Shader"
        ))

        // Blur shaders
        shaderModules["blurH"] = device.createShaderModule(descriptor: GPUShaderModuleDescriptor(
            code: CGWebGPUShaders.blurHorizontal,
            label: "Blur Horizontal Shader"
        ))

        shaderModules["blurV"] = device.createShaderModule(descriptor: GPUShaderModuleDescriptor(
            code: CGWebGPUShaders.blurVertical,
            label: "Blur Vertical Shader"
        ))

        // Shadow composite shader
        shaderModules["shadow"] = device.createShaderModule(descriptor: GPUShaderModuleDescriptor(
            code: CGWebGPUShaders.shadowComposite,
            label: "Shadow Composite Shader"
        ))
    }

    // MARK: - Pipeline Creation

    private func createBlendPipeline(for blendMode: CGBlendMode) -> GPURenderPipeline? {
        guard let module = shaderModules["basic2D"] else { return nil }

        let blendState = createBlendState(for: blendMode)

        return device.createRenderPipeline(descriptor: GPURenderPipelineDescriptor(
            vertex: GPUVertexState(
                module: module,
                entryPoint: "vs_main",
                buffers: [createVertexBufferLayout()]
            ),
            primitive: GPUPrimitiveState(topology: .triangleList, cullMode: .none),
            fragment: GPUFragmentState(
                module: module,
                entryPoint: "fs_main",
                targets: [GPUColorTargetState(format: textureFormat, blend: blendState)]
            ),
            label: "Blend Pipeline (\(blendMode))"
        ))
    }

    private func createClippedPipeline(for blendMode: CGBlendMode) -> GPURenderPipeline? {
        guard let module = shaderModules["basic2D"] else { return nil }

        let blendState = createBlendState(for: blendMode)
        let stencilState = GPUStencilFaceState(
            compare: .equal,
            failOp: .keep,
            depthFailOp: .keep,
            passOp: .keep
        )

        return device.createRenderPipeline(descriptor: GPURenderPipelineDescriptor(
            vertex: GPUVertexState(
                module: module,
                entryPoint: "vs_main",
                buffers: [createVertexBufferLayout()]
            ),
            primitive: GPUPrimitiveState(topology: .triangleList, cullMode: .none),
            depthStencil: GPUDepthStencilState(
                format: depthStencilFormat,
                depthWriteEnabled: false,
                depthCompare: .always,
                stencilFront: stencilState,
                stencilBack: stencilState,
                stencilReadMask: 0xFF,
                stencilWriteMask: 0x00
            ),
            fragment: GPUFragmentState(
                module: module,
                entryPoint: "fs_main",
                targets: [GPUColorTargetState(format: textureFormat, blend: blendState)]
            ),
            label: "Clipped Pipeline (\(blendMode))"
        ))
    }

    private func createStencilWritePipeline() -> GPURenderPipeline? {
        guard let module = shaderModules["basic2D"] else { return nil }

        let stencilState = GPUStencilFaceState(
            compare: .always,
            failOp: .keep,
            depthFailOp: .keep,
            passOp: .incrementClamp
        )

        return device.createRenderPipeline(descriptor: GPURenderPipelineDescriptor(
            vertex: GPUVertexState(
                module: module,
                entryPoint: "vs_main",
                buffers: [createVertexBufferLayout()]
            ),
            primitive: GPUPrimitiveState(topology: .triangleList, cullMode: .none),
            depthStencil: GPUDepthStencilState(
                format: depthStencilFormat,
                depthWriteEnabled: false,
                depthCompare: .always,
                stencilFront: stencilState,
                stencilBack: stencilState,
                stencilReadMask: 0xFF,
                stencilWriteMask: 0xFF
            ),
            fragment: GPUFragmentState(
                module: module,
                entryPoint: "fs_main",
                targets: [GPUColorTargetState(format: textureFormat, writeMask: [])]
            ),
            label: "Stencil Write Pipeline"
        ))
    }

    private func createImagePipeline() -> GPURenderPipeline? {
        guard let module = shaderModules["texture2D"] else { return nil }

        let normalBlend = GPUBlendState(
            color: GPUBlendComponent(srcFactor: .srcAlpha, dstFactor: .oneMinusSrcAlpha, operation: .add),
            alpha: GPUBlendComponent(srcFactor: .one, dstFactor: .oneMinusSrcAlpha, operation: .add)
        )

        return device.createRenderPipeline(descriptor: GPURenderPipelineDescriptor(
            vertex: GPUVertexState(
                module: module,
                entryPoint: "vs_main",
                buffers: [createImageVertexBufferLayout()]
            ),
            primitive: GPUPrimitiveState(topology: .triangleList, cullMode: .none),
            fragment: GPUFragmentState(
                module: module,
                entryPoint: "fs_main",
                targets: [GPUColorTargetState(format: textureFormat, blend: normalBlend)]
            ),
            label: "Image Pipeline"
        ))
    }

    private func createPatternPipeline() -> GPURenderPipeline? {
        guard let module = shaderModules["pattern"] else { return nil }

        let normalBlend = GPUBlendState(
            color: GPUBlendComponent(srcFactor: .srcAlpha, dstFactor: .oneMinusSrcAlpha, operation: .add),
            alpha: GPUBlendComponent(srcFactor: .one, dstFactor: .oneMinusSrcAlpha, operation: .add)
        )

        return device.createRenderPipeline(descriptor: GPURenderPipelineDescriptor(
            vertex: GPUVertexState(
                module: module,
                entryPoint: "vs_main",
                buffers: [createVertexBufferLayout()]
            ),
            primitive: GPUPrimitiveState(topology: .triangleList, cullMode: .none),
            fragment: GPUFragmentState(
                module: module,
                entryPoint: "fs_main",
                targets: [GPUColorTargetState(format: textureFormat, blend: normalBlend)]
            ),
            label: "Pattern Pipeline"
        ))
    }

    private func createBlurHorizontalPipeline() -> GPURenderPipeline? {
        guard let module = shaderModules["blurH"] else { return nil }

        return device.createRenderPipeline(descriptor: GPURenderPipelineDescriptor(
            vertex: GPUVertexState(module: module, entryPoint: "vs_main"),
            primitive: GPUPrimitiveState(topology: .triangleList),
            fragment: GPUFragmentState(
                module: module,
                entryPoint: "fs_main",
                targets: [GPUColorTargetState(format: textureFormat)]
            ),
            label: "Blur Horizontal Pipeline"
        ))
    }

    private func createBlurVerticalPipeline() -> GPURenderPipeline? {
        guard let module = shaderModules["blurV"] else { return nil }

        return device.createRenderPipeline(descriptor: GPURenderPipelineDescriptor(
            vertex: GPUVertexState(module: module, entryPoint: "vs_main"),
            primitive: GPUPrimitiveState(topology: .triangleList),
            fragment: GPUFragmentState(
                module: module,
                entryPoint: "fs_main",
                targets: [GPUColorTargetState(format: textureFormat)]
            ),
            label: "Blur Vertical Pipeline"
        ))
    }

    private func createShadowCompositePipeline() -> GPURenderPipeline? {
        guard let module = shaderModules["shadow"] else { return nil }

        let shadowBlend = GPUBlendState(
            color: GPUBlendComponent(srcFactor: .srcAlpha, dstFactor: .oneMinusSrcAlpha, operation: .add),
            alpha: GPUBlendComponent(srcFactor: .one, dstFactor: .oneMinusSrcAlpha, operation: .add)
        )

        return device.createRenderPipeline(descriptor: GPURenderPipelineDescriptor(
            vertex: GPUVertexState(module: module, entryPoint: "vs_main"),
            primitive: GPUPrimitiveState(topology: .triangleList),
            fragment: GPUFragmentState(
                module: module,
                entryPoint: "fs_main",
                targets: [GPUColorTargetState(format: textureFormat, blend: shadowBlend)]
            ),
            label: "Shadow Composite Pipeline"
        ))
    }

    // MARK: - Helper Methods

    private func createVertexBufferLayout() -> GPUVertexBufferLayout {
        return GPUVertexBufferLayout(
            arrayStride: UInt64(CGWebGPUVertex.stride),
            attributes: [
                GPUVertexAttribute(format: .float32x2, offset: 0, shaderLocation: 0),
                GPUVertexAttribute(format: .float32x4, offset: UInt64(MemoryLayout<Float>.stride * 2), shaderLocation: 1)
            ]
        )
    }

    private func createImageVertexBufferLayout() -> GPUVertexBufferLayout {
        return GPUVertexBufferLayout(
            arrayStride: UInt64(MemoryLayout<Float>.stride * 4),  // position(2) + texCoord(2)
            attributes: [
                GPUVertexAttribute(format: .float32x2, offset: 0, shaderLocation: 0),
                GPUVertexAttribute(format: .float32x2, offset: UInt64(MemoryLayout<Float>.stride * 2), shaderLocation: 1)
            ]
        )
    }

    private func createBlendState(for mode: CGBlendMode) -> GPUBlendState {
        switch mode {
        case .normal:
            return GPUBlendState(
                color: GPUBlendComponent(srcFactor: .srcAlpha, dstFactor: .oneMinusSrcAlpha, operation: .add),
                alpha: GPUBlendComponent(srcFactor: .one, dstFactor: .oneMinusSrcAlpha, operation: .add)
            )
        case .copy:
            return GPUBlendState(
                color: GPUBlendComponent(srcFactor: .one, dstFactor: .zero, operation: .add),
                alpha: GPUBlendComponent(srcFactor: .one, dstFactor: .zero, operation: .add)
            )
        case .sourceIn:
            return GPUBlendState(
                color: GPUBlendComponent(srcFactor: .dstAlpha, dstFactor: .zero, operation: .add),
                alpha: GPUBlendComponent(srcFactor: .dstAlpha, dstFactor: .zero, operation: .add)
            )
        case .sourceOut:
            return GPUBlendState(
                color: GPUBlendComponent(srcFactor: .oneMinusDstAlpha, dstFactor: .zero, operation: .add),
                alpha: GPUBlendComponent(srcFactor: .oneMinusDstAlpha, dstFactor: .zero, operation: .add)
            )
        case .sourceAtop:
            return GPUBlendState(
                color: GPUBlendComponent(srcFactor: .dstAlpha, dstFactor: .oneMinusSrcAlpha, operation: .add),
                alpha: GPUBlendComponent(srcFactor: .dstAlpha, dstFactor: .oneMinusSrcAlpha, operation: .add)
            )
        case .destinationOver:
            return GPUBlendState(
                color: GPUBlendComponent(srcFactor: .oneMinusDstAlpha, dstFactor: .one, operation: .add),
                alpha: GPUBlendComponent(srcFactor: .oneMinusDstAlpha, dstFactor: .one, operation: .add)
            )
        case .destinationIn:
            return GPUBlendState(
                color: GPUBlendComponent(srcFactor: .zero, dstFactor: .srcAlpha, operation: .add),
                alpha: GPUBlendComponent(srcFactor: .zero, dstFactor: .srcAlpha, operation: .add)
            )
        case .destinationOut:
            return GPUBlendState(
                color: GPUBlendComponent(srcFactor: .zero, dstFactor: .oneMinusSrcAlpha, operation: .add),
                alpha: GPUBlendComponent(srcFactor: .zero, dstFactor: .oneMinusSrcAlpha, operation: .add)
            )
        case .destinationAtop:
            return GPUBlendState(
                color: GPUBlendComponent(srcFactor: .oneMinusDstAlpha, dstFactor: .srcAlpha, operation: .add),
                alpha: GPUBlendComponent(srcFactor: .oneMinusDstAlpha, dstFactor: .srcAlpha, operation: .add)
            )
        case .xor:
            return GPUBlendState(
                color: GPUBlendComponent(srcFactor: .oneMinusDstAlpha, dstFactor: .oneMinusSrcAlpha, operation: .add),
                alpha: GPUBlendComponent(srcFactor: .oneMinusDstAlpha, dstFactor: .oneMinusSrcAlpha, operation: .add)
            )
        case .plusLighter:
            return GPUBlendState(
                color: GPUBlendComponent(srcFactor: .one, dstFactor: .one, operation: .add),
                alpha: GPUBlendComponent(srcFactor: .one, dstFactor: .one, operation: .add)
            )
        case .darken:
            return GPUBlendState(
                color: GPUBlendComponent(srcFactor: .one, dstFactor: .one, operation: .min),
                alpha: GPUBlendComponent(srcFactor: .one, dstFactor: .one, operation: .min)
            )
        case .lighten:
            return GPUBlendState(
                color: GPUBlendComponent(srcFactor: .one, dstFactor: .one, operation: .max),
                alpha: GPUBlendComponent(srcFactor: .one, dstFactor: .one, operation: .max)
            )
        default:
            // Fall back to normal blending for unsupported modes
            return GPUBlendState(
                color: GPUBlendComponent(srcFactor: .srcAlpha, dstFactor: .oneMinusSrcAlpha, operation: .add),
                alpha: GPUBlendComponent(srcFactor: .one, dstFactor: .oneMinusSrcAlpha, operation: .add)
            )
        }
    }

    // MARK: - Statistics

    /// Returns the number of cached pipelines.
    public var pipelineCount: Int {
        return pipelines.count
    }

    /// Returns whether the cache has been warmed up.
    public var hasWarmedUp: Bool {
        return isWarmedUp
    }
}

#endif
