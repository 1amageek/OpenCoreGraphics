//
//  PathTessellator.swift
//  CGWebGPU
//
//  Converts CGPath to GPU-renderable triangles
//

#if arch(wasm32)
import Foundation

/// Tessellates CGPath into triangles for GPU rendering
public struct PathTessellator: Sendable {

    /// Flatness for curve subdivision (smaller = more segments)
    public var flatness: CGFloat

    /// Viewport width for coordinate conversion
    public var viewportWidth: CGFloat

    /// Viewport height for coordinate conversion
    public var viewportHeight: CGFloat

    /// Triangulator for polygon tessellation
    private let triangulator = EarClippingTriangulator()

    /// Stroke generator for line caps and joins
    private var strokeGenerator = StrokeGenerator()

    public init(flatness: CGFloat = 0.5, viewportWidth: CGFloat = 800, viewportHeight: CGFloat = 600) {
        self.flatness = flatness
        self.viewportWidth = viewportWidth
        self.viewportHeight = viewportHeight
    }

    // MARK: - Coordinate Conversion

    /// Convert from CoreGraphics coordinates to normalized device coordinates (NDC)
    /// CoreGraphics: origin at bottom-left, Y up
    /// NDC: origin at center, X: -1 to 1, Y: -1 to 1
    private func toNDC(_ point: CGPoint) -> (Float, Float) {
        let x = Float((point.x / viewportWidth) * 2.0 - 1.0)
        let y = Float((point.y / viewportHeight) * 2.0 - 1.0)
        return (x, y)
    }

    // MARK: - Path Flattening

    /// Represents a flattened subpath with closure information
    public struct FlattenedSubpath {
        public let points: [CGPoint]
        public let isClosed: Bool
    }

    /// Flatten a path into line segments (converts curves to lines)
    /// Returns subpaths without closure information (for backward compatibility)
    public func flattenPath(_ path: CGPath) -> [[CGPoint]] {
        return flattenPathWithInfo(path).map { $0.points }
    }

    /// Flatten a path into line segments with closure information
    /// - Parameter path: The path to flatten
    /// - Returns: Array of FlattenedSubpath containing points and whether the subpath was closed
    public func flattenPathWithInfo(_ path: CGPath) -> [FlattenedSubpath] {
        var subpaths: [FlattenedSubpath] = []
        var currentSubpath: [CGPoint] = []
        var currentPoint = CGPoint.zero
        var subpathStart = CGPoint.zero

        path.applyWithBlock { element in
            let type = element.pointee.type
            let points = element.pointee.points

            switch type {
            case .moveToPoint:
                if !currentSubpath.isEmpty {
                    subpaths.append(FlattenedSubpath(points: currentSubpath, isClosed: false))
                }
                currentSubpath = []
                if let points = points {
                    let point = points[0]
                    currentSubpath.append(point)
                    currentPoint = point
                    subpathStart = point
                }

            case .addLineToPoint:
                if let points = points {
                    let point = points[0]
                    currentSubpath.append(point)
                    currentPoint = point
                }

            case .addQuadCurveToPoint:
                if let points = points {
                    let control = points[0]
                    let end = points[1]
                    let segments = subdivideQuadBezier(
                        start: currentPoint,
                        control: control,
                        end: end,
                        flatness: flatness
                    )
                    currentSubpath.append(contentsOf: segments.dropFirst())
                    currentPoint = end
                }

            case .addCurveToPoint:
                if let points = points {
                    let control1 = points[0]
                    let control2 = points[1]
                    let end = points[2]
                    let segments = subdivideCubicBezier(
                        start: currentPoint,
                        control1: control1,
                        control2: control2,
                        end: end,
                        flatness: flatness
                    )
                    currentSubpath.append(contentsOf: segments.dropFirst())
                    currentPoint = end
                }

            case .closeSubpath:
                // For closed subpaths, add the start point back to create the closing segment
                // This is needed for stroke tessellation to draw the closing line
                if !currentSubpath.isEmpty {
                    // Add start point to close the path (for stroke tessellation)
                    currentSubpath.append(subpathStart)
                    subpaths.append(FlattenedSubpath(points: currentSubpath, isClosed: true))
                    currentSubpath = []
                }
                currentPoint = subpathStart

            @unknown default:
                break
            }
        }

        if !currentSubpath.isEmpty {
            subpaths.append(FlattenedSubpath(points: currentSubpath, isClosed: false))
        }

        return subpaths
    }

