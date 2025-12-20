//
//  CGPath.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//

import Foundation


/// Internal representation of a path element for storage
internal enum PathCommand: Sendable {
    case moveTo(CGPoint)
    case lineTo(CGPoint)
    case quadCurveTo(control: CGPoint, end: CGPoint)
    case curveTo(control1: CGPoint, control2: CGPoint, end: CGPoint)
    case closeSubpath
}

/// An immutable graphics path: a mathematical description of shapes or lines
/// to be drawn in a graphics context.
public class CGPath: @unchecked Sendable {

    internal var commands: [PathCommand]

    /// Creates an empty path.
    internal init() {
        self.commands = []
    }

    /// Creates a path from an array of commands.
    internal init(commands: [PathCommand]) {
        self.commands = commands
    }

    /// Create an immutable path of a rectangle.
    public convenience init(rect: CGRect, transform: UnsafePointer<CGAffineTransform>? = nil) {
        self.init()
        let t = transform?.pointee ?? CGAffineTransform.identity
        let p1 = CGPoint(x: rect.minX, y: rect.minY).applying(t)
        let p2 = CGPoint(x: rect.maxX, y: rect.minY).applying(t)
        let p3 = CGPoint(x: rect.maxX, y: rect.maxY).applying(t)
        let p4 = CGPoint(x: rect.minX, y: rect.maxY).applying(t)

        commands.append(.moveTo(p1))
        commands.append(.lineTo(p2))
        commands.append(.lineTo(p3))
        commands.append(.lineTo(p4))
        commands.append(.closeSubpath)
    }

    /// Create an immutable path of an ellipse.
    public convenience init(ellipseIn rect: CGRect, transform: UnsafePointer<CGAffineTransform>? = nil) {
        self.init()
        let t = transform?.pointee ?? CGAffineTransform.identity

        // Approximate ellipse with 4 bezier curves
        let cx = rect.midX
        let cy = rect.midY
        let rx = rect.width / 2
        let ry = rect.height / 2

        // Magic number for bezier approximation of circle: 4 * (sqrt(2) - 1) / 3
        let kappa = CGFloat(0.5522847498)
        let ox = rx * kappa
        let oy = ry * kappa

        let p0 = CGPoint(x: cx + rx, y: cy).applying(t)
        let p1 = CGPoint(x: cx + rx, y: cy + oy).applying(t)
        let p2 = CGPoint(x: cx + ox, y: cy + ry).applying(t)
        let p3 = CGPoint(x: cx, y: cy + ry).applying(t)
        let p4 = CGPoint(x: cx - ox, y: cy + ry).applying(t)
        let p5 = CGPoint(x: cx - rx, y: cy + oy).applying(t)
        let p6 = CGPoint(x: cx - rx, y: cy).applying(t)
        let p7 = CGPoint(x: cx - rx, y: cy - oy).applying(t)
        let p8 = CGPoint(x: cx - ox, y: cy - ry).applying(t)
        let p9 = CGPoint(x: cx, y: cy - ry).applying(t)
        let p10 = CGPoint(x: cx + ox, y: cy - ry).applying(t)
        let p11 = CGPoint(x: cx + rx, y: cy - oy).applying(t)

        commands.append(.moveTo(p0))
        commands.append(.curveTo(control1: p1, control2: p2, end: p3))
        commands.append(.curveTo(control1: p4, control2: p5, end: p6))
        commands.append(.curveTo(control1: p7, control2: p8, end: p9))
        commands.append(.curveTo(control1: p10, control2: p11, end: p0))
        commands.append(.closeSubpath)
    }

