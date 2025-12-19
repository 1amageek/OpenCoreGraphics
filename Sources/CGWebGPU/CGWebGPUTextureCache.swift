//
//  CGWebGPUTextureCache.swift
//  CGWebGPU
//
//  LRU texture cache for CGImage textures.
//

#if arch(wasm32)
import Foundation
import OpenCoreGraphics
import SwiftWebGPU
import JavaScriptKit

/// LRU cache for CGImage textures.
///
/// Texture creation and upload is expensive. This cache maintains a mapping
/// from `CGImage` identity to GPU textures, with LRU eviction to manage memory.
///
/// ## Features
///
/// - **Identity-based lookup**: Uses `ObjectIdentifier` for O(1) cache lookup
/// - **LRU eviction**: Automatically evicts least recently used textures when
///   the cache reaches capacity
/// - **Memory tracking**: Tracks approximate GPU memory usage
///
/// ## Usage
///
/// ```swift
/// let cache = CGWebGPUTextureCache(device: device, capacity: 100)
///
/// // Get or create texture
/// if let texture = cache.getOrCreateTexture(for: image) {
///     // Use texture for rendering
/// }
///
/// // Clear cache when done
/// cache.clear()
/// ```
public final class CGWebGPUTextureCache: @unchecked Sendable {

    // MARK: - Types

    /// Entry in the texture cache.
    private struct CacheEntry {
        let texture: GPUTexture
        let textureView: GPUTextureView
        let width: Int
        let height: Int
        var lastAccess: UInt64

        var memorySize: Int {
            // RGBA8 = 4 bytes per pixel
            return width * height * 4
        }
    }

    // MARK: - Properties

    private let device: GPUDevice
    private let queue: GPUQueue

    /// Maximum number of textures to cache
    private let capacity: Int

    /// Cached textures by image identity
    private var cache: [ObjectIdentifier: CacheEntry] = [:]

    /// Access order for LRU eviction
    private var accessOrder: [ObjectIdentifier] = []

    /// Current access counter
    private var accessCounter: UInt64 = 0

    /// Approximate total memory usage
    public private(set) var totalMemoryUsage: Int = 0

    /// Maximum memory usage before forced eviction (bytes)
    public var maxMemoryUsage: Int = 256 * 1024 * 1024  // 256 MB default

    // MARK: - Initialization

    /// Creates a new texture cache.
    ///
    /// - Parameters:
    ///   - device: The WebGPU device for creating textures
    ///   - capacity: Maximum number of textures to cache (default: 100)
    public init(device: GPUDevice, capacity: Int = 100) {
        self.device = device
        self.queue = device.queue
        self.capacity = capacity
    }

    // MARK: - Texture Access

    /// Gets an existing texture for an image, or nil if not cached.
    ///
    /// - Parameter image: The source image
    /// - Returns: The cached texture view, or nil
    public func getTexture(for image: CGImage) -> GPUTextureView? {
        let key = ObjectIdentifier(image)

        guard var entry = cache[key] else {
            return nil
        }

        // Update access time
        accessCounter += 1
        entry.lastAccess = accessCounter
        cache[key] = entry

        // Move to end of access order
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
        }
        accessOrder.append(key)

