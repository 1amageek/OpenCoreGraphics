//
//  StrokeGenerator.swift
//  CGWebGPU
//
//  Generates triangle meshes for stroke rendering with line caps and joins
//

#if arch(wasm32)
import Foundation

/// Generates triangle meshes for strokes (lines)
public struct StrokeGenerator: Sendable {

    /// Line cap style
    public enum LineCap: Sendable {
        case butt    // Cut off at endpoint
        case round   // Semicircle at endpoint
        case square  // Extend by half width as rectangle
    }

    /// Line join style
    public enum LineJoin: Sendable {
        case miter   // Sharp corner
        case round   // Rounded corner
        case bevel   // Flat corner
    }

    /// Number of segments for round caps/joins
    public var roundSegments: Int = 8

    public init() {}

    // MARK: - Line Cap

    /// Generate line cap vertices
    /// - Parameters:
    ///   - point: Endpoint coordinate
    ///   - direction: Direction of the line (pointing outward from endpoint)
    ///   - halfWidth: Half of line width
    ///   - style: Cap style
    /// - Returns: Array of triangle vertices
    public func generateCap(
        at point: CGPoint,
        direction: CGVector,
        halfWidth: CGFloat,
        style: LineCap
    ) -> [CGPoint] {
        let normalizedDir = direction.normalized
        let normal = CGVector(dx: -normalizedDir.dy, dy: normalizedDir.dx)

        switch style {
        case .butt:
            // No additional geometry
            return []

        case .square:
            // Extend by half width as rectangle
            let extend = normalizedDir * halfWidth
            let p0 = CGPoint(x: point.x + normal.dx * halfWidth,
                            y: point.y + normal.dy * halfWidth)
            let p1 = CGPoint(x: point.x - normal.dx * halfWidth,
                            y: point.y - normal.dy * halfWidth)
            let p2 = CGPoint(x: p1.x + extend.dx, y: p1.y + extend.dy)
            let p3 = CGPoint(x: p0.x + extend.dx, y: p0.y + extend.dy)
            // Two triangles
            return [p0, p1, p2, p0, p2, p3]

        case .round:
            // Generate semicircle
            var vertices: [CGPoint] = []
            let startAngle = atan2(normal.dy, normal.dx)

            for i in 0..<roundSegments {
                let a0 = startAngle + CGFloat(i) * .pi / CGFloat(roundSegments)
                let a1 = startAngle + CGFloat(i + 1) * .pi / CGFloat(roundSegments)

                let v0 = CGPoint(x: point.x + cos(a0) * halfWidth,
                                y: point.y + sin(a0) * halfWidth)
                let v1 = CGPoint(x: point.x + cos(a1) * halfWidth,
                                y: point.y + sin(a1) * halfWidth)

                vertices.append(contentsOf: [point, v0, v1])
            }
            return vertices
        }
    }

    // MARK: - Line Join

    /// Generate line join vertices
    /// - Parameters:
    ///   - point: Join point
    ///   - incoming: Direction of incoming line segment
    ///   - outgoing: Direction of outgoing line segment
    ///   - halfWidth: Half of line width
    ///   - style: Join style
    ///   - miterLimit: Miter limit (for miter style)
    /// - Returns: Array of triangle vertices
    public func generateJoin(
        at point: CGPoint,
        incoming: CGVector,
        outgoing: CGVector,
        halfWidth: CGFloat,
        style: LineJoin,
        miterLimit: CGFloat = 10
    ) -> [CGPoint] {
        let inNorm = incoming.normalized
        let outNorm = outgoing.normalized

        let n1 = CGVector(dx: -inNorm.dy, dy: inNorm.dx)
        let n2 = CGVector(dx: -outNorm.dy, dy: outNorm.dx)

        // Calculate angle
        let cross = inNorm.dx * outNorm.dy - inNorm.dy * outNorm.dx
        let dot = inNorm.dx * outNorm.dx + inNorm.dy * outNorm.dy
        let angle = atan2(cross, dot)

        // Straight line - no join needed
        if abs(angle) < 0.01 { return [] }

        // Determine if turning left or right
        let isLeft = angle > 0

        switch style {
        case .bevel:
            // Simple triangle fill
            let p1 = CGPoint(x: point.x + (isLeft ? n1.dx : -n1.dx) * halfWidth,
                            y: point.y + (isLeft ? n1.dy : -n1.dy) * halfWidth)
            let p2 = CGPoint(x: point.x + (isLeft ? n2.dx : -n2.dx) * halfWidth,
                            y: point.y + (isLeft ? n2.dy : -n2.dy) * halfWidth)
            return [point, p1, p2]

        case .round:
            // Arc fill
            var vertices: [CGPoint] = []
            let startAngle = atan2(isLeft ? n1.dy : -n1.dy, isLeft ? n1.dx : -n1.dx)
            let endAngle = atan2(isLeft ? n2.dy : -n2.dy, isLeft ? n2.dx : -n2.dx)
            var deltaAngle = endAngle - startAngle

            // Normalize angle
            if isLeft && deltaAngle < 0 { deltaAngle += 2 * .pi }
            if !isLeft && deltaAngle > 0 { deltaAngle -= 2 * .pi }

            let steps = max(2, Int(abs(deltaAngle) / (.pi / CGFloat(roundSegments))))

            for i in 0..<steps {
                let a0 = startAngle + deltaAngle * CGFloat(i) / CGFloat(steps)
                let a1 = startAngle + deltaAngle * CGFloat(i + 1) / CGFloat(steps)

                let v0 = CGPoint(x: point.x + cos(a0) * halfWidth,
                                y: point.y + sin(a0) * halfWidth)
                let v1 = CGPoint(x: point.x + cos(a1) * halfWidth,
                                y: point.y + sin(a1) * halfWidth)

                vertices.append(contentsOf: [point, v0, v1])
            }
            return vertices

        case .miter:
            // Calculate miter intersection
            let miterLen = halfWidth / cos(angle / 2)

            // Check miter limit
            if abs(miterLen) > halfWidth * miterLimit {
                // Fallback to bevel
                return generateJoin(at: point, incoming: incoming, outgoing: outgoing,
                                   halfWidth: halfWidth, style: .bevel)
            }

            // Miter direction
            let miterDir = CGVector(
                dx: n1.dx + n2.dx,
                dy: n1.dy + n2.dy
            ).normalized

            let miterPoint = CGPoint(
                x: point.x + (isLeft ? miterDir.dx : -miterDir.dx) * abs(miterLen),
                y: point.y + (isLeft ? miterDir.dy : -miterDir.dy) * abs(miterLen)
            )

            let p1 = CGPoint(x: point.x + (isLeft ? n1.dx : -n1.dx) * halfWidth,
                            y: point.y + (isLeft ? n1.dy : -n1.dy) * halfWidth)
            let p2 = CGPoint(x: point.x + (isLeft ? n2.dx : -n2.dx) * halfWidth,
                            y: point.y + (isLeft ? n2.dy : -n2.dy) * halfWidth)

            return [point, p1, miterPoint, point, miterPoint, p2]
        }
    }
}

// MARK: - CGVector Extensions

extension CGVector {
    /// Normalized vector (unit length)
    var normalized: CGVector {
        let len = sqrt(dx * dx + dy * dy)
        guard len > 0 else { return self }
        return CGVector(dx: dx / len, dy: dy / len)
    }

    /// Scalar multiplication
    static func * (lhs: CGVector, rhs: CGFloat) -> CGVector {
        return CGVector(dx: lhs.dx * rhs, dy: lhs.dy * rhs)
    }
}
#endif