    /// Create an immutable path of a rounded rectangle.
    public convenience init(roundedRect rect: CGRect, cornerWidth: CGFloat, cornerHeight: CGFloat,
                           transform: UnsafePointer<CGAffineTransform>? = nil) {
        self.init()
        let t = transform?.pointee ?? CGAffineTransform.identity

        let cw = min(cornerWidth, rect.width / 2)
        let ch = min(cornerHeight, rect.height / 2)

        // Magic number for bezier approximation
        let kappa = CGFloat(0.5522847498)
        let ox = cw * kappa
        let oy = ch * kappa

        // Start from top-left after the corner
        let startPoint = CGPoint(x: rect.minX + cw, y: rect.minY).applying(t)
        commands.append(.moveTo(startPoint))

        // Top edge and top-right corner
        commands.append(.lineTo(CGPoint(x: rect.maxX - cw, y: rect.minY).applying(t)))
        commands.append(.curveTo(
            control1: CGPoint(x: rect.maxX - cw + ox, y: rect.minY).applying(t),
            control2: CGPoint(x: rect.maxX, y: rect.minY + ch - oy).applying(t),
            end: CGPoint(x: rect.maxX, y: rect.minY + ch).applying(t)
        ))

        // Right edge and bottom-right corner
        commands.append(.lineTo(CGPoint(x: rect.maxX, y: rect.maxY - ch).applying(t)))
        commands.append(.curveTo(
            control1: CGPoint(x: rect.maxX, y: rect.maxY - ch + oy).applying(t),
            control2: CGPoint(x: rect.maxX - cw + ox, y: rect.maxY).applying(t),
            end: CGPoint(x: rect.maxX - cw, y: rect.maxY).applying(t)
        ))

        // Bottom edge and bottom-left corner
        commands.append(.lineTo(CGPoint(x: rect.minX + cw, y: rect.maxY).applying(t)))
        commands.append(.curveTo(
            control1: CGPoint(x: rect.minX + cw - ox, y: rect.maxY).applying(t),
            control2: CGPoint(x: rect.minX, y: rect.maxY - ch + oy).applying(t),
            end: CGPoint(x: rect.minX, y: rect.maxY - ch).applying(t)
        ))

        // Left edge and top-left corner
        commands.append(.lineTo(CGPoint(x: rect.minX, y: rect.minY + ch).applying(t)))
        commands.append(.curveTo(
            control1: CGPoint(x: rect.minX, y: rect.minY + ch - oy).applying(t),
            control2: CGPoint(x: rect.minX + cw - ox, y: rect.minY).applying(t),
            end: startPoint
        ))

        commands.append(.closeSubpath)
    }

    // MARK: - Properties

    /// Returns the bounding box containing all points in a graphics path.
    public var boundingBox: CGRect {
        return boundingBoxOfPath
    }

