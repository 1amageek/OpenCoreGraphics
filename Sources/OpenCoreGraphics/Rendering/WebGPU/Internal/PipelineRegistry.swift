//
//  PipelineRegistry.swift
//  CGWebGPU
//
//  Internal pipeline caching and management.
//

#if arch(wasm32)
import OpenCoreGraphicsSupport
import SwiftWebGPU

/// Internal pipeline registry for CGWebGPUContextRenderer.
///
/// Manages WebGPU render pipelines with demand-driven caching.
internal final class PipelineRegistry {

    // MARK: - Types

    /// Pipeline cache key including sample count for MSAA support.
    private struct PipelineCacheKey: Hashable {
        let type: PipelineType
        let sampleCount: Int
    }

    private struct PipelineCacheEntry {
        let key: PipelineCacheKey
        let pipeline: GPURenderPipeline
    }

    /// Pipeline type identifier.
    enum PipelineType: Hashable {
        case blend(CGBlendMode)
        case clipped(CGBlendMode)
        case maskedBlend(CGBlendMode, Bool)
        case stencilWrite
        case image(CGBlendMode, Bool)
        case maskedImage(CGBlendMode, Bool)
        case pattern(CGBlendMode, Bool)
        case blurHorizontal
        case blurVertical
        case shadowComposite
    }

    // MARK: - Properties

    private let device: GPUDevice
    private let textureFormat: GPUTextureFormat
    private let depthStencilFormat: GPUTextureFormat = .depth24plusStencil8

    /// Current sample count for MSAA. 1 = no MSAA, 4 = 4x MSAA.
    private(set) var sampleCount: Int

    private var pipelines: [PipelineCacheEntry] = []
    private var shaderModules: [String: GPUShaderModule] = [:]
    // MARK: - Initialization

    init(device: GPUDevice, textureFormat: GPUTextureFormat, sampleCount: Int = 1) {
        self.device = device
        self.textureFormat = textureFormat
        self.sampleCount = sampleCount
    }

    /// Updates the sample count for MSAA.
    /// Pipelines with the new sample count will be created on demand.
    func setSampleCount(_ count: Int) {
        self.sampleCount = count
    }

    // MARK: - Pipeline Access

    func getPipeline(for mode: CGBlendMode) -> GPURenderPipeline? {
        let key = PipelineCacheKey(type: .blend(mode), sampleCount: sampleCount)
        if let existing = cachedPipeline(for: key) {
            return existing
        }

        ensureShaderModulesCreated()

        let pipeline = createBlendPipeline(for: mode)
        if let pipeline {
            cache(pipeline, for: key)
        }
        return pipeline
    }

    func getClippedPipeline(for mode: CGBlendMode) -> GPURenderPipeline? {
        let key = PipelineCacheKey(type: .clipped(mode), sampleCount: sampleCount)
        if let existing = cachedPipeline(for: key) {
            return existing
        }

        ensureShaderModulesCreated()

        let pipeline = createClippedPipeline(for: mode)
        if let pipeline {
            cache(pipeline, for: key)
        }
        return pipeline
    }

    func getPipeline(_ type: PipelineType) -> GPURenderPipeline? {
        let key = PipelineCacheKey(type: type, sampleCount: sampleCount)
        if let existing = cachedPipeline(for: key) {
            return existing
        }

        ensureShaderModulesCreated()

        let pipeline: GPURenderPipeline?
        switch type {
        case .blend(let mode):
            pipeline = createBlendPipeline(for: mode)
        case .clipped(let mode):
            pipeline = createClippedPipeline(for: mode)
        case .maskedBlend(let mode, let clipped):
            pipeline = createMaskedBlendPipeline(for: mode, clipped: clipped)
        case .stencilWrite:
            pipeline = createStencilWritePipeline()
        case .image(let mode, let clipped):
            pipeline = createImagePipeline(for: mode, clipped: clipped)
        case .maskedImage(let mode, let clipped):
            pipeline = createMaskedImagePipeline(for: mode, clipped: clipped)
        case .pattern(let mode, let clipped):
            pipeline = createPatternPipeline(for: mode, clipped: clipped)
        case .blurHorizontal:
            pipeline = createBlurHorizontalPipeline()
        case .blurVertical:
            pipeline = createBlurVerticalPipeline()
        case .shadowComposite:
            pipeline = createShadowCompositePipeline()
        }

        if let pipeline {
            cache(pipeline, for: key)
        }
        return pipeline
    }

