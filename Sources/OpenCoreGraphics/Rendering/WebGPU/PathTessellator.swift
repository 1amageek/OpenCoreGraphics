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


    // MARK: - Triangulation

    /// Tessellate a path for filling (converts polygon to triangles).
    ///
    /// - Parameters:
    ///   - path: The path to fill.
    ///   - color: The fill color applied to every produced vertex.
    ///   - rule: The fill rule. Even-odd paths are pre-processed so that
    ///     self-intersections are resolved against the even-odd interior; the
    ///     ear-clipping triangulator only understands winding boundaries, so
    ///     this conversion is required for the right coverage.
    public func tessellateFill(
        _ path: CGPath,
        color: CGColor,
        rule: CGPathFillRule = .winding
    ) -> CGWebGPUVertexBatch {
        let sourcePath: CGPath
        switch rule {
        case .evenOdd:
            sourcePath = _resolveSelfIntersections(path: path, rule: .evenOdd)
        case .winding:
            sourcePath = path
        @unknown default:
            sourcePath = path
        }
        let flattenedSubpaths = flattenPathWithInfo(sourcePath)
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
        lineCap: CGLineCap = .butt,
        lineJoin: CGLineJoin = .miter,
        miterLimit: CGFloat = 10
    ) -> CGWebGPUVertexBatch {
        var vertices: [CGWebGPUVertex] = []
        let (r, g, b, a) = extractColorComponents(color)
        let geometry = CGStrokeGeometry.make(
            path: path,
            lineWidth: lineWidth,
            lineCap: lineCap,
            lineJoin: lineJoin,
            miterLimit: miterLimit
        )
        for point in geometry.triangles {
            let (x, y) = toNDC(point)
            vertices.append(CGWebGPUVertex(x: x, y: y, r: r, g: g, b: b, a: a))
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