    /// Returns the bounding box of a graphics path.
    public var boundingBoxOfPath: CGRect {
        if commands.isEmpty { return CGRect.null }

        var minX = CGFloat.infinity
        var minY = CGFloat.infinity
        var maxX = -CGFloat.infinity
        var maxY = -CGFloat.infinity

        for command in commands {
            switch command {
            case .moveTo(let point), .lineTo(let point):
                minX = min(minX, point.x)
                minY = min(minY, point.y)
                maxX = max(maxX, point.x)
                maxY = max(maxY, point.y)
            case .quadCurveTo(let control, let end):
                minX = min(minX, min(control.x, end.x))
                minY = min(minY, min(control.y, end.y))
                maxX = max(maxX, max(control.x, end.x))
                maxY = max(maxY, max(control.y, end.y))
            case .curveTo(let control1, let control2, let end):
                minX = min(minX, min(control1.x, min(control2.x, end.x)))
                minY = min(minY, min(control1.y, min(control2.y, end.y)))
                maxX = max(maxX, max(control1.x, max(control2.x, end.x)))
                maxY = max(maxY, max(control1.y, max(control2.y, end.y)))
            case .closeSubpath:
                break
            }
        }

        if minX == CGFloat.infinity {
            return CGRect.null
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Returns the current point in a graphics path.
    public var currentPoint: CGPoint {
        for command in commands.reversed() {
            switch command {
            case .moveTo(let point), .lineTo(let point):
                return point
            case .quadCurveTo(_, let end):
                return end
            case .curveTo(_, _, let end):
                return end
            case .closeSubpath:
                continue
            }
        }
        return CGPoint.zero
    }

    /// Indicates whether or not a graphics path is empty.
    public var isEmpty: Bool {
        return commands.isEmpty
    }

    // MARK: - Copying

    /// Creates an immutable copy of a graphics path.
    public func copy() -> CGPath? {
        return CGPath(commands: commands)
    }

    /// Creates an immutable copy of a graphics path transformed by a transformation matrix.
    public func copy(using transform: UnsafePointer<CGAffineTransform>?) -> CGPath? {
        guard let t = transform?.pointee else {
            return copy()
        }
        return CGPath(commands: commands.map { $0.applying(t) })
    }

    /// Creates a mutable copy of an existing graphics path.
    public func mutableCopy() -> CGMutablePath? {
        return CGMutablePath(commands: commands)
    }

    /// Creates a mutable copy of a graphics path transformed by a transformation matrix.
    public func mutableCopy(using transform: UnsafePointer<CGAffineTransform>?) -> CGMutablePath? {
        guard let t = transform?.pointee else {
            return mutableCopy()
        }
        return CGMutablePath(commands: commands.map { $0.applying(t) })
    }

    /// Creates a stroked copy of the path.
    ///
    /// This method creates a new path that represents the outline of the stroked
    /// version of the original path.
    ///
    /// - Parameters:
    ///   - lineWidth: The width of the stroke.
    ///   - lineCap: The line cap style.
    ///   - lineJoin: The line join style.
    ///   - miterLimit: The miter limit for sharp corners.
    ///   - transform: An optional transform to apply.
    /// - Returns: A new path representing the stroke outline.
    public func copy(strokingWithWidth lineWidth: CGFloat,
                     lineCap: CGLineCap,
                     lineJoin: CGLineJoin,
                     miterLimit: CGFloat,
                     transform: CGAffineTransform = .identity) -> CGPath {
        // Return empty path for zero or negative line width
        guard lineWidth > 0 else {
            return CGMutablePath()
        }

        let halfWidth = lineWidth / 2

        // Apply transform to commands if needed
        let transformedCommands: [PathCommand]
        if transform.isIdentity {
            transformedCommands = commands
        } else {
            transformedCommands = commands.map { $0.applying(transform) }
        }

        let strokedPath = CGMutablePath()

        // Process each subpath
        var subpathStart: CGPoint?
        var currentPoint: CGPoint = .zero
        var subpathPoints: [CGPoint] = []
        var isClosed = false

        func flushSubpath() {
            guard subpathPoints.count >= 2 else {
                subpathPoints.removeAll()
                return
            }

            // Generate stroke outline for this subpath
            generateStrokeOutline(
                points: subpathPoints,
                isClosed: isClosed,
                halfWidth: halfWidth,
                lineCap: lineCap,
                lineJoin: lineJoin,
                miterLimit: miterLimit,
                into: strokedPath
            )

            subpathPoints.removeAll()
            isClosed = false
        }

        for command in transformedCommands {
            switch command {
            case .moveTo(let point):
                flushSubpath()
                currentPoint = point
                subpathStart = point
                subpathPoints.append(point)

            case .lineTo(let point):
                subpathPoints.append(point)
                currentPoint = point

            case .quadCurveTo(let control, let end):
                // Flatten quadratic curve to line segments
                let segments = flattenQuadCurve(from: currentPoint, control: control, to: end)
                subpathPoints.append(contentsOf: segments)
                currentPoint = end

            case .curveTo(let control1, let control2, let end):
                // Flatten cubic curve to line segments
                let segments = flattenCubicCurve(from: currentPoint, control1: control1, control2: control2, to: end)
                subpathPoints.append(contentsOf: segments)
                currentPoint = end

            case .closeSubpath:
                if let start = subpathStart, currentPoint != start {
                    subpathPoints.append(start)
                }
                isClosed = true
                flushSubpath()
                if let start = subpathStart {
                    currentPoint = start
                }
            }
        }

        flushSubpath()

        return strokedPath
    }

    // MARK: - Stroke Outline Generation (Private)

    private func generateStrokeOutline(
        points: [CGPoint],
        isClosed: Bool,
        halfWidth: CGFloat,
        lineCap: CGLineCap,
        lineJoin: CGLineJoin,
        miterLimit: CGFloat,
        into path: CGMutablePath
    ) {
        guard points.count >= 2 else { return }

        var leftSide: [CGPoint] = []
        var rightSide: [CGPoint] = []

        // Generate offset points for each segment
        for i in 0..<(points.count - 1) {
            let p0 = points[i]
            let p1 = points[i + 1]

            let dx = p1.x - p0.x
            let dy = p1.y - p0.y
            let length = sqrt(dx * dx + dy * dy)

            guard length > 0.0001 else { continue }

            // Perpendicular unit vector
            let nx = -dy / length * halfWidth
            let ny = dx / length * halfWidth

            if leftSide.isEmpty {
                leftSide.append(CGPoint(x: p0.x + nx, y: p0.y + ny))
                rightSide.append(CGPoint(x: p0.x - nx, y: p0.y - ny))
            }

            // Handle line join with previous segment
            if i > 0 && !leftSide.isEmpty {
                let prevP = points[i - 1]
                let prevDx = p0.x - prevP.x
                let prevDy = p0.y - prevP.y
                let prevLength = sqrt(prevDx * prevDx + prevDy * prevDy)

                if prevLength > 0.0001 {
                    let prevNx = -prevDy / prevLength * halfWidth
                    let prevNy = prevDx / prevLength * halfWidth

                    // Add join points based on lineJoin style
                    switch lineJoin {
                    case .miter:
                        // For simplicity, just add both points (real miter needs intersection)
                        leftSide.append(CGPoint(x: p0.x + nx, y: p0.y + ny))
                        rightSide.append(CGPoint(x: p0.x - nx, y: p0.y - ny))
                    case .round:
                        // Add arc points (simplified)
                        leftSide.append(CGPoint(x: p0.x + (prevNx + nx) / 2, y: p0.y + (prevNy + ny) / 2))
                        leftSide.append(CGPoint(x: p0.x + nx, y: p0.y + ny))
                        rightSide.append(CGPoint(x: p0.x - (prevNx + nx) / 2, y: p0.y - (prevNy + ny) / 2))
                        rightSide.append(CGPoint(x: p0.x - nx, y: p0.y - ny))
                    case .bevel:
                        leftSide.append(CGPoint(x: p0.x + nx, y: p0.y + ny))
                        rightSide.append(CGPoint(x: p0.x - nx, y: p0.y - ny))
                    @unknown default:
                        leftSide.append(CGPoint(x: p0.x + nx, y: p0.y + ny))
                        rightSide.append(CGPoint(x: p0.x - nx, y: p0.y - ny))
                    }
                }
            }

            leftSide.append(CGPoint(x: p1.x + nx, y: p1.y + ny))
            rightSide.append(CGPoint(x: p1.x - nx, y: p1.y - ny))
        }

        guard !leftSide.isEmpty else { return }

        // Build the stroke outline path
        if isClosed {
            // For closed paths, connect left side to reversed right side
            path.move(to: leftSide[0])
            for i in 1..<leftSide.count {
                path.addLine(to: leftSide[i])
            }
            path.closeSubpath()

            path.move(to: rightSide[0])
            for i in 1..<rightSide.count {
                path.addLine(to: rightSide[i])
            }
            path.closeSubpath()
        } else {
            // For open paths, add end caps and create a single closed outline
            path.move(to: leftSide[0])

            // Left side forward
            for i in 1..<leftSide.count {
                path.addLine(to: leftSide[i])
            }

            // End cap at end
            addEndCap(at: points.last!,
                      leftPoint: leftSide.last!,
                      rightPoint: rightSide.last!,
                      style: lineCap,
                      into: path)

            // Right side backward
            for i in (0..<rightSide.count).reversed() {
                path.addLine(to: rightSide[i])
            }

            // End cap at start
            addEndCap(at: points.first!,
                      leftPoint: rightSide.first!,
                      rightPoint: leftSide.first!,
                      style: lineCap,
                      into: path)

            path.closeSubpath()
        }
    }

    private func addEndCap(at point: CGPoint,
                           leftPoint: CGPoint,
                           rightPoint: CGPoint,
                           style: CGLineCap,
                           into path: CGMutablePath) {
        switch style {
        case .butt:
            // Just connect directly
            path.addLine(to: rightPoint)

        case .round:
            // Add semicircle
            let centerX = (leftPoint.x + rightPoint.x) / 2
            let centerY = (leftPoint.y + rightPoint.y) / 2
            let radius = sqrt(pow(leftPoint.x - centerX, 2) + pow(leftPoint.y - centerY, 2))

            let startAngle = atan2(leftPoint.y - centerY, leftPoint.x - centerX)
            let endAngle = atan2(rightPoint.y - centerY, rightPoint.x - centerX)

            // Add arc (simplified - just add intermediate points)
            let steps = 8
            for i in 1...steps {
                let t = CGFloat(i) / CGFloat(steps)
                let angle = startAngle + (endAngle - startAngle + .pi) * t
                let x = centerX + radius * cos(angle)
                let y = centerY + radius * sin(angle)
                path.addLine(to: CGPoint(x: x, y: y))
            }

        case .square:
            // Extend by half width
            let dx = leftPoint.x - rightPoint.x
            let dy = leftPoint.y - rightPoint.y
            let length = sqrt(dx * dx + dy * dy)
            guard length > 0 else {
                path.addLine(to: rightPoint)
                return
            }
            let extend = length / 2
            let nx = dy / length * extend
            let ny = -dx / length * extend

            path.addLine(to: CGPoint(x: leftPoint.x + nx, y: leftPoint.y + ny))
            path.addLine(to: CGPoint(x: rightPoint.x + nx, y: rightPoint.y + ny))
            path.addLine(to: rightPoint)

        @unknown default:
            path.addLine(to: rightPoint)
        }
    }

    private func flattenQuadCurve(from start: CGPoint, control: CGPoint, to end: CGPoint) -> [CGPoint] {
        var points: [CGPoint] = []
        let steps = 8
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let mt = 1 - t
            let x = mt * mt * start.x + 2 * mt * t * control.x + t * t * end.x
            let y = mt * mt * start.y + 2 * mt * t * control.y + t * t * end.y
            points.append(CGPoint(x: x, y: y))
        }
        return points
    }

    private func flattenCubicCurve(from start: CGPoint, control1: CGPoint, control2: CGPoint, to end: CGPoint) -> [CGPoint] {
        var points: [CGPoint] = []
        let steps = 12
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let mt = 1 - t
            let mt2 = mt * mt
            let mt3 = mt2 * mt
            let t2 = t * t
            let t3 = t2 * t
            let x = mt3 * start.x + 3 * mt2 * t * control1.x + 3 * mt * t2 * control2.x + t3 * end.x
            let y = mt3 * start.y + 3 * mt2 * t * control1.y + 3 * mt * t2 * control2.y + t3 * end.y
            points.append(CGPoint(x: x, y: y))
        }
        return points
    }

