//
//  PipelineRegistry.swift
//  CGWebGPU
//
//  Internal pipeline caching and management.
//

#if arch(wasm32)
import Foundation
import OpenCoreGraphics
import SwiftWebGPU

/// Internal pipeline registry for CGWebGPUContextRenderer.
///
/// Manages WebGPU render pipelines with caching and optional pre-warming.
internal final class PipelineRegistry: @unchecked Sendable {

    // MARK: - Types

    /// Pipeline type identifier.
    enum PipelineType: Hashable {
        case blend(CGBlendMode)
        case clipped(CGBlendMode)
        case stencilWrite
        case image
        case pattern
        case blurHorizontal
        case blurVertical
        case shadowComposite
    }

    // MARK: - Properties

    private let device: GPUDevice
    private let textureFormat: GPUTextureFormat
    private let depthStencilFormat: GPUTextureFormat = .depth24plusStencil8

    private var pipelines: [PipelineType: GPURenderPipeline] = [:]
    private var shaderModules: [String: GPUShaderModule] = [:]
    private var isWarmedUp: Bool = false

    // MARK: - Initialization

    init(device: GPUDevice, textureFormat: GPUTextureFormat) {
        self.device = device
        self.textureFormat = textureFormat
    }

    // MARK: - Warm-up

    /// Pre-creates commonly used pipelines.
    func warmUp() {
        guard !isWarmedUp else { return }

        createShaderModules()

        let supportedModes: [CGBlendMode] = [
            .normal, .copy, .sourceIn, .sourceOut, .sourceAtop,
            .destinationOver, .destinationIn, .destinationOut, .destinationAtop,
            .xor, .plusLighter, .darken, .lighten
        ]

        for mode in supportedModes {
            pipelines[.blend(mode)] = createBlendPipeline(for: mode)
            pipelines[.clipped(mode)] = createClippedPipeline(for: mode)
        }

        pipelines[.stencilWrite] = createStencilWritePipeline()
        pipelines[.image] = createImagePipeline()
        pipelines[.pattern] = createPatternPipeline()
        pipelines[.blurHorizontal] = createBlurHorizontalPipeline()
        pipelines[.blurVertical] = createBlurVerticalPipeline()
        pipelines[.shadowComposite] = createShadowCompositePipeline()

        isWarmedUp = true
    }

    // MARK: - Pipeline Access

    func getPipeline(for mode: CGBlendMode) -> GPURenderPipeline? {
        let key = PipelineType.blend(mode)
        if let existing = pipelines[key] {
            return existing
        }

        ensureShaderModulesCreated()

        let pipeline = createBlendPipeline(for: mode)
        if let pipeline = pipeline {
            pipelines[key] = pipeline
        }
        return pipeline
    }

    func getClippedPipeline(for mode: CGBlendMode) -> GPURenderPipeline? {
        let key = PipelineType.clipped(mode)
        if let existing = pipelines[key] {
            return existing
        }

        ensureShaderModulesCreated()

        let pipeline = createClippedPipeline(for: mode)
        if let pipeline = pipeline {
            pipelines[key] = pipeline
        }
        return pipeline
    }

    func getPipeline(_ type: PipelineType) -> GPURenderPipeline? {
        if let existing = pipelines[type] {
            return existing
        }

        ensureShaderModulesCreated()

        let pipeline: GPURenderPipeline?
        switch type {
        case .blend(let mode):
            pipeline = createBlendPipeline(for: mode)
        case .clipped(let mode):
            pipeline = createClippedPipeline(for: mode)
        case .stencilWrite:
            pipeline = createStencilWritePipeline()
        case .image:
            pipeline = createImagePipeline()
        case .pattern:
            pipeline = createPatternPipeline()
        case .blurHorizontal:
            pipeline = createBlurHorizontalPipeline()
        case .blurVertical:
            pipeline = createBlurVerticalPipeline()
        case .shadowComposite:
            pipeline = createShadowCompositePipeline()
        }

        if let pipeline = pipeline {
            pipelines[type] = pipeline
        }
        return pipeline
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
            fragment: GPUFragmentState(
                module: module,
                entryPoint: "fs_main",
                targets: [GPUColorTargetState(format: textureFormat, blend: createBlendState(for: blendMode))]
            ),
            label: "Blend Pipeline (\(blendMode))"
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
            fragment: GPUFragmentState(
                module: module,
                entryPoint: "fs_main",
                targets: [GPUColorTargetState(format: textureFormat, blend: createBlendState(for: blendMode))]
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
