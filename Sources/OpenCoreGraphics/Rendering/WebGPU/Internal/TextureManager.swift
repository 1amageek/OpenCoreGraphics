//
//  TextureManager.swift
//  CGWebGPU
//
//  Internal LRU texture cache for CGImage textures.
//

#if arch(wasm32)
import Foundation
import SwiftWebGPU
import JavaScriptKit

/// Internal texture manager with LRU eviction.
///
/// Manages GPU textures created from CGImage instances with automatic
/// memory management through LRU eviction.
internal final class TextureManager: @unchecked Sendable {

    // MARK: - Types

    /// Cached texture entry.
    struct TextureEntry {
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
    private var cache: [ObjectIdentifier: TextureEntry] = [:]

    /// Access order for LRU eviction (oldest first)
    private var accessOrder: [ObjectIdentifier] = []

    /// Current access counter for LRU tracking
    private var accessCounter: UInt64 = 0

    /// Approximate total GPU memory usage (bytes)
    private(set) var totalMemoryUsage: Int = 0

    /// Maximum memory before forced eviction (bytes)
    var maxMemoryUsage: Int = 256 * 1024 * 1024  // 256 MB

    // MARK: - Initialization

    /// Creates a new texture manager.
    ///
    /// - Parameters:
    ///   - device: The WebGPU device
    ///   - capacity: Maximum texture count (default: 100)
    init(device: GPUDevice, capacity: Int = 100) {
        self.device = device
        self.queue = device.queue
        self.capacity = capacity
    }

    // MARK: - Texture Access

    /// Gets a cached texture view for an image.
    ///
    /// - Parameter image: The source CGImage
    /// - Returns: The texture view, or nil if not cached
    func getTexture(for image: CGImage) -> GPUTextureView? {
        let key = ObjectIdentifier(image)

        guard var entry = cache[key] else {
            return nil
        }

        // Update access time
        accessCounter += 1
        entry.lastAccess = accessCounter
        cache[key] = entry

        // Move to end of access order (most recently used)
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
        }
        accessOrder.append(key)

        return entry.textureView
    }

    /// Gets or creates a texture for the specified image.
    ///
    /// - Parameter image: The source CGImage
    /// - Returns: The texture view, or nil if creation failed
    func getOrCreateTexture(for image: CGImage) -> GPUTextureView? {
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

    // MARK: - Texture Creation

    /// Creates a texture entry from a CGImage.
    private func createTextureEntry(for image: CGImage) -> TextureEntry? {
        let width = image.width
        let height = image.height

        guard width > 0, height > 0 else { return nil }

        // Create GPU texture
        let texture = device.createTexture(descriptor: GPUTextureDescriptor(
            size: GPUExtent3D(width: UInt32(width), height: UInt32(height)),
            format: .rgba8unorm,
            usage: [.textureBinding, .copyDst],
            label: "CGImage Texture (\(width)x\(height))"
        ))

        // Extract and upload pixel data
        guard let pixelData = extractPixelData(from: image) else {
            return nil
        }

        uploadPixelData(pixelData, to: texture, width: width, height: height)

        let textureView = texture.createView()
        accessCounter += 1

        return TextureEntry(
            texture: texture,
            textureView: textureView,
            width: width,
            height: height,
            lastAccess: accessCounter
        )
    }

    /// Extracts RGBA pixel data from a CGImage.
    private func extractPixelData(from image: CGImage) -> Data? {
        guard let provider = image.dataProvider,
              let data = provider.data else {
            return nil
        }

        // Verify data size matches expected RGBA format
        let expectedSize = image.width * image.height * 4
        if data.count >= expectedSize {
            return data
        }

        // Format mismatch - would need conversion
        return nil
    }

    /// Uploads pixel data to a GPU texture.
    private func uploadPixelData(_ data: Data, to texture: GPUTexture, width: Int, height: Int) {
        let bytes = [UInt8](data)
        let uint8Array = JSTypedArray<UInt8>(bytes)

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

    /// Evicts entries if over capacity or memory limit.
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
        }

        accessOrder.removeFirst()
    }

    /// Clears all cached textures.
    func clear() {
        cache.removeAll()
        accessOrder.removeAll()
        totalMemoryUsage = 0
    }

    /// Removes a specific image from the cache.
    func remove(image: CGImage) {
        let key = ObjectIdentifier(image)

        if let entry = cache.removeValue(forKey: key) {
            totalMemoryUsage -= entry.memorySize

            if let index = accessOrder.firstIndex(of: key) {
                accessOrder.remove(at: index)
            }
        }
    }

    // MARK: - Statistics

    /// Number of cached textures.
    var count: Int { cache.count }

    /// Whether the cache is empty.
    var isEmpty: Bool { cache.isEmpty }

    /// Whether the cache is at capacity.
    var isFull: Bool { cache.count >= capacity }
}

#endif