    // MARK: - Examining

    /// Returns whether the specified point is interior to the path.
    public func contains(_ point: CGPoint, using rule: CGPathFillRule = .winding,
                         transform: CGAffineTransform = .identity) -> Bool {
        // Transform the point first (inverse transform to convert from user space to path space)
        let testPoint = point.applying(transform.inverted())

        // Simple bounding box check using the transformed point
        let bbox: CGRect = boundingBoxOfPath
        let bboxIsNull: Bool = bbox.isNull
        let bboxContainsPoint: Bool = bbox.contains(testPoint)
        if bboxIsNull || !bboxContainsPoint {
            return false
        }

        // Use ray casting algorithm for point-in-polygon test
        // Count intersections for each subpath
        var windingNumber = 0
        var currentPoint = CGPoint.zero
        var subpathStart = CGPoint.zero

        for command in commands {
            switch command {
            case .moveTo(let p):
                currentPoint = p
                subpathStart = p

            case .lineTo(let p):
                windingNumber += countRayIntersections(testPoint, from: currentPoint, to: p)
                currentPoint = p

            case .quadCurveTo(let control, let end):
                // Flatten quadratic curve and test each segment
                let segments = flattenQuadCurveForContainment(from: currentPoint, control: control, to: end)
                var prev = currentPoint
                for segmentEnd in segments {
                    windingNumber += countRayIntersections(testPoint, from: prev, to: segmentEnd)
                    prev = segmentEnd
                }
                currentPoint = end

            case .curveTo(let control1, let control2, let end):
                // Flatten cubic curve and test each segment
                let segments = flattenCubicCurveForContainment(from: currentPoint, control1: control1, control2: control2, to: end)
                var prev = currentPoint
                for segmentEnd in segments {
                    windingNumber += countRayIntersections(testPoint, from: prev, to: segmentEnd)
                    prev = segmentEnd
                }
                currentPoint = end

            case .closeSubpath:
                windingNumber += countRayIntersections(testPoint, from: currentPoint, to: subpathStart)
                currentPoint = subpathStart
            }
        }

        // Apply fill rule
        switch rule {
        case .winding:
            return windingNumber != 0
        case .evenOdd:
            return (windingNumber & 1) != 0
        @unknown default:
            return windingNumber != 0
        }
    }

