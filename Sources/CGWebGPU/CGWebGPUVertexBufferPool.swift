//
//  CGWebGPUVertexBufferPool.swift
//  CGWebGPU
//
//  Ring buffer pool for efficient vertex buffer allocation.
//

#if arch(wasm32)
import Foundation
import SwiftWebGPU
import JavaScriptKit

/// A pool of vertex buffers using a ring buffer pattern.
///
/// Creating GPU buffers per draw call is expensive. This pool maintains a set of
/// reusable buffers organized as a ring buffer that rotates each frame.
///
/// ## Ring Buffer Pattern
///
/// The pool uses N sets of buffers (where N = frame latency, typically 2-3).
/// Each frame uses a different set, allowing the GPU to read from buffers
/// while the CPU writes to the next frame's buffers.
///
/// ```
/// Frame 0: [Buffer Set 0] ← CPU writes
///          [Buffer Set 1] ← GPU reads
///          [Buffer Set 2] ← Free
///
/// Frame 1: [Buffer Set 0] ← Free
///          [Buffer Set 1] ← CPU writes
///          [Buffer Set 2] ← GPU reads
/// ```
///
/// ## Usage
///
/// ```swift
/// let pool = CGWebGPUVertexBufferPool(device: device)
///
/// // At frame start
/// pool.advanceFrame()
///
/// // During rendering
/// let buffer = pool.acquireBuffer(size: vertexDataSize)
/// buffer.write(vertexData)
/// renderPass.setVertexBuffer(0, buffer: buffer)
/// ```
public final class CGWebGPUVertexBufferPool: @unchecked Sendable {

    // MARK: - Types

    /// A buffer allocation from the pool.
    public struct BufferAllocation {
        /// The GPU buffer
        public let buffer: GPUBuffer

        /// Offset within the buffer
        public let offset: UInt64

        /// Size of this allocation
        public let size: UInt64
    }

    /// Configuration for the buffer pool.
    public struct Configuration {
        /// Number of buffer sets (frames in flight)
        public var frameCount: Int = 3

        /// Initial buffer size per frame (bytes)
        public var initialBufferSize: Int = 1024 * 1024  // 1 MB

        /// Maximum buffer size (bytes)
        public var maxBufferSize: Int = 64 * 1024 * 1024  // 64 MB

        /// Growth factor when buffer is too small
        public var growthFactor: Double = 2.0

        public init() {}
    }

    // MARK: - Properties

    private let device: GPUDevice
    private let config: Configuration

    /// Buffer sets for each frame in flight
    private var bufferSets: [[GPUBuffer]] = []

    /// Current write offset for each buffer set
    private var writeOffsets: [UInt64] = []

    /// Buffer sizes for each set
    private var bufferSizes: [Int] = []

    /// Current frame index in the ring
    private var currentFrame: Int = 0

    /// Total allocations this frame
    private var frameAllocations: Int = 0

    // MARK: - Initialization

    /// Creates a new vertex buffer pool.
    ///
    /// - Parameters:
    ///   - device: The WebGPU device
    ///   - configuration: Pool configuration
    public init(device: GPUDevice, configuration: Configuration = Configuration()) {
        self.device = device
        self.config = configuration

        // Initialize buffer sets
        for _ in 0..<config.frameCount {
            let buffer = createBuffer(size: config.initialBufferSize)
            bufferSets.append([buffer])
            writeOffsets.append(0)
            bufferSizes.append(config.initialBufferSize)
        }
    }

    // MARK: - Frame Management

    /// Advances to the next frame in the ring.
    ///
    /// Call this at the beginning of each frame to reset the current frame's
    /// write offset and switch to the next buffer set.
    public func advanceFrame() {
        currentFrame = (currentFrame + 1) % config.frameCount
        writeOffsets[currentFrame] = 0
        frameAllocations = 0
    }

    // MARK: - Buffer Allocation

    /// Acquires a buffer for vertex data.
    ///
    /// - Parameter size: Required size in bytes
    /// - Returns: A buffer allocation, or nil if allocation failed
    public func acquireBuffer(size: Int) -> BufferAllocation? {
        guard size > 0 else { return nil }

        let alignedSize = alignSize(size)
        let currentOffset = writeOffsets[currentFrame]

        // Check if current buffer has enough space
        if currentOffset + UInt64(alignedSize) <= UInt64(bufferSizes[currentFrame]) {
            // Use existing buffer
            let buffer = bufferSets[currentFrame][0]
            writeOffsets[currentFrame] = currentOffset + UInt64(alignedSize)
            frameAllocations += 1

            return BufferAllocation(
                buffer: buffer,
                offset: currentOffset,
                size: UInt64(alignedSize)
            )
        }

        // Need to grow the buffer
        if !growBuffer(toFit: alignedSize) {
            return nil
        }

        // Try again with new buffer
        return acquireBuffer(size: size)
    }