    // MARK: - Bezier Subdivision

    private func subdivideQuadBezier(start: CGPoint, control: CGPoint, end: CGPoint, flatness: CGFloat) -> [CGPoint] {
        var result: [CGPoint] = [start]
        subdivideQuadBezierRecursive(start: start, control: control, end: end, flatness: flatness, result: &result)
        return result
    }

    private func subdivideQuadBezierRecursive(start: CGPoint, control: CGPoint, end: CGPoint, flatness: CGFloat, result: inout [CGPoint]) {
        // Check if curve is flat enough
        let midLine = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        let distance = hypot(control.x - midLine.x, control.y - midLine.y)

        if distance <= flatness {
            result.append(end)
        } else {
            // Subdivide at t=0.5
            let p01 = CGPoint(x: (start.x + control.x) / 2, y: (start.y + control.y) / 2)
            let p12 = CGPoint(x: (control.x + end.x) / 2, y: (control.y + end.y) / 2)
            let p012 = CGPoint(x: (p01.x + p12.x) / 2, y: (p01.y + p12.y) / 2)

            subdivideQuadBezierRecursive(start: start, control: p01, end: p012, flatness: flatness, result: &result)
            subdivideQuadBezierRecursive(start: p012, control: p12, end: end, flatness: flatness, result: &result)
        }
    }

    private func subdivideCubicBezier(start: CGPoint, control1: CGPoint, control2: CGPoint, end: CGPoint, flatness: CGFloat) -> [CGPoint] {
        var result: [CGPoint] = [start]
        subdivideCubicBezierRecursive(start: start, control1: control1, control2: control2, end: end, flatness: flatness, result: &result)
        return result
    }

    private func subdivideCubicBezierRecursive(start: CGPoint, control1: CGPoint, control2: CGPoint, end: CGPoint, flatness: CGFloat, result: inout [CGPoint]) {
        // Check flatness using distance from control points to line
        let d1 = pointToLineDistance(point: control1, lineStart: start, lineEnd: end)
        let d2 = pointToLineDistance(point: control2, lineStart: start, lineEnd: end)

        if max(d1, d2) <= flatness {
            result.append(end)
        } else {
            // De Casteljau subdivision at t=0.5
            let p01 = midpoint(start, control1)
            let p12 = midpoint(control1, control2)
            let p23 = midpoint(control2, end)
            let p012 = midpoint(p01, p12)
            let p123 = midpoint(p12, p23)
            let p0123 = midpoint(p012, p123)

            subdivideCubicBezierRecursive(start: start, control1: p01, control2: p012, end: p0123, flatness: flatness, result: &result)
            subdivideCubicBezierRecursive(start: p0123, control1: p123, control2: p23, end: end, flatness: flatness, result: &result)
        }
    }

    private func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        return CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    private func pointToLineDistance(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let length = hypot(dx, dy)
        if length == 0 { return hypot(point.x - lineStart.x, point.y - lineStart.y) }

        let t = ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / (length * length)
        let projX = lineStart.x + t * dx
        let projY = lineStart.y + t * dy
        return hypot(point.x - projX, point.y - projY)
    }