    /// Counts ray intersections for winding number calculation.
    /// Returns +1 for upward crossing, -1 for downward crossing, 0 for no intersection.
    private func countRayIntersections(_ point: CGPoint, from p1: CGPoint, to p2: CGPoint) -> Int {
        // Ray casting from point going right (positive x direction)
        // Using winding number algorithm

        // Check if segment crosses the horizontal line at point.y
        if p1.y <= point.y {
            if p2.y > point.y {
                // Upward crossing
                let vt = (point.y - p1.y) / (p2.y - p1.y)
                let xIntersection = p1.x + vt * (p2.x - p1.x)
                if point.x < xIntersection {
                    return 1  // Upward crossing to the right
                }
            }
        } else {
            if p2.y <= point.y {
                // Downward crossing
                let vt = (point.y - p1.y) / (p2.y - p1.y)
                let xIntersection = p1.x + vt * (p2.x - p1.x)
                if point.x < xIntersection {
                    return -1  // Downward crossing to the right
                }
            }
        }

        return 0
    }

    /// Flattens quadratic curve for containment testing with adaptive subdivision.
    private func flattenQuadCurveForContainment(from start: CGPoint, control: CGPoint, to end: CGPoint) -> [CGPoint] {
        var points: [CGPoint] = []

        // Use adaptive subdivision based on curve flatness
        func subdivide(p0: CGPoint, p1: CGPoint, p2: CGPoint, depth: Int) {
            // Check if curve is flat enough
            let flatness = quadraticFlatness(p0: p0, p1: p1, p2: p2)
            if flatness < 0.5 || depth > 10 {
                points.append(p2)
                return
            }

            // Subdivide using de Casteljau's algorithm
            let p01 = CGPoint(x: (p0.x + p1.x) / 2, y: (p0.y + p1.y) / 2)
            let p12 = CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
            let p012 = CGPoint(x: (p01.x + p12.x) / 2, y: (p01.y + p12.y) / 2)

            subdivide(p0: p0, p1: p01, p2: p012, depth: depth + 1)
            subdivide(p0: p012, p1: p12, p2: p2, depth: depth + 1)
        }

        subdivide(p0: start, p1: control, p2: end, depth: 0)
        return points
    }

