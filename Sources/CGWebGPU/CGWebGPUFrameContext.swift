//
//  CGWebGPUFrameContext.swift
//  CGWebGPU
//
//  Frame-based command batching for efficient WebGPU rendering.
//

#if arch(wasm32)
import Foundation
import OpenCoreGraphics
import SwiftWebGPU

/// A draw command representing a single rendering operation.
///
/// Commands are collected during a frame and executed in a single batch
/// for optimal GPU performance.
public enum CGWebGPUDrawCommand: Sendable {
    /// Fill a path with a solid color
    case fill(vertices: [Float], pipeline: PipelineKey, clipPaths: [[Float]]?)

    /// Stroke a path
    case stroke(vertices: [Float], pipeline: PipelineKey, clipPaths: [[Float]]?)

    /// Draw an image
    case image(vertices: [Float], textureID: ObjectIdentifier, alpha: Float)

    /// Draw a linear gradient
    case linearGradient(vertices: [Float])

    /// Draw a radial gradient
    case radialGradient(vertices: [Float])

    /// Draw with a pattern
    case pattern(vertices: [Float], patternUniforms: [Float])

    /// Clear a region
    case clear(vertices: [Float])

    /// Begin a transparency layer
    case beginTransparencyLayer(bounds: CGRect?)

    /// End a transparency layer
    case endTransparencyLayer(alpha: Float, blendMode: Int)

    /// Render shadow for the accumulated commands
    case shadow(vertices: [Float], color: [Float], offset: CGSize, blur: Float)
}

/// Identifies a specific pipeline configuration.
public struct PipelineKey: Hashable, Sendable {
    public let blendMode: CGBlendMode
    public let hasClipping: Bool
    public let hasStencil: Bool

    public init(blendMode: CGBlendMode, hasClipping: Bool = false, hasStencil: Bool = false) {
        self.blendMode = blendMode
        self.hasClipping = hasClipping
        self.hasStencil = hasStencil
    }

    /// Convenience initializer for normal blend mode
    public static var normal: PipelineKey {
        return PipelineKey(blendMode: .normal)
    }
}

/// Manages a single frame's worth of draw commands.
///
/// `CGWebGPUFrameContext` provides the following benefits:
///
/// ## Command Batching
/// Instead of submitting GPU commands immediately, drawing operations are
/// collected into a batch. This allows for:
/// - Reduced command encoder creation overhead
/// - Minimized state changes between draw calls
/// - Optimized vertex buffer allocation
///
/// ## Usage
///
/// ```swift
/// // Begin a new frame
/// let frame = frameContext.beginFrame()
///
/// // Record draw commands
/// frame.addFill(vertices: [...], pipeline: .normal)
/// frame.addStroke(vertices: [...], pipeline: .normal)
///
/// // Submit all commands at once
/// frame.endFrame()
/// ```
public final class CGWebGPUFrameContext: @unchecked Sendable {

    // MARK: - Properties

    /// Accumulated draw commands for this frame
    private var commands: [CGWebGPUDrawCommand] = []

    /// Total vertex count for the frame (for buffer allocation)
    private var totalVertexCount: Int = 0

    /// Whether a frame is currently active
    private var isFrameActive: Bool = false

    /// Weak reference to the vertex buffer pool
    private weak var vertexBufferPool: CGWebGPUVertexBufferPool?

    /// Frame index for ring buffer management
    private var frameIndex: UInt64 = 0

    // MARK: - Initialization

    public init(vertexBufferPool: CGWebGPUVertexBufferPool? = nil) {
        self.vertexBufferPool = vertexBufferPool
    }

    // MARK: - Frame Lifecycle

    /// Begins a new frame.
    ///
    /// This clears any pending commands and prepares for a new batch of draw operations.
    public func beginFrame() {
        guard !isFrameActive else {
            print("Warning: beginFrame called while frame is already active")
            return
        }

        commands.removeAll(keepingCapacity: true)
        totalVertexCount = 0
        isFrameActive = true
        frameIndex += 1
    }

    /// Ends the current frame and returns accumulated commands.
    ///
    /// - Returns: Array of draw commands to be executed
    public func endFrame() -> [CGWebGPUDrawCommand] {
        guard isFrameActive else {
            print("Warning: endFrame called without active frame")
            return []
        }

        isFrameActive = false
        let result = commands

        // Notify buffer pool that frame is complete
        vertexBufferPool?.advanceFrame()

        return result
    }