        return entry.textureView
    }

    /// Gets or creates a texture for the specified image.
    ///
    /// - Parameter image: The source image
    /// - Returns: The texture view, or nil if creation failed
    public func getOrCreateTexture(for image: CGImage) -> GPUTextureView? {
        // Check cache first
        if let existing = getTexture(for: image) {
            return existing
        }

        // Create new texture
        guard let entry = createTextureEntry(for: image) else {
            return nil
        }

        let key = ObjectIdentifier(image)

        // Evict if necessary
        evictIfNeeded()

        // Add to cache
        cache[key] = entry
        accessOrder.append(key)
        totalMemoryUsage += entry.memorySize

        return entry.textureView
    }

    /// Creates a texture entry for an image.
    private func createTextureEntry(for image: CGImage) -> CacheEntry? {
        let width = image.width
        let height = image.height

        guard width > 0, height > 0 else { return nil }

        // Create texture
        let texture = device.createTexture(descriptor: GPUTextureDescriptor(
            size: GPUExtent3D(width: UInt32(width), height: UInt32(height)),
            format: .rgba8unorm,
            usage: [.textureBinding, .copyDst],
            label: "CGImage Texture (\(width)x\(height))"
        ))

        // Upload pixel data
        guard let pixelData = extractPixelData(from: image) else {
            return nil
        }

        uploadPixelData(pixelData, to: texture, width: width, height: height)

        let textureView = texture.createView()
        accessCounter += 1

        return CacheEntry(
            texture: texture,
            textureView: textureView,
            width: width,
            height: height,
            lastAccess: accessCounter
        )
    }

    /// Extracts RGBA pixel data from a CGImage.
    private func extractPixelData(from image: CGImage) -> Data? {
        // Try to get data directly from the image's data provider
        guard let provider = image.dataProvider,
              let data = provider.data else {
            return nil
        }

        // Verify the data is the expected size
        let expectedSize = image.width * image.height * 4  // RGBA
        if data.count >= expectedSize {
            return data
        }

        // If data format doesn't match, we might need conversion
        // For now, return nil if sizes don't match
        return nil
    }

    /// Uploads pixel data to a texture.
    private func uploadPixelData(_ data: Data, to texture: GPUTexture, width: Int, height: Int) {
        // Convert Data to [UInt8] then to JSTypedArray
        let bytes = [UInt8](data)
        let uint8Array = JSTypedArray<UInt8>(bytes)

        // Write to texture
        queue.writeTexture(
            destination: GPUImageCopyTexture(texture: texture),
            data: uint8Array.jsObject,
            dataLayout: GPUImageDataLayout(
                offset: 0,
                bytesPerRow: UInt32(width * 4),
                rowsPerImage: UInt32(height)
            ),
            size: GPUExtent3D(width: UInt32(width), height: UInt32(height))
        )
    }

    // MARK: - Cache Management

    /// Evicts entries if cache is over capacity.
    private func evictIfNeeded() {
        // Evict by count
        while cache.count >= capacity && !accessOrder.isEmpty {
            evictLeastRecentlyUsed()
        }

        // Evict by memory
        while totalMemoryUsage > maxMemoryUsage && !accessOrder.isEmpty {
            evictLeastRecentlyUsed()
        }
    }

    /// Evicts the least recently used entry.
    private func evictLeastRecentlyUsed() {
        guard let lruKey = accessOrder.first else { return }

        if let entry = cache.removeValue(forKey: lruKey) {
            totalMemoryUsage -= entry.memorySize
            // GPUTexture will be deallocated when entry is removed
        }

        accessOrder.removeFirst()
    }

    /// Clears all cached textures.
    public func clear() {
        cache.removeAll()
        accessOrder.removeAll()
        totalMemoryUsage = 0
    }

    /// Removes a specific image from the cache.
    ///
    /// - Parameter image: The image to remove
    public func remove(image: CGImage) {
        let key = ObjectIdentifier(image)

        if let entry = cache.removeValue(forKey: key) {
            totalMemoryUsage -= entry.memorySize

            if let index = accessOrder.firstIndex(of: key) {
                accessOrder.remove(at: index)
            }
        }
    }

    // MARK: - Statistics

    /// Returns the number of cached textures.
    public var count: Int {
        return cache.count
    }

    /// Returns whether the cache is empty.
    public var isEmpty: Bool {
        return cache.isEmpty
    }

    /// Returns whether the cache is at capacity.
    public var isFull: Bool {
        return cache.count >= capacity
    }

    /// Returns cache statistics.
    public var statistics: CacheStatistics {
        return CacheStatistics(
            entryCount: cache.count,
            capacity: capacity,
            memoryUsage: totalMemoryUsage,
            maxMemoryUsage: maxMemoryUsage
        )
    }
}

// MARK: - Statistics

/// Statistics about the texture cache.
public struct CacheStatistics: Sendable {
    public let entryCount: Int
    public let capacity: Int
    public let memoryUsage: Int
    public let maxMemoryUsage: Int

    public var utilizationPercent: Double {
        return Double(entryCount) / Double(capacity) * 100.0
    }

    public var memoryUtilizationPercent: Double {
        guard maxMemoryUsage > 0 else { return 0 }
        return Double(memoryUsage) / Double(maxMemoryUsage) * 100.0
    }
}

#endif