    /// Flattens cubic curve for containment testing with adaptive subdivision.
    private func flattenCubicCurveForContainment(from start: CGPoint, control1: CGPoint, control2: CGPoint, to end: CGPoint) -> [CGPoint] {
        var points: [CGPoint] = []

        // Use adaptive subdivision based on curve flatness
        func subdivide(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, depth: Int) {
            // Check if curve is flat enough
            let flatness = cubicFlatness(p0: p0, p1: p1, p2: p2, p3: p3)
            if flatness < 0.5 || depth > 10 {
                points.append(p3)
                return
            }

            // Subdivide using de Casteljau's algorithm
            let p01 = CGPoint(x: (p0.x + p1.x) / 2, y: (p0.y + p1.y) / 2)
            let p12 = CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
            let p23 = CGPoint(x: (p2.x + p3.x) / 2, y: (p2.y + p3.y) / 2)
            let p012 = CGPoint(x: (p01.x + p12.x) / 2, y: (p01.y + p12.y) / 2)
            let p123 = CGPoint(x: (p12.x + p23.x) / 2, y: (p12.y + p23.y) / 2)
            let p0123 = CGPoint(x: (p012.x + p123.x) / 2, y: (p012.y + p123.y) / 2)

            subdivide(p0: p0, p1: p01, p2: p012, p3: p0123, depth: depth + 1)
            subdivide(p0: p0123, p1: p123, p2: p23, p3: p3, depth: depth + 1)
        }

        subdivide(p0: start, p1: control1, p2: control2, p3: end, depth: 0)
        return points
    }