    private func cachedPipeline(
        for key: PipelineCacheKey
    ) -> GPURenderPipeline? {
        pipelines.first(where: { $0.key == key })?.pipeline
    }

    private func cache(
        _ pipeline: GPURenderPipeline,
        for key: PipelineCacheKey
    ) {
        if let index = pipelines.firstIndex(
            where: { $0.key == key }
        ) {
            pipelines[index] = PipelineCacheEntry(
                key: key,
                pipeline: pipeline
            )
            return
        }
        pipelines.append(
            PipelineCacheEntry(
                key: key,
                pipeline: pipeline
            )
        )
    }

    private func ensureShaderModulesCreated() {
        if shaderModules.isEmpty {
            createShaderModules()
        }
    }

    // MARK: - Shader Modules

    private func createShaderModules() {
        shaderModules["basic2D"] = device.createShaderModule(descriptor: GPUShaderModuleDescriptor(
            code: CGWebGPUShaders.simple2D,
            label: "Basic 2D Shader"
        ))

        shaderModules["texture2D"] = device.createShaderModule(descriptor: GPUShaderModuleDescriptor(
            code: CGWebGPUShaders.texture2D,
            label: "Texture 2D Shader"
        ))

        shaderModules["maskedBasic2D"] = device.createShaderModule(descriptor: GPUShaderModuleDescriptor(
            code: CGWebGPUShaders.maskedSimple2D,
            label: "Masked Basic 2D Shader"
        ))

        shaderModules["maskedTexture2D"] = device.createShaderModule(descriptor: GPUShaderModuleDescriptor(
            code: CGWebGPUShaders.maskedTexture2D,
            label: "Masked Texture 2D Shader"
        ))

        shaderModules["pattern"] = device.createShaderModule(descriptor: GPUShaderModuleDescriptor(
            code: CGWebGPUShaders.patternTiling,
            label: "Pattern Shader"
        ))

        shaderModules["blurH"] = device.createShaderModule(descriptor: GPUShaderModuleDescriptor(
            code: CGWebGPUShaders.blurHorizontal,
            label: "Blur Horizontal Shader"
        ))

        shaderModules["blurV"] = device.createShaderModule(descriptor: GPUShaderModuleDescriptor(
            code: CGWebGPUShaders.blurVertical,
            label: "Blur Vertical Shader"
        ))

        shaderModules["shadow"] = device.createShaderModule(descriptor: GPUShaderModuleDescriptor(
            code: CGWebGPUShaders.shadowComposite,
            label: "Shadow Composite Shader"
        ))
    }

    // MARK: - Pipeline Creation

    private func createBlendPipeline(for blendMode: CGBlendMode) -> GPURenderPipeline? {
        guard let module = shaderModules["basic2D"] else { return nil }

        return device.createRenderPipeline(descriptor: GPURenderPipelineDescriptor(
            vertex: GPUVertexState(
                module: module,
                entryPoint: "vs_main",
                buffers: [createVertexBufferLayout()]
            ),
            primitive: GPUPrimitiveState(topology: .triangleList, cullMode: .none),
            multisample: GPUMultisampleState(count: UInt32(sampleCount)),
            fragment: GPUFragmentState(
                module: module,
                entryPoint: "fs_main",
                targets: [GPUColorTargetState(format: textureFormat, blend: createBlendState(for: blendMode))]
            ),
            label: "Blend Pipeline (\(blendMode)) [MSAA \(sampleCount)x]"
        ))
    }

