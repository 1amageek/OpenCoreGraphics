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
        guard !commands.isEmpty else { return .null }

        var bounds = CGRect.null
        for command in commands {
            switch command {
            case .moveTo(let point), .lineTo(let point):
                bounds = bounds.including(point)
            case .quadCurveTo(let control, let end):
                bounds = bounds.including(control).including(end)
            case .curveTo(let control1, let control2, let end):
                bounds = bounds.including(control1).including(control2).including(end)
            case .closeSubpath:
                break
            }
        }
        return bounds
    }

    /// Returns the tight bounding box of the rendered path geometry.
    public var boundingBoxOfPath: CGRect {
        guard !commands.isEmpty else { return .null }

        var bounds = CGRect.null
        var currentPoint = CGPoint.zero
        var hasCurrentPoint = false
        for command in commands {
            switch command {
            case .moveTo(let point):
                bounds = bounds.including(point)
                currentPoint = point
                hasCurrentPoint = true

            case .lineTo(let point):
                guard hasCurrentPoint else { continue }
                bounds = bounds.including(point)
                currentPoint = point

            case .quadCurveTo(let control, let end):
                guard hasCurrentPoint else { continue }
                bounds = bounds.includingQuadraticCurve(
                    start: currentPoint,
                    control: control,
                    end: end
                )
                currentPoint = end

            case .curveTo(let control1, let control2, let end):
                guard hasCurrentPoint else { continue }
                bounds = bounds.includingCubicCurve(
                    start: currentPoint,
                    control1: control1,
                    control2: control2,
                    end: end
                )
                currentPoint = end

            case .closeSubpath:
                break
            }
        }
        return bounds
    }

    /// Returns the current point in a graphics path.
    public var currentPoint: CGPoint {
        var needsSubpathStart = false
        for command in commands.reversed() {
            switch command {
            case .moveTo(let point):
                return point
            case .lineTo(let point):
                if needsSubpathStart { continue }
                return point
            case .quadCurveTo(_, let end):
                if needsSubpathStart { continue }
                return end
            case .curveTo(_, _, let end):
                if needsSubpathStart { continue }
                return end
            case .closeSubpath:
                needsSubpathStart = true
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
    public func copy(strokingWithWidth lineWidth: CGFloat,
                     lineCap: CGLineCap,
                     lineJoin: CGLineJoin,
                     miterLimit: CGFloat,
                     transform: CGAffineTransform = .identity) -> CGPath {
        CGStrokeGeometry.make(
            path: self,
            lineWidth: lineWidth,
            lineCap: lineCap,
            lineJoin: lineJoin,
            miterLimit: miterLimit,
            transform: transform
        ).path
    }

    // MARK: - Examining

    /// Returns whether the specified point is interior to the path.
    public func contains(_ point: CGPoint, using rule: CGPathFillRule = .winding,
                         transform: CGAffineTransform = .identity) -> Bool {
        let sourcePath: CGPath
        if transform.isIdentity {
            sourcePath = self
        } else {
            var transform = transform
            sourcePath = withUnsafePointer(to: &transform) { pointer in
                copy(using: pointer) ?? CGPath()
            }
        }

        let bounds = sourcePath.boundingBoxOfPath
        guard !bounds.isNull, bounds.contains(point) else { return false }
        let scale = max(1, max(abs(bounds.width), abs(bounds.height)))
        let tolerance = max(
            scale * CGFloat.ulpOfOne * 64,
            min(0.01, scale * 1e-7)
        )
        return _isInside(
            point,
            in: sourcePath._flattenToSubpaths(threshold: tolerance),
            rule: rule
        )
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