    /// Calculate flatness of a quadratic bezier curve.
    /// Returns the maximum distance from control point to the line connecting start and end.
    private func quadraticFlatness(p0: CGPoint, p1: CGPoint, p2: CGPoint) -> CGFloat {
        // Distance from control point to line p0-p2
        let dx = p2.x - p0.x
        let dy = p2.y - p0.y
        let d = sqrt(dx * dx + dy * dy)

        if d < 0.0001 {
            return sqrt(pow(p1.x - p0.x, 2) + pow(p1.y - p0.y, 2))
        }

        let t = ((p1.x - p0.x) * dx + (p1.y - p0.y) * dy) / (d * d)
        let projX = p0.x + t * dx
        let projY = p0.y + t * dy

        return sqrt(pow(p1.x - projX, 2) + pow(p1.y - projY, 2))
    }

    /// Calculate flatness of a cubic bezier curve.
    /// Returns the maximum distance from control points to the line connecting start and end.
    private func cubicFlatness(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint) -> CGFloat {
        // Maximum distance from control points to line p0-p3
        let dx = p3.x - p0.x
        let dy = p3.y - p0.y
        let d = sqrt(dx * dx + dy * dy)

        if d < 0.0001 {
            let d1 = sqrt(pow(p1.x - p0.x, 2) + pow(p1.y - p0.y, 2))
            let d2 = sqrt(pow(p2.x - p0.x, 2) + pow(p2.y - p0.y, 2))
            return max(d1, d2)
        }

        // Distance from p1 to line
        let t1 = ((p1.x - p0.x) * dx + (p1.y - p0.y) * dy) / (d * d)
        let proj1X = p0.x + t1 * dx
        let proj1Y = p0.y + t1 * dy
        let dist1 = sqrt(pow(p1.x - proj1X, 2) + pow(p1.y - proj1Y, 2))

        // Distance from p2 to line
        let t2 = ((p2.x - p0.x) * dx + (p2.y - p0.y) * dy) / (d * d)
        let proj2X = p0.x + t2 * dx
        let proj2Y = p0.y + t2 * dy
        let dist2 = sqrt(pow(p2.x - proj2X, 2) + pow(p2.y - proj2Y, 2))

        return max(dist1, dist2)
    }

    /// Indicates whether or not a graphics path represents a rectangle.
    public func isRect(_ rect: UnsafeMutablePointer<CGRect>?) -> Bool {
        // Check if path represents a simple rectangle
        guard commands.count == 5 else { return false }

        var points: [CGPoint] = []
        for command in commands {
            switch command {
            case .moveTo(let p), .lineTo(let p):
                points.append(p)
            case .closeSubpath:
                break
            default:
                return false
            }
        }

        guard points.count == 4 else { return false }

        // Check if it forms a rectangle (axis-aligned)
        let xs = Set(points.map { $0.x })
        let ys = Set(points.map { $0.y })

        if xs.count == 2 && ys.count == 2 {
            let minX = xs.min()!
            let maxX = xs.max()!
            let minY = ys.min()!
            let maxY = ys.max()!
            rect?.pointee = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            return true
        }

        return false
    }

    // MARK: - Apply

    /// For each element in a graphics path, calls a custom applier function.
    public func apply(info: UnsafeMutableRawPointer?, function: CGPathApplierFunction) {
        for command in commands {
            switch command {
            case .moveTo(var point):
                var element = CGPathElement(type: .moveToPoint, points: &point)
                withUnsafePointer(to: &element) { function(info, $0) }

            case .lineTo(var point):
                var element = CGPathElement(type: .addLineToPoint, points: &point)
                withUnsafePointer(to: &element) { function(info, $0) }

            case .quadCurveTo(let control, let end):
                var points = [control, end]
                points.withUnsafeMutableBufferPointer { buffer in
                    var element = CGPathElement(type: .addQuadCurveToPoint, points: buffer.baseAddress)
                    withUnsafePointer(to: &element) { function(info, $0) }
                }

            case .curveTo(let control1, let control2, let end):
                var points = [control1, control2, end]
                points.withUnsafeMutableBufferPointer { buffer in
                    var element = CGPathElement(type: .addCurveToPoint, points: buffer.baseAddress)
                    withUnsafePointer(to: &element) { function(info, $0) }
                }

            case .closeSubpath:
                var element = CGPathElement(type: .closeSubpath, points: nil)
                withUnsafePointer(to: &element) { function(info, $0) }
            }
        }
    }