    /// Calculate miter offset for stroke corners
    /// - Parameters:
    ///   - n1: Normal of incoming segment (unit vector)
    ///   - n2: Normal of outgoing segment (unit vector)
    ///   - halfWidth: Half of line width
    ///   - miterLimit: Maximum miter length ratio
    /// - Returns: Outer and inner offset vectors, or nil if segments are parallel
    private func calculateMiterOffset(
        n1: (CGFloat, CGFloat),
        n2: (CGFloat, CGFloat),
        halfWidth: CGFloat,
        miterLimit: CGFloat
    ) -> (outer: CGVector, inner: CGVector)? {
        // Calculate the bisector of the two normals
        let bisectorX = n1.0 + n2.0
        let bisectorY = n1.1 + n2.1
        let bisectorLen = hypot(bisectorX, bisectorY)

        // If normals are opposite (180° turn), use simple offset
        if bisectorLen < 0.001 {
            return (
                outer: CGVector(dx: n1.0 * halfWidth, dy: n1.1 * halfWidth),
                inner: CGVector(dx: -n1.0 * halfWidth, dy: -n1.1 * halfWidth)
            )
        }

        // Normalized bisector
        let bx = bisectorX / bisectorLen
        let by = bisectorY / bisectorLen

        // Calculate the dot product to find the angle
        let dot = n1.0 * n2.0 + n1.1 * n2.1  // cos(angle between normals)

        // Miter length = halfWidth / cos(angle/2)
        // cos(angle/2) = sqrt((1 + cos(angle)) / 2) = sqrt((1 + dot) / 2)
        let cosHalfAngle = sqrt((1 + dot) / 2)

        if cosHalfAngle < 0.001 {
            // Very sharp angle, fallback to simple offset
            return (
                outer: CGVector(dx: n1.0 * halfWidth, dy: n1.1 * halfWidth),
                inner: CGVector(dx: -n1.0 * halfWidth, dy: -n1.1 * halfWidth)
            )
        }

        var miterLen = halfWidth / cosHalfAngle

        // Apply miter limit
        if miterLen > halfWidth * miterLimit {
            miterLen = halfWidth * miterLimit
        }

        // Determine which side is outer (positive cross product = left turn = outer is on + side)
        let cross = n1.0 * n2.1 - n1.1 * n2.0

        if cross >= 0 {
            // Left turn: outer is along positive bisector
            return (
                outer: CGVector(dx: bx * miterLen, dy: by * miterLen),
                inner: CGVector(dx: -bx * halfWidth, dy: -by * halfWidth)
            )
        } else {
            // Right turn: outer is along negative bisector
            return (
                outer: CGVector(dx: -bx * miterLen, dy: -by * miterLen),
                inner: CGVector(dx: bx * halfWidth, dy: by * halfWidth)
            )
        }
    }

    // MARK: - Triangulation

    /// Tessellate a path for filling (converts polygon to triangles)
    public func tessellateFill(_ path: CGPath, color: CGColor) -> CGWebGPUVertexBatch {
        let flattenedSubpaths = flattenPathWithInfo(path)
        var vertices: [CGWebGPUVertex] = []

        // Extract color components
        let (r, g, b, a) = extractColorComponents(color)

        for flattenedSubpath in flattenedSubpaths {
            var subpath = flattenedSubpath.points

            // For closed paths, remove the duplicate end point before triangulation
            // Ear clipping already treats the polygon as closed (uses modulo wrap-around)
            if flattenedSubpath.isClosed && subpath.count > 1 {
                subpath.removeLast()
            }

            guard subpath.count >= 3 else { continue }

            // Simple ear-clipping triangulation for convex and simple concave polygons
            let triangles = triangulatePolygon(subpath)
            for triangle in triangles {
                for point in triangle {
                    let (nx, ny) = toNDC(point)
                    vertices.append(CGWebGPUVertex(x: nx, y: ny, r: r, g: g, b: b, a: a))
                }
            }
        }

        return CGWebGPUVertexBatch(vertices: vertices)
    }

