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
///
/// ## Identity & Ownership
///
/// The cache is keyed by `ObjectIdentifier(CGImage)`, but a raw pointer
/// identifier is only stable while the underlying object is alive. To
/// guarantee key uniqueness, every cache entry holds a strong reference
/// to its `CGImage`; without this, the source image could be released by
/// ARC, its heap address reused by a fresh allocation, and a subsequent
/// lookup would incorrectly return the stale `GPUTextureView`
/// (cross-image identity collision symptom).
internal final class TextureManager: @unchecked Sendable {

    // MARK: - Types

    /// Cached texture entry.
    ///
    /// Holds the source `CGImage` so the entry's
    /// `ObjectIdentifier(cgImage)` key remains unique for the lifetime of
    /// the cached texture.
    struct TextureEntry {
        let cgImage: CGImage
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

    /// Cached textures keyed by `ObjectIdentifier(CGImage)`.
    ///
    /// Each entry retains its `CGImage` (see `TextureEntry.cgImage`) so
    /// the identifier remains unique for the cached lifetime.
    private var cache: [ObjectIdentifier: TextureEntry] = [:]

    /// Access order for LRU eviction (oldest first)
    private var accessOrder: [ObjectIdentifier] = []

    /// Current access counter for LRU tracking
    private var accessCounter: UInt64 = 0

    /// Approximate total GPU memory usage (bytes)
    private(set) var totalMemoryUsage: Int = 0

    /// Maximum memory before forced eviction (bytes)
    var maxMemoryUsage: Int = 256 * 1024 * 1024  // 256 MB

    /// Called for each `CGImage` whose cached texture is removed.
    ///
    /// Downstream caches keyed by the same `ObjectIdentifier(CGImage)`
    /// must drop their entries here, otherwise they may end up serving
    /// stale `GPUTextureView`s for a future image whose heap address
    /// happens to alias the evicted one.
    var onEvict: ((CGImage) -> Void)?

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
            cgImage: image,
            texture: texture,
            textureView: textureView,
            width: width,
            height: height,
            lastAccess: accessCounter
        )
    }

    /// Extracts RGBA pixel data from a CGImage.
    private func extractPixelData(from image: CGImage) -> Data? {
        guard let data = image.data ?? image.dataProvider?.data else {
            return nil
        }

        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let packedBytesPerRow = width * bytesPerPixel

        guard width > 0,
              height > 0,
              image.bitsPerComponent == 8,
              image.bitsPerPixel == 32,
              image.bytesPerRow >= packedBytesPerRow else {
            return nil
        }

        let requiredByteCount = image.bytesPerRow * (height - 1) + packedBytesPerRow
        guard data.count >= requiredByteCount else { return nil }

        var result = [UInt8](repeating: 0, count: packedBytesPerRow * height)
        data.withUnsafeBytes { raw in
            guard let source = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }

            for y in 0..<height {
                let sourceRow = y * image.bytesPerRow
                let destinationRow = y * packedBytesPerRow

                for x in 0..<width {
                    let sourceOffset = sourceRow + x * bytesPerPixel
                    let destinationOffset = destinationRow + x * bytesPerPixel
                    let b0 = source[sourceOffset]
                    let b1 = source[sourceOffset + 1]
                    let b2 = source[sourceOffset + 2]
                    let b3 = source[sourceOffset + 3]
                    let pixel = rgbaPixel(
                        b0,
                        b1,
                        b2,
                        b3,
                        alphaInfo: image.alphaInfo,
                        byteOrderInfo: image.byteOrderInfo
                    )

                    result[destinationOffset] = pixel.r
                    result[destinationOffset + 1] = pixel.g
                    result[destinationOffset + 2] = pixel.b
                    result[destinationOffset + 3] = pixel.a
                }
            }
        }

        return Data(result)
    }

    private func rgbaPixel(
        _ b0: UInt8,
        _ b1: UInt8,
        _ b2: UInt8,
        _ b3: UInt8,
        alphaInfo: CGImageAlphaInfo,
        byteOrderInfo: CGImageByteOrderInfo
    ) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        let hasAlpha: Bool
        switch alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast:
            hasAlpha = false
        case .premultipliedLast, .premultipliedFirst, .last, .first, .alphaOnly:
            hasAlpha = true
        }

        switch byteOrderInfo {
        case .order32Little:
            switch alphaInfo {
            case .premultipliedLast, .last, .noneSkipLast:
                return (b3, b2, b1, hasAlpha ? b0 : 255)
            case .premultipliedFirst, .first, .noneSkipFirst:
                return (b2, b1, b0, hasAlpha ? b3 : 255)
            case .none:
                return (b2, b1, b0, 255)
            case .alphaOnly:
                return (255, 255, 255, b0)
            }

        case .order32Big, .orderDefault, .order16Little, .order16Big:
            switch alphaInfo {
            case .premultipliedFirst, .first, .noneSkipFirst:
                return (b1, b2, b3, hasAlpha ? b0 : 255)
            case .premultipliedLast, .last, .noneSkipLast, .none:
                return (b0, b1, b2, hasAlpha ? b3 : 255)
            case .alphaOnly:
                return (255, 255, 255, b0)
            }
        }
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

        accessOrder.removeFirst()

        if let entry = cache.removeValue(forKey: lruKey) {
            totalMemoryUsage -= entry.memorySize
            onEvict?(entry.cgImage)
        }
    }

    /// Clears all cached textures.
    func clear() {
        // Snapshot evicted images first so the callback can run after the
        // dictionary is fully drained — avoids iteration-during-mutation
        // if the callback indirectly inserts back into the cache.
        let evicted = cache.values.map { $0.cgImage }
        cache.removeAll()
        accessOrder.removeAll()
        totalMemoryUsage = 0

        if let onEvict = onEvict {
            for cgImage in evicted {
                onEvict(cgImage)
            }
        }
    }

    /// Removes a specific image from the cache.
    func remove(image: CGImage) {
        let key = ObjectIdentifier(image)

        if let entry = cache.removeValue(forKey: key) {
            totalMemoryUsage -= entry.memorySize

            if let index = accessOrder.firstIndex(of: key) {
                accessOrder.remove(at: index)
            }
            onEvict?(entry.cgImage)
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
