//
//  TextureManager.swift
//  CGWebGPU
//
//  Internal LRU texture cache for CGImage textures.
//

#if arch(wasm32)
import OpenCoreGraphicsSupport
import SwiftWebGPU

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
internal final class TextureManager {

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

        var memorySize: Int {
            // RGBA8 = 4 bytes per pixel
            return width * height * 4
        }
    }

    private struct CacheRecord {
        let key: TextureKey
        let entry: TextureEntry
    }

    // MARK: - Properties

    private let device: GPUDevice
    private let queue: GPUQueue
    private let uploadStaging: WebGPUUploadStaging

    /// Maximum number of textures to cache
    private let capacity: Int

    /// Cached textures ordered from least to most recently used.
    ///
    /// The cache is intentionally array-backed. Swift 6.4 release-WASM can
    /// miscompile `_DictionaryStorage` resizing for this composite key, while
    /// the bounded capacity keeps the linear lookup cost deterministic.
    private var cache: [CacheRecord] = []

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
    init(
        device: GPUDevice,
        uploadStaging: WebGPUUploadStaging,
        capacity: Int = 100
    ) {
        self.device = device
        self.queue = device.queue
        self.uploadStaging = uploadStaging
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

        guard let index = cache.firstIndex(where: { $0.key == key }) else {
            return nil
        }

        let record = cache.remove(at: index)
        cache.append(record)
        return record.entry.textureView
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

        guard entry.memorySize <= maxMemoryUsage else {
            entry.texture.destroy()
            return nil
        }

        // Evict before insertion so both capacity and memory limits remain
        // true immediately after this method returns.
        evictIfNeeded(additionalMemory: entry.memorySize)
        cache.append(CacheRecord(key: key, entry: entry))
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

        guard uploadPixelData(pixelData, to: texture, width: width, height: height) else {
            return nil
        }

        return TextureEntry(
            cgImage: image,
            texture: texture,
            textureView: texture.createView(),
            width: width,
            height: height
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
    private func uploadPixelData(
        _ data: Data,
        to texture: GPUTexture,
        width: Int,
        height: Int
    ) -> Bool {
        guard let uint8Array = uploadStaging.uint8Array(copying: data) else {
            return false
        }
        queue.writeTexture(
            destination: GPUImageCopyTexture(texture: texture),
            data: uint8Array,
            dataLayout: GPUImageDataLayout(
                offset: 0,
                bytesPerRow: UInt32(width * 4),
                rowsPerImage: UInt32(height)
            ),
            size: GPUExtent3D(width: UInt32(width), height: UInt32(height))
        )
        return true
    }

    // MARK: - Cache Management

    /// Evicts entries if over capacity or memory limit.
    private func evictIfNeeded(additionalMemory: Int) {
        while !cache.isEmpty,
              cache.count >= capacity
                || totalMemoryUsage + additionalMemory > maxMemoryUsage {
            evictLeastRecentlyUsed()
        }
    }

    /// Evicts the least recently used entry.
    private func evictLeastRecentlyUsed() {
        guard !cache.isEmpty else { return }
        let record = cache.removeFirst()
        totalMemoryUsage -= record.entry.memorySize
        record.entry.texture.destroy()
        onEvict?(record.entry.cgImage)
    }

    /// Clears all cached textures.
    func clear() {
        // Snapshot records first so callbacks run after the cache is drained.
        let evicted = cache.map({ $0.entry })
        cache.removeAll()
        totalMemoryUsage = 0

        for entry in evicted {
            entry.texture.destroy()
            onEvict?(entry.cgImage)
        }
    }

    /// Removes a specific image from the cache.
    func remove(image: CGImage) {
        let identifier = ObjectIdentifier(image)
        var index = cache.count
        while index > 0 {
            index -= 1
            guard cache[index].key.imageIdentifier == identifier else {
                continue
            }
            let record = cache.remove(at: index)
            totalMemoryUsage -= record.entry.memorySize
            record.entry.texture.destroy()
            onEvict?(record.entry.cgImage)
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