    /// Tessellate a path for stroking (converts path to triangle strip)
    /// - Parameters:
    ///   - path: The path to stroke
    ///   - color: Stroke color
    ///   - lineWidth: Width of the stroke
    ///   - lineCap: Line cap style (default: .butt)
    ///   - lineJoin: Line join style (default: .miter)
    ///   - miterLimit: Miter limit for .miter join style (default: 10)
    public func tessellateStroke(
        _ path: CGPath,
        color: CGColor,
        lineWidth: CGFloat,
        lineCap: StrokeGenerator.LineCap = .butt,
        lineJoin: StrokeGenerator.LineJoin = .miter,
        miterLimit: CGFloat = 10
    ) -> CGWebGPUVertexBatch {
        let flattenedSubpaths = flattenPathWithInfo(path)
        var vertices: [CGWebGPUVertex] = []

        let (r, g, b, a) = extractColorComponents(color)
        let halfWidth = lineWidth / 2

        for flattenedSubpath in flattenedSubpaths {
            let subpath = flattenedSubpath.points
            guard subpath.count >= 2 else { continue }

            // Use the explicit closure information from flattenPathWithInfo
            let isClosed = flattenedSubpath.isClosed

            // For closed paths, the points array includes start point at the end: [p0, p1, p2, p3, p0]
            // So we draw subpath.count - 1 segments (same as open paths)
            let segmentCount = subpath.count - 1

            // Pre-calculate normals for each segment
            var segmentNormals: [(nx: CGFloat, ny: CGFloat, length: CGFloat)] = []
            for i in 0..<segmentCount {
                let p0 = subpath[i]
                let p1 = subpath[i + 1]
                let dx = p1.x - p0.x
                let dy = p1.y - p0.y
                let length = hypot(dx, dy)
                if length > 0 {
                    let nx = -dy / length
                    let ny = dx / length
                    segmentNormals.append((nx, ny, length))
                } else {
                    segmentNormals.append((0, 0, 0))
                }
            }

            for i in 0..<segmentCount {
                guard segmentNormals[i].length > 0 else { continue }

                let p0 = subpath[i]
                let p1 = subpath[i + 1]
                let nx = segmentNormals[i].nx * halfWidth
                let ny = segmentNormals[i].ny * halfWidth

                // Calculate adjusted corner vertices for proper miter joins
                // Start point (p0) adjustments
                var v0 = CGPoint(x: p0.x + nx, y: p0.y + ny)  // outer at start
                var v1 = CGPoint(x: p0.x - nx, y: p0.y - ny)  // inner at start

                // End point (p1) adjustments
                var v2 = CGPoint(x: p1.x + nx, y: p1.y + ny)  // outer at end
                var v3 = CGPoint(x: p1.x - nx, y: p1.y - ny)  // inner at end

                // For closed paths or intermediate points, adjust vertices at joins
                // Adjust start vertices based on previous segment
                let hasPrevSegment = isClosed || i > 0
                if hasPrevSegment {
                    let prevIdx = isClosed ? (i - 1 + segmentCount) % segmentCount : i - 1
                    if prevIdx >= 0 && segmentNormals[prevIdx].length > 0 {
                        let prevNx = segmentNormals[prevIdx].nx
                        let prevNy = segmentNormals[prevIdx].ny
                        let currNx = segmentNormals[i].nx
                        let currNy = segmentNormals[i].ny

                        // Calculate miter at start point
                        if let miter = calculateMiterOffset(
                            n1: (prevNx, prevNy),
                            n2: (currNx, currNy),
                            halfWidth: halfWidth,
                            miterLimit: miterLimit
                        ) {
                            v0 = CGPoint(x: p0.x + miter.outer.dx, y: p0.y + miter.outer.dy)
                            v1 = CGPoint(x: p0.x + miter.inner.dx, y: p0.y + miter.inner.dy)
                        }
                    }
                }

                // Adjust end vertices based on next segment
                let hasNextSegment = isClosed || i < segmentCount - 1
                if hasNextSegment {
                    let nextIdx = (i + 1) % segmentCount
                    if segmentNormals[nextIdx].length > 0 {
                        let currNx = segmentNormals[i].nx
                        let currNy = segmentNormals[i].ny
                        let nextNx = segmentNormals[nextIdx].nx
                        let nextNy = segmentNormals[nextIdx].ny

                        // Calculate miter at end point
                        if let miter = calculateMiterOffset(
                            n1: (currNx, currNy),
                            n2: (nextNx, nextNy),
                            halfWidth: halfWidth,
                            miterLimit: miterLimit
                        ) {
                            v2 = CGPoint(x: p1.x + miter.outer.dx, y: p1.y + miter.outer.dy)
                            v3 = CGPoint(x: p1.x + miter.inner.dx, y: p1.y + miter.inner.dy)
                        }
                    }
                }

                // Triangle 1: v0, v1, v2
                let (x0, y0) = toNDC(v0)
                let (x1, y1) = toNDC(v1)
                let (x2, y2) = toNDC(v2)
                let (x3, y3) = toNDC(v3)

                vertices.append(CGWebGPUVertex(x: x0, y: y0, r: r, g: g, b: b, a: a))
                vertices.append(CGWebGPUVertex(x: x1, y: y1, r: r, g: g, b: b, a: a))
                vertices.append(CGWebGPUVertex(x: x2, y: y2, r: r, g: g, b: b, a: a))

                // Triangle 2: v1, v3, v2
                vertices.append(CGWebGPUVertex(x: x1, y: y1, r: r, g: g, b: b, a: a))
                vertices.append(CGWebGPUVertex(x: x3, y: y3, r: r, g: g, b: b, a: a))
                vertices.append(CGWebGPUVertex(x: x2, y: y2, r: r, g: g, b: b, a: a))
            }

            // Generate line caps (only for open paths)
            if !isClosed {
                // Start cap
                if subpath.count >= 2 {
                    let p0 = subpath[0]
                    let p1 = subpath[1]
                    let dx = p0.x - p1.x
                    let dy = p0.y - p1.y
                    let len = hypot(dx, dy)
                    if len > 0 {
                        let direction = CGVector(dx: dx / len, dy: dy / len)
                        let capPoints = strokeGenerator.generateCap(
                            at: p0,
                            direction: direction,
                            halfWidth: halfWidth,
                            style: lineCap
                        )
                        for point in capPoints {
                            let (px, py) = toNDC(point)
                            vertices.append(CGWebGPUVertex(x: px, y: py, r: r, g: g, b: b, a: a))
                        }
                    }
                }

                // End cap
                if subpath.count >= 2 {
                    let p0 = subpath[subpath.count - 2]
                    let p1 = subpath[subpath.count - 1]
                    let dx = p1.x - p0.x
                    let dy = p1.y - p0.y
                    let len = hypot(dx, dy)
                    if len > 0 {
                        let direction = CGVector(dx: dx / len, dy: dy / len)
                        let capPoints = strokeGenerator.generateCap(
                            at: p1,
                            direction: direction,
                            halfWidth: halfWidth,
                            style: lineCap
                        )
                        for point in capPoints {
                            let (px, py) = toNDC(point)
                            vertices.append(CGWebGPUVertex(x: px, y: py, r: r, g: g, b: b, a: a))
                        }
                    }
                }
            }
        }

        return CGWebGPUVertexBatch(vertices: vertices)
    }

    // MARK: - Polygon Triangulation

    private func triangulatePolygon(_ polygon: [CGPoint]) -> [[CGPoint]] {
        return triangulator.triangulate(polygon)
    }

    // MARK: - Color Extraction

    private func extractColorComponents(_ color: CGColor) -> (Float, Float, Float, Float) {
        let components = color.components ?? [0, 0, 0, 1]
        let numComponents = color.numberOfComponents

        if numComponents >= 4 {
            // RGBA
            return (Float(components[0]), Float(components[1]), Float(components[2]), Float(components[3]))
        } else if numComponents >= 2 {
            // Grayscale + Alpha
            return (Float(components[0]), Float(components[0]), Float(components[0]), Float(components[1]))
        } else if numComponents >= 1 {
            // Grayscale
            return (Float(components[0]), Float(components[0]), Float(components[0]), 1.0)
        } else {
            return (0, 0, 0, 1)
        }
    }
}
#endif