    private func createClippedPipeline(for blendMode: CGBlendMode) -> GPURenderPipeline? {
        guard let module = shaderModules["basic2D"] else { return nil }

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
            multisample: GPUMultisampleState(count: UInt32(sampleCount)),
            fragment: GPUFragmentState(
                module: module,
                entryPoint: "fs_main",
                targets: [GPUColorTargetState(format: textureFormat, blend: createBlendState(for: blendMode))]
            ),
            label: "Clipped Pipeline (\(blendMode)) [MSAA \(sampleCount)x]"
        ))
    }

    private func createStencilWritePipeline() -> GPURenderPipeline? {
        guard let module = shaderModules["basic2D"] else { return nil }

        let stencilState = GPUStencilFaceState(
            compare: .equal,
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
            multisample: GPUMultisampleState(count: UInt32(sampleCount)),
            fragment: GPUFragmentState(
                module: module,
                entryPoint: "fs_main",
                targets: [GPUColorTargetState(format: textureFormat, writeMask: [])]
            ),
            label: "Stencil Write Pipeline [MSAA \(sampleCount)x]"
        ))
    }

    private func createMaskedBlendPipeline(for blendMode: CGBlendMode, clipped: Bool) -> GPURenderPipeline? {
        guard let module = shaderModules["maskedBasic2D"] else { return nil }

        return device.createRenderPipeline(descriptor: GPURenderPipelineDescriptor(
            vertex: GPUVertexState(
                module: module,
                entryPoint: "vs_main",
                buffers: [createVertexBufferLayout()]
            ),
            primitive: GPUPrimitiveState(topology: .triangleList, cullMode: .none),
            depthStencil: clipped ? clippedDepthStencilState() : nil,
            multisample: GPUMultisampleState(count: UInt32(sampleCount)),
            fragment: GPUFragmentState(
                module: module,
                entryPoint: "fs_main",
                targets: [GPUColorTargetState(format: textureFormat, blend: createBlendState(for: blendMode))]
            ),
            label: "Masked Blend Pipeline (\(blendMode), clipped: \(clipped)) [MSAA \(sampleCount)x]"
        ))
    }

    private func createImagePipeline(for blendMode: CGBlendMode, clipped: Bool) -> GPURenderPipeline? {
        guard let module = shaderModules["texture2D"] else { return nil }

        let depthStencil: GPUDepthStencilState?
        if clipped {
            let stencilState = GPUStencilFaceState(
                compare: .equal,
                failOp: .keep,
                depthFailOp: .keep,
                passOp: .keep
            )
            depthStencil = GPUDepthStencilState(
                format: depthStencilFormat,
                depthWriteEnabled: false,
                depthCompare: .always,
                stencilFront: stencilState,
                stencilBack: stencilState,
                stencilReadMask: 0xFF,
                stencilWriteMask: 0x00
            )
        } else {
            depthStencil = nil
        }

        return device.createRenderPipeline(descriptor: GPURenderPipelineDescriptor(
            vertex: GPUVertexState(
                module: module,
                entryPoint: "vs_main",
                buffers: [createImageVertexBufferLayout()]
            ),
            primitive: GPUPrimitiveState(topology: .triangleList, cullMode: .none),
            depthStencil: depthStencil,
            multisample: GPUMultisampleState(count: UInt32(sampleCount)),
            fragment: GPUFragmentState(
                module: module,
                entryPoint: "fs_main",
                targets: [GPUColorTargetState(format: textureFormat, blend: createBlendState(for: blendMode))]
            ),
            label: "Image Pipeline (\(blendMode), clipped: \(clipped)) [MSAA \(sampleCount)x]"
        ))
    }

    private func createMaskedImagePipeline(for blendMode: CGBlendMode, clipped: Bool) -> GPURenderPipeline? {
        guard let module = shaderModules["maskedTexture2D"] else { return nil }

        return device.createRenderPipeline(descriptor: GPURenderPipelineDescriptor(
            vertex: GPUVertexState(
                module: module,
                entryPoint: "vs_main",
                buffers: [createImageVertexBufferLayout()]
            ),
            primitive: GPUPrimitiveState(topology: .triangleList, cullMode: .none),
            depthStencil: clipped ? clippedDepthStencilState() : nil,
            multisample: GPUMultisampleState(count: UInt32(sampleCount)),
            fragment: GPUFragmentState(
                module: module,
                entryPoint: "fs_main",
                targets: [GPUColorTargetState(format: textureFormat, blend: createBlendState(for: blendMode))]
            ),
            label: "Masked Image Pipeline (\(blendMode), clipped: \(clipped)) [MSAA \(sampleCount)x]"
        ))
    }

    private func clippedDepthStencilState() -> GPUDepthStencilState {
        let stencilState = GPUStencilFaceState(
            compare: .equal,
            failOp: .keep,
            depthFailOp: .keep,
            passOp: .keep
        )
        return GPUDepthStencilState(
            format: depthStencilFormat,
            depthWriteEnabled: false,
            depthCompare: .always,
            stencilFront: stencilState,
            stencilBack: stencilState,
            stencilReadMask: 0xFF,
            stencilWriteMask: 0x00
        )
    }

    private func createPatternPipeline(for blendMode: CGBlendMode, clipped: Bool) -> GPURenderPipeline? {
        guard let module = shaderModules["pattern"] else { return nil }

        let depthStencil: GPUDepthStencilState?
        if clipped {
            let stencilState = GPUStencilFaceState(
                compare: .equal,
                failOp: .keep,
                depthFailOp: .keep,
                passOp: .keep
            )
            depthStencil = GPUDepthStencilState(
                format: depthStencilFormat,
                depthWriteEnabled: false,
                depthCompare: .always,
                stencilFront: stencilState,
                stencilBack: stencilState,
                stencilReadMask: 0xFF,
                stencilWriteMask: 0x00
            )
        } else {
            depthStencil = nil
        }

        return device.createRenderPipeline(descriptor: GPURenderPipelineDescriptor(
            vertex: GPUVertexState(
                module: module,
                entryPoint: "vs_main",
                buffers: [createVertexBufferLayout()]
            ),
            primitive: GPUPrimitiveState(topology: .triangleList, cullMode: .none),
            depthStencil: depthStencil,
            multisample: GPUMultisampleState(count: UInt32(sampleCount)),
            fragment: GPUFragmentState(
                module: module,
                entryPoint: "fs_main",
                targets: [GPUColorTargetState(format: textureFormat, blend: createBlendState(for: blendMode))]
            ),
            label: "Pattern Pipeline (\(blendMode), clipped: \(clipped)) [MSAA \(sampleCount)x]"
        ))
    }

    private func createBlurHorizontalPipeline() -> GPURenderPipeline? {
        guard let module = shaderModules["blurH"] else { return nil }

        // Blur pipelines operate on intermediate textures, not MSAA textures
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

        // Blur pipelines operate on intermediate textures, not MSAA textures
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
            multisample: GPUMultisampleState(count: UInt32(sampleCount)),
            fragment: GPUFragmentState(
                module: module,
                entryPoint: "fs_main",
                targets: [GPUColorTargetState(format: textureFormat, blend: shadowBlend)]
            ),
            label: "Shadow Composite Pipeline [MSAA \(sampleCount)x]"
        ))
    }

    // MARK: - Helpers

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
            arrayStride: UInt64(MemoryLayout<Float>.stride * 4),
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
            return GPUBlendState(
                color: GPUBlendComponent(srcFactor: .srcAlpha, dstFactor: .oneMinusSrcAlpha, operation: .add),
                alpha: GPUBlendComponent(srcFactor: .one, dstFactor: .oneMinusSrcAlpha, operation: .add)
            )
        }
    }
}

#endif