    /// Whether a frame is currently active.
    public var isActive: Bool {
        return isFrameActive
    }

    /// Current frame index.
    public var currentFrameIndex: UInt64 {
        return frameIndex
    }

    // MARK: - Command Recording

    /// Adds a fill command.
    public func addFill(
        vertices: [Float],
        pipeline: PipelineKey,
        clipPaths: [[Float]]? = nil
    ) {
        guard isFrameActive else { return }

        commands.append(.fill(vertices: vertices, pipeline: pipeline, clipPaths: clipPaths))
        totalVertexCount += vertices.count / 6  // 6 floats per vertex
    }

    /// Adds a stroke command.
    public func addStroke(
        vertices: [Float],
        pipeline: PipelineKey,
        clipPaths: [[Float]]? = nil
    ) {
        guard isFrameActive else { return }

        commands.append(.stroke(vertices: vertices, pipeline: pipeline, clipPaths: clipPaths))
        totalVertexCount += vertices.count / 6
    }

    /// Adds an image draw command.
    public func addImage(
        vertices: [Float],
        textureID: ObjectIdentifier,
        alpha: Float
    ) {
        guard isFrameActive else { return }

        commands.append(.image(vertices: vertices, textureID: textureID, alpha: alpha))
        // Image vertices have 4 floats per vertex (position(2) + texCoord(2))
        totalVertexCount += vertices.count / 4
    }

    /// Adds a linear gradient command.
    public func addLinearGradient(vertices: [Float]) {
        guard isFrameActive else { return }

        commands.append(.linearGradient(vertices: vertices))
        totalVertexCount += vertices.count / 6
    }

    /// Adds a radial gradient command.
    public func addRadialGradient(vertices: [Float]) {
        guard isFrameActive else { return }

        commands.append(.radialGradient(vertices: vertices))
        totalVertexCount += vertices.count / 6
    }

    /// Adds a pattern fill command.
    public func addPattern(vertices: [Float], patternUniforms: [Float]) {
        guard isFrameActive else { return }

        commands.append(.pattern(vertices: vertices, patternUniforms: patternUniforms))
        totalVertexCount += vertices.count / 6
    }

    /// Adds a clear command.
    public func addClear(vertices: [Float]) {
        guard isFrameActive else { return }

        commands.append(.clear(vertices: vertices))
        totalVertexCount += vertices.count / 6
    }

    /// Adds a transparency layer begin command.
    public func addBeginTransparencyLayer(bounds: CGRect?) {
        guard isFrameActive else { return }

        commands.append(.beginTransparencyLayer(bounds: bounds))
    }

    /// Adds a transparency layer end command.
    public func addEndTransparencyLayer(alpha: Float, blendMode: Int) {
        guard isFrameActive else { return }

        commands.append(.endTransparencyLayer(alpha: alpha, blendMode: blendMode))
    }

    /// Adds a shadow command.
    public func addShadow(
        vertices: [Float],
        color: [Float],
        offset: CGSize,
        blur: Float
    ) {
        guard isFrameActive else { return }

        commands.append(.shadow(vertices: vertices, color: color, offset: offset, blur: blur))
        totalVertexCount += vertices.count / 6
    }

    // MARK: - Statistics

    /// Returns the total vertex count for this frame.
    public var vertexCount: Int {
        return totalVertexCount
    }

    /// Returns the number of commands in this frame.
    public var commandCount: Int {
        return commands.count
    }

    /// Returns estimated buffer size needed for vertices.
    public var estimatedVertexBufferSize: Int {
        return totalVertexCount * 6 * MemoryLayout<Float>.stride
    }
}

// MARK: - Frame Statistics

/// Statistics about a completed frame.
public struct CGWebGPUFrameStats: Sendable {
    /// Number of draw commands executed
    public let commandCount: Int

    /// Total vertices processed
    public let vertexCount: Int

    /// Number of state changes (pipeline switches)
    public let stateChanges: Int

    /// Frame index
    public let frameIndex: UInt64

    public init(
        commandCount: Int,
        vertexCount: Int,
        stateChanges: Int,
        frameIndex: UInt64
    ) {
        self.commandCount = commandCount
        self.vertexCount = vertexCount
        self.stateChanges = stateChanges
        self.frameIndex = frameIndex
    }
}

#endif
