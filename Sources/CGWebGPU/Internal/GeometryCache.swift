//
//  GeometryCache.swift
//  CGWebGPU
//
//  Internal cache for tessellated path geometry.
//

#if arch(wasm32)
import Foundation
import OpenCoreGraphics

/// Internal cache for tessellated path geometry.
///
/// Tessellation is CPU-intensive. This cache stores tessellated vertices
/// for reuse when the same path is drawn multiple times.
internal final class GeometryCache: @unchecked Sendable {

    // MARK: - Types

    /// Hash identifier for a path configuration.
    struct PathHash: Hashable {
        let value: Int
    }

    /// Cached tessellated geometry.
    struct CachedGeometry {
        /// Tessellated vertices (position + color interleaved)
        let vertices: [Float]

        /// Number of vertices
        let vertexCount: Int

        /// Bounding box of the geometry
        let bounds: CGRect

        /// Whether this is fill or stroke geometry
        let isFill: Bool

        /// Last access counter for LRU
        var lastAccess: UInt64
    }

    // MARK: - Properties

    /// Maximum number of cached geometries
    private let capacity: Int

    /// Cache storage
    private var cache: [PathHash: CachedGeometry] = [:]

    /// Access order for LRU eviction (oldest first)
    private var accessOrder: [PathHash] = []

    /// Current access counter
    private var accessCounter: UInt64 = 0

    /// Cache statistics
    private(set) var hits: Int = 0
    private(set) var misses: Int = 0

    // MARK: - Initialization

    /// Creates a new geometry cache.
    ///
    /// - Parameter capacity: Maximum number of cached geometries (default: 500)
    init(capacity: Int = 500) {
        self.capacity = capacity
    }

    // MARK: - Hash Computation

    /// Computes a hash for a path configuration.
    ///
    /// The hash includes:
    /// - Path elements (move, line, curve, close)
    /// - Transform matrix
    /// - Fill vs stroke mode
    ///
    /// - Parameters:
    ///   - path: The path to hash
    ///   - transform: Applied transformation
    ///   - isFill: Whether this is for fill (true) or stroke (false)
    /// - Returns: A hash identifier
    func computeHash(path: CGPath, transform: CGAffineTransform, isFill: Bool) -> PathHash {
        var hasher = Hasher()

        // Hash path elements
        path.applyWithBlock { elementPtr in
            let element = elementPtr.pointee
            hasher.combine(element.type.rawValue)
            guard let points = element.points else { return }
            switch element.type {
            case .moveToPoint, .addLineToPoint:
                hasher.combine(points[0].x)
                hasher.combine(points[0].y)
            case .addQuadCurveToPoint:
                hasher.combine(points[0].x)
                hasher.combine(points[0].y)
                hasher.combine(points[1].x)
                hasher.combine(points[1].y)
            case .addCurveToPoint:
                hasher.combine(points[0].x)
                hasher.combine(points[0].y)
                hasher.combine(points[1].x)
                hasher.combine(points[1].y)
                hasher.combine(points[2].x)
                hasher.combine(points[2].y)
            case .closeSubpath:
                break
            @unknown default:
                break
            }
        }

        // Hash transform
        hasher.combine(transform.a)
        hasher.combine(transform.b)
        hasher.combine(transform.c)
        hasher.combine(transform.d)
        hasher.combine(transform.tx)
        hasher.combine(transform.ty)

        // Hash fill mode
        hasher.combine(isFill)

        return PathHash(value: hasher.finalize())
    }

    // MARK: - Cache Access

    /// Gets cached geometry if available.
    ///
    /// - Parameter hash: The path hash
    /// - Returns: Cached geometry, or nil if not found
    func get(_ hash: PathHash) -> CachedGeometry? {
        guard var entry = cache[hash] else {
            misses += 1
            return nil
        }

        // Update access time
        accessCounter += 1
        entry.lastAccess = accessCounter
        cache[hash] = entry

        // Move to end of access order
        if let index = accessOrder.firstIndex(of: hash) {
            accessOrder.remove(at: index)
        }
        accessOrder.append(hash)

        hits += 1
        return entry
    }

    /// Gets cached geometry or tessellates and caches the result.
    ///
    /// - Parameters:
    ///   - path: The path to tessellate
    ///   - transform: Applied transformation
    ///   - isFill: Whether to fill or stroke
    ///   - color: The color for vertices
    ///   - tessellator: The tessellator to use if not cached
    /// - Returns: Cached or newly tessellated geometry
    func getOrTessellate(
        path: CGPath,
        transform: CGAffineTransform,
        isFill: Bool,
        color: CGColor,
        tessellator: PathTessellator
    ) -> CachedGeometry? {
        let hash = computeHash(path: path, transform: transform, isFill: isFill)

        // Check cache
        if let cached = get(hash) {
            return cached
        }

        // Tessellate
        var mutableTransform = transform
        let transformedPath = withUnsafePointer(to: &mutableTransform) { transformPtr in
            path.copy(using: transformPtr)
        }
        guard let finalPath = transformedPath else { return nil }

        let vertices: [Float]
        if isFill {
            let batch = tessellator.tessellateFill(finalPath, color: color)
            vertices = batch.toFloatArray()
        } else {
            // For stroke, we need line width - use default for cache key purposes
            // Actual stroke width should be part of the hash if caching strokes
            return nil  // Stroke caching requires additional parameters
        }

        guard !vertices.isEmpty else { return nil }

        // Calculate bounds
        let bounds = finalPath.boundingBox

        // Create entry
        accessCounter += 1
        let geometry = CachedGeometry(
            vertices: vertices,
            vertexCount: vertices.count / 6,  // 6 floats per vertex (x, y, r, g, b, a)
            bounds: bounds,
            isFill: isFill,
            lastAccess: accessCounter
        )

        // Evict if needed
        evictIfNeeded()

        // Store in cache
        cache[hash] = geometry
        accessOrder.append(hash)

        return geometry
    }

    /// Stores pre-tessellated geometry in the cache.
    ///
    /// - Parameters:
    ///   - geometry: The geometry to cache
    ///   - hash: The path hash
    func store(_ geometry: CachedGeometry, for hash: PathHash) {
        evictIfNeeded()

        var entry = geometry
        accessCounter += 1
        entry.lastAccess = accessCounter

        cache[hash] = entry
        accessOrder.append(hash)
    }

    // MARK: - Cache Management

    /// Evicts entries if over capacity.
    private func evictIfNeeded() {
        while cache.count >= capacity && !accessOrder.isEmpty {
            evictLeastRecentlyUsed()
        }
    }

    /// Evicts the least recently used entry.
    private func evictLeastRecentlyUsed() {
        guard let lruKey = accessOrder.first else { return }
        cache.removeValue(forKey: lruKey)
        accessOrder.removeFirst()
    }

    /// Clears all cached geometry.
    func clear() {
        cache.removeAll()
        accessOrder.removeAll()
        hits = 0
        misses = 0
    }

    // MARK: - Statistics

    /// Number of cached geometries.
    var count: Int { cache.count }

    /// Whether the cache is empty.
    var isEmpty: Bool { cache.isEmpty }

    /// Cache hit rate (0.0 to 1.0).
    var hitRate: Double {
        let total = hits + misses
        guard total > 0 else { return 0 }
        return Double(hits) / Double(total)
    }
}

#endif
