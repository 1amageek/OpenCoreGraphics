//
//  EarClipping.swift
//  CGWebGPU
//
//  Ear clipping algorithm for polygon triangulation
//

#if arch(wasm32)
import Foundation

/// Ear Clipping algorithm for polygon triangulation
/// Handles both convex and concave (simple) polygons
public struct EarClippingTriangulator: Sendable {

    public init() {}

    /// Triangulate a polygon into triangles
    /// - Parameter polygon: Array of vertices (clockwise or counter-clockwise)
    /// - Returns: Array of triangles, each containing 3 points
    public func triangulate(_ polygon: [CGPoint]) -> [[CGPoint]] {
        guard polygon.count >= 3 else { return [] }
        if polygon.count == 3 { return [polygon] }

        // Copy vertex list (we'll remove vertices as we clip ears)
        var vertices = polygon
        var triangles: [[CGPoint]] = []

        // Determine winding direction
        let clockwise = isClockwise(polygon)

        // Find and clip ears
        var attempts = 0
        let maxAttempts = vertices.count * vertices.count

        while vertices.count > 3 && attempts < maxAttempts {
            var earFound = false

            for i in 0..<vertices.count {
                let prev = vertices[(i - 1 + vertices.count) % vertices.count]
                let curr = vertices[i]
                let next = vertices[(i + 1) % vertices.count]

                // Check if this vertex is convex
                if isConvex(prev: prev, curr: curr, next: next, clockwise: clockwise) {
                    // Check if no other vertices are inside this triangle
                    let triangle = [prev, curr, next]
                    var containsOther = false

                    for j in 0..<vertices.count {
                        if j == (i - 1 + vertices.count) % vertices.count ||
                           j == i ||
                           j == (i + 1) % vertices.count {
                            continue
                        }
                        if triangleContainsPoint(triangle, point: vertices[j]) {
                            containsOther = true
                            break
                        }
                    }

                    if !containsOther {
                        // Found an ear, clip it
                        triangles.append(triangle)
                        vertices.remove(at: i)
                        earFound = true
                        break
                    }
                }
            }

            if !earFound {
                attempts += 1
            }
        }

        // Remaining 3 vertices form the last triangle
        if vertices.count == 3 {
            triangles.append(vertices)
        }

        return triangles
    }

    // MARK: - Private Methods

    /// Determine if polygon is clockwise (using signed area)
    private func isClockwise(_ polygon: [CGPoint]) -> Bool {
        var sum: CGFloat = 0
        for i in 0..<polygon.count {
            let p1 = polygon[i]
            let p2 = polygon[(i + 1) % polygon.count]
            sum += (p2.x - p1.x) * (p2.y + p1.y)
        }
        return sum > 0
    }

    /// Check if vertex is convex (using cross product sign)
    private func isConvex(prev: CGPoint, curr: CGPoint, next: CGPoint, clockwise: Bool) -> Bool {
        let cross = crossProduct(
            CGPoint(x: curr.x - prev.x, y: curr.y - prev.y),
            CGPoint(x: next.x - curr.x, y: next.y - curr.y)
        )
        return clockwise ? cross < 0 : cross > 0
    }

    /// 2D cross product (Z component)
    private func crossProduct(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        return a.x * b.y - a.y * b.x
    }

    /// Check if point is inside triangle (using barycentric coordinates)
    private func triangleContainsPoint(_ triangle: [CGPoint], point: CGPoint) -> Bool {
        let p0 = triangle[0]
        let p1 = triangle[1]
        let p2 = triangle[2]

        let area = crossProduct(
            CGPoint(x: p1.x - p0.x, y: p1.y - p0.y),
            CGPoint(x: p2.x - p0.x, y: p2.y - p0.y)
        )

        // Degenerate triangle
        if abs(area) < 1e-10 { return false }

        let s = crossProduct(
            CGPoint(x: p1.x - p0.x, y: p1.y - p0.y),
            CGPoint(x: point.x - p0.x, y: point.y - p0.y)
        ) / area

        let t = crossProduct(
            CGPoint(x: point.x - p0.x, y: point.y - p0.y),
            CGPoint(x: p2.x - p0.x, y: p2.y - p0.y)
        ) / area

        // Strictly inside (not on boundary)
        return s > 0 && t > 0 && (s + t) < 1
    }
}
#endif