    /// Acquires a buffer and writes data to it.
    ///
    /// - Parameter data: The vertex data to write
    /// - Returns: The buffer allocation containing the buffer and offset, or nil
    public func acquireAndWrite(data: [Float]) -> BufferAllocation? {
        let byteSize = data.count * MemoryLayout<Float>.stride

        guard let allocation = acquireBuffer(size: byteSize) else {
            return nil
        }

        // Write data via queue
        writeDataToBuffer(data, buffer: allocation.buffer, offset: allocation.offset)

        return allocation
    }

    /// Writes vertex batch data directly to a buffer.
    ///
    /// - Parameter batch: The vertex batch to write
    /// - Returns: The buffer allocation containing the buffer and offset, or nil
    public func acquireAndWrite(batch: CGWebGPUVertexBatch) -> BufferAllocation? {
        let floatData = batch.toFloatArray()
        return acquireAndWrite(data: floatData)
    }

    // MARK: - Private Methods

    private func createBuffer(size: Int) -> GPUBuffer {
        return device.createBuffer(descriptor: GPUBufferDescriptor(
            size: UInt64(size),
            usage: [.vertex, .copyDst],
            label: "Vertex Buffer Pool (\(size) bytes)"
        ))
    }

    private func growBuffer(toFit requiredSize: Int) -> Bool {
        let currentSize = bufferSizes[currentFrame]
        var newSize = currentSize

        // Grow until we can fit
        while newSize < requiredSize && newSize < config.maxBufferSize {
            newSize = Int(Double(newSize) * config.growthFactor)
        }

        // Clamp to max
        newSize = min(newSize, config.maxBufferSize)

        if newSize < requiredSize {
            print("CGWebGPUVertexBufferPool: Cannot allocate \(requiredSize) bytes (max: \(config.maxBufferSize))")
            return false
        }

        // Create new buffer
        let newBuffer = createBuffer(size: newSize)
        bufferSets[currentFrame] = [newBuffer]
        bufferSizes[currentFrame] = newSize
        writeOffsets[currentFrame] = 0

        return true
    }

    private func alignSize(_ size: Int) -> Int {
        // Align to 4 bytes (minimum WebGPU alignment)
        return (size + 3) & ~3
    }

    private func writeDataToBuffer(_ data: [Float], buffer: GPUBuffer, offset: UInt64) {
        // Convert Float array to ArrayBuffer via JSTypedArray
        let floatArray = JSTypedArray<Float>(data)
        let queue = device.queue

        // Use writeBuffer with offset
        queue.writeBuffer(
            buffer,
            bufferOffset: offset,
            data: floatArray.jsObject
        )
    }

    // MARK: - Statistics

    /// Returns the current frame index.
    public var currentFrameIndex: Int {
        return currentFrame
    }

    /// Returns the number of allocations this frame.
    public var allocationsThisFrame: Int {
        return frameAllocations
    }

    /// Returns the current buffer usage for this frame.
    public var currentFrameUsage: (used: UInt64, total: Int) {
        return (writeOffsets[currentFrame], bufferSizes[currentFrame])
    }

    /// Returns statistics about the pool.
    public var statistics: PoolStatistics {
        var totalAllocated = 0
        for size in bufferSizes {
            totalAllocated += size
        }

        return PoolStatistics(
            frameCount: config.frameCount,
            currentFrame: currentFrame,
            totalMemoryAllocated: totalAllocated,
            currentFrameUsed: Int(writeOffsets[currentFrame]),
            currentFrameCapacity: bufferSizes[currentFrame],
            allocationsThisFrame: frameAllocations
        )
    }
}

// MARK: - Statistics

/// Statistics about the vertex buffer pool.
public struct PoolStatistics: Sendable {
    public let frameCount: Int
    public let currentFrame: Int
    public let totalMemoryAllocated: Int
    public let currentFrameUsed: Int
    public let currentFrameCapacity: Int
    public let allocationsThisFrame: Int

    public var currentFrameUtilization: Double {
        guard currentFrameCapacity > 0 else { return 0 }
        return Double(currentFrameUsed) / Double(currentFrameCapacity) * 100.0
    }
}

#endif