    /// For each element in a graphics path, calls a custom block.
    public func applyWithBlock(_ block: (UnsafePointer<CGPathElement>) -> Void) {
        for command in commands {
            switch command {
            case .moveTo(var point):
                var element = CGPathElement(type: .moveToPoint, points: &point)
                withUnsafePointer(to: &element) { block($0) }

            case .lineTo(var point):
                var element = CGPathElement(type: .addLineToPoint, points: &point)
                withUnsafePointer(to: &element) { block($0) }

            case .quadCurveTo(let control, let end):
                var points = [control, end]
                points.withUnsafeMutableBufferPointer { buffer in
                    var element = CGPathElement(type: .addQuadCurveToPoint, points: buffer.baseAddress)
                    withUnsafePointer(to: &element) { block($0) }
                }

            case .curveTo(let control1, let control2, let end):
                var points = [control1, control2, end]
                points.withUnsafeMutableBufferPointer { buffer in
                    var element = CGPathElement(type: .addCurveToPoint, points: buffer.baseAddress)
                    withUnsafePointer(to: &element) { block($0) }
                }

            case .closeSubpath:
                var element = CGPathElement(type: .closeSubpath, points: nil)
                withUnsafePointer(to: &element) { block($0) }
            }
        }
    }
}

// MARK: - Equatable

extension CGPath: Equatable {
    public static func == (lhs: CGPath, rhs: CGPath) -> Bool {
        guard lhs.commands.count == rhs.commands.count else { return false }
        for (l, r) in zip(lhs.commands, rhs.commands) {
            if !l.isEqual(to: r) { return false }
        }
        return true
    }
}

// MARK: - Hashable

extension CGPath: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(commands.count)
        for command in commands {
            command.hash(into: &hasher)
        }
    }
}

// MARK: - PathCommand Extensions

extension PathCommand {
    func applying(_ transform: CGAffineTransform) -> PathCommand {
        switch self {
        case .moveTo(let point):
            return .moveTo(point.applying(transform))
        case .lineTo(let point):
            return .lineTo(point.applying(transform))
        case .quadCurveTo(let control, let end):
            return .quadCurveTo(control: control.applying(transform), end: end.applying(transform))
        case .curveTo(let control1, let control2, let end):
            return .curveTo(control1: control1.applying(transform),
                           control2: control2.applying(transform),
                           end: end.applying(transform))
        case .closeSubpath:
            return .closeSubpath
        }
    }

    func isEqual(to other: PathCommand) -> Bool {
        switch (self, other) {
        case (.moveTo(let p1), .moveTo(let p2)):
            return p1 == p2
        case (.lineTo(let p1), .lineTo(let p2)):
            return p1 == p2
        case (.quadCurveTo(let c1, let e1), .quadCurveTo(let c2, let e2)):
            return c1 == c2 && e1 == e2
        case (.curveTo(let c11, let c12, let e1), .curveTo(let c21, let c22, let e2)):
            return c11 == c21 && c12 == c22 && e1 == e2
        case (.closeSubpath, .closeSubpath):
            return true
        default:
            return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .moveTo(let point):
            hasher.combine(0)
            hasher.combine(point)
        case .lineTo(let point):
            hasher.combine(1)
            hasher.combine(point)
        case .quadCurveTo(let control, let end):
            hasher.combine(2)
            hasher.combine(control)
            hasher.combine(end)
        case .curveTo(let control1, let control2, let end):
            hasher.combine(3)
            hasher.combine(control1)
            hasher.combine(control2)
            hasher.combine(end)
        case .closeSubpath:
            hasher.combine(4)
        }
    }
}

