//
//  BufferPool.swift
//  CGWebGPU
//
//  Internal ring buffer pool for efficient vertex buffer allocation.
//

#if arch(wasm32)
import Foundation
import SwiftWebGPU
import JavaScriptKit

/// Internal vertex buffer pool using ring buffer pattern.
///
/// Maintains reusable GPU buffers organized as a ring that rotates each frame,
/// preventing GPU/CPU synchronization stalls.
internal final class BufferPool: @unchecked Sendable {

    // MARK: - Types

    /// A buffer allocation from the pool.
    struct Allocation {
        /// The GPU buffer
        let buffer: GPUBuffer

        /// Offset within the buffer (bytes)
        let offset: UInt64

        /// Size of this allocation (bytes)
        let size: UInt64
    }

    /// Pool configuration.
    struct Configuration {
        /// Number of buffer sets (frames in flight)
        var frameCount: Int = 3

        /// Initial buffer size per frame (bytes)
        var initialBufferSize: Int = 1024 * 1024  // 1 MB

        /// Maximum buffer size (bytes)
        var maxBufferSize: Int = 64 * 1024 * 1024  // 64 MB

        /// Growth factor when buffer is too small
        var growthFactor: Double = 2.0

        init() {}
    }

    // MARK: - Properties

    private let device: GPUDevice
    private let config: Configuration

    /// Buffer for each frame in flight
    private var buffers: [GPUBuffer]

    /// Current write offset for each frame
    private var writeOffsets: [UInt64]

    /// Buffer size for each frame
    private var bufferSizes: [Int]

    /// Current frame index in the ring
    private var currentFrame: Int = 0

    /// Allocations this frame (for statistics)
    private var frameAllocations: Int = 0

    // MARK: - Initialization

    /// Creates a new buffer pool.
    ///
    /// - Parameters:
    ///   - device: The WebGPU device
    ///   - configuration: Pool configuration
    init(device: GPUDevice, configuration: Configuration = Configuration()) {
        self.device = device
        self.config = configuration

        // Initialize buffers for each frame
        self.buffers = []
        self.writeOffsets = []
        self.bufferSizes = []

        for _ in 0..<config.frameCount {
            let buffer = createBuffer(size: config.initialBufferSize)
            buffers.append(buffer)
            writeOffsets.append(0)
            bufferSizes.append(config.initialBufferSize)
        }
    }

    // MARK: - Frame Management

    /// Advances to the next frame in the ring.
    ///
    /// Call at the beginning of each frame to reset the write offset
    /// and switch to the next buffer set.
    func advanceFrame() {
        currentFrame = (currentFrame + 1) % config.frameCount
        writeOffsets[currentFrame] = 0
        frameAllocations = 0
    }

    // MARK: - Buffer Allocation

    /// Acquires a buffer allocation for the specified size.
    ///
    /// - Parameter size: Required size in bytes
    /// - Returns: Buffer allocation, or nil if failed
    func acquire(size: Int) -> Allocation? {
        guard size > 0 else { return nil }

        let alignedSize = alignSize(size)
        let currentOffset = writeOffsets[currentFrame]

        // Check if current buffer has enough space
        if currentOffset + UInt64(alignedSize) <= UInt64(bufferSizes[currentFrame]) {
            let buffer = buffers[currentFrame]
            writeOffsets[currentFrame] = currentOffset + UInt64(alignedSize)
            frameAllocations += 1

            return Allocation(
                buffer: buffer,
                offset: currentOffset,
                size: UInt64(alignedSize)
            )
        }

        // Need to grow the buffer
        if !growBuffer(toFit: alignedSize) {
            return nil
        }

        // Retry with new buffer
        return acquire(size: size)
    }

    /// Acquires a buffer and writes float data.
    ///
    /// - Parameter data: Float array to write
    /// - Returns: Buffer allocation, or nil if failed
    func acquireAndWrite(data: [Float]) -> Allocation? {
        let byteSize = data.count * MemoryLayout<Float>.stride

        guard let allocation = acquire(size: byteSize) else {
            return nil
        }

        writeData(data, to: allocation.buffer, offset: allocation.offset)
        return allocation
    }

    // MARK: - Private Methods

    private func createBuffer(size: Int) -> GPUBuffer {
        return device.createBuffer(descriptor: GPUBufferDescriptor(
            size: UInt64(size),
            usage: [.vertex, .copyDst],
            label: "BufferPool (\(size) bytes)"
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
            return false
        }

        // Create new buffer
        let newBuffer = createBuffer(size: newSize)
        buffers[currentFrame] = newBuffer
        bufferSizes[currentFrame] = newSize
        writeOffsets[currentFrame] = 0

        return true
    }

    private func alignSize(_ size: Int) -> Int {
        // Align to 4 bytes (WebGPU minimum)
        return (size + 3) & ~3
    }

    private func writeData(_ data: [Float], to buffer: GPUBuffer, offset: UInt64) {
        let floatArray = JSTypedArray<Float>(data)
        device.queue.writeBuffer(
            buffer,
            bufferOffset: offset,
            data: floatArray.jsObject
        )
    }

    // MARK: - Statistics

    /// Current frame index.
    var currentFrameIndex: Int { currentFrame }

    /// Allocations this frame.
    var allocationsThisFrame: Int { frameAllocations }

    /// Current frame buffer usage.
    var currentFrameUsage: (used: UInt64, capacity: Int) {
        (writeOffsets[currentFrame], bufferSizes[currentFrame])
    }

    /// Total memory allocated across all frames.
    var totalMemoryAllocated: Int {
        bufferSizes.reduce(0, +)
    }
}

#endif
