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
/// Cache identity includes the source image, destination color space, and
/// rendering intent. A single image may therefore have distinct GPU textures
/// when it is drawn into contexts with different color-management state.
internal final class TextureManager: @unchecked Sendable {

    // MARK: - Types

    struct TextureKey: Hashable {
        let imageIdentifier: ObjectIdentifier
        let destinationColorSpace: CGColorSpace
        let intent: CGColorRenderingIntent
    }

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

    /// Cached textures keyed by image identity and color conversion state.
    private var cache: [TextureKey: TextureEntry] = [:]

    /// Access order for LRU eviction (oldest first)
    private var accessOrder: [TextureKey] = []

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
    /// - Parameters:
    ///   - image: The source CGImage.
    ///   - destinationColorSpace: The context destination color space.
    ///   - intent: The resolved sampled-image rendering intent.
    /// - Returns: The texture view, or nil if not cached
    func getTexture(
        for image: CGImage,
        destinationColorSpace: CGColorSpace,
        intent: CGColorRenderingIntent
    ) -> GPUTextureView? {
        let key = TextureKey(
            imageIdentifier: ObjectIdentifier(image),
            destinationColorSpace: destinationColorSpace,
            intent: intent
        )

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
    /// - Parameters:
    ///   - image: The source CGImage.
    ///   - destinationColorSpace: The context destination color space.
    ///   - intent: The resolved sampled-image rendering intent.
    /// - Returns: The texture view, or nil if creation failed
    func getOrCreateTexture(
        for image: CGImage,
        destinationColorSpace: CGColorSpace,
        intent: CGColorRenderingIntent
    ) -> GPUTextureView? {
        // Check cache first
        if let existing = getTexture(
            for: image,
            destinationColorSpace: destinationColorSpace,
            intent: intent
        ) {
            return existing
        }

        // Create new texture
        guard let entry = createTextureEntry(
            for: image,
            destinationColorSpace: destinationColorSpace,
            intent: intent
        ) else {
            return nil
        }

        let key = TextureKey(
            imageIdentifier: ObjectIdentifier(image),
            destinationColorSpace: destinationColorSpace,
            intent: intent
        )

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
    private func createTextureEntry(
        for image: CGImage,
        destinationColorSpace: CGColorSpace,
        intent: CGColorRenderingIntent
    ) -> TextureEntry? {
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
        guard let pixelData = extractPixelData(
            from: image,
            destinationColorSpace: destinationColorSpace,
            intent: intent
        ) else {
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
    private func extractPixelData(
        from image: CGImage,
        destinationColorSpace: CGColorSpace,
        intent: CGColorRenderingIntent
    ) -> Data? {
        guard let data = image.data ?? image.dataProvider?.data,
              let sourceColorSpace = image.colorSpace,
              destinationColorSpace.model == .rgb,
              destinationColorSpace.numberOfComponents == 3 else {
            return nil
        }

        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let packedBytesPerRow = width * bytesPerPixel

        guard width > 0, height > 0 else {
            return nil
        }

        let sourceBytesPerPixel = (image.bitsPerPixel + 7) / 8
        let requiredByteCount = image.bytesPerRow * (height - 1) + width * sourceBytesPerPixel
        guard data.count >= requiredByteCount else { return nil }

        let destinationFormat = CGColorBufferFormat(
            version: 0,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: packedBytesPerRow
        )
        let sourceFormat = CGColorBufferFormat(
            version: 0,
            bitmapInfo: image.bitmapInfo,
            bitsPerComponent: image.bitsPerComponent,
            bitsPerPixel: image.bitsPerPixel,
            bytesPerRow: image.bytesPerRow
        )
        var result = Data(count: packedBytesPerRow * height)
        let converted = data.withUnsafeBytes { sourceBuffer -> Bool in
            guard let source = sourceBuffer.baseAddress else { return false }
            return result.withUnsafeMutableBytes { destinationBuffer -> Bool in
                guard let destination = destinationBuffer.baseAddress else { return false }
                return CGColorBufferConverter.convert(
                    width: width,
                    height: height,
                    destinationBuffer: destination,
                    destinationFormat: destinationFormat,
                    destinationColorSpace: destinationColorSpace,
                    sourceBuffer: source,
                    sourceFormat: sourceFormat,
                    sourceColorSpace: sourceColorSpace,
                    intent: intent,
                    options: nil
                )
            }
        }
        return converted ? result : nil
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
        let identifier = ObjectIdentifier(image)
        let keys = cache.keys.filter { $0.imageIdentifier == identifier }
        for key in keys {
            guard let entry = cache.removeValue(forKey: key) else { continue }
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
