//
//  CGMutablePath.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//


import Foundation


/// A mutable graphics path: a mathematical description of shapes or lines
/// to be drawn in a graphics context.
public class CGMutablePath: CGPath, @unchecked Sendable {

    /// Creates a mutable graphics path.
    public override init() {
        super.init()
    }

    /// Creates a mutable path from an array of commands.
    internal override init(commands: [PathCommand]) {
        super.init(commands: commands)
    }

    // MARK: - Constructing a Graphics Path

    /// Begins a new subpath at the specified point.
    public func move(to point: CGPoint, transform: CGAffineTransform = .identity) {
        commands.append(.moveTo(point.applying(transform)))
    }

    /// Appends a straight line segment from the current point to the specified point.
    public func addLine(to point: CGPoint, transform: CGAffineTransform = .identity) {
        commands.append(.lineTo(point.applying(transform)))
    }

    /// Adds a sequence of connected straight-line segments to the path.
    public func addLines(between points: [CGPoint], transform: CGAffineTransform = .identity) {
        guard !points.isEmpty else { return }
        commands.append(.moveTo(points[0].applying(transform)))
        for i in 1..<points.count {
            commands.append(.lineTo(points[i].applying(transform)))
        }
    }

    /// Adds a rectangular subpath to the path.
    public func addRect(_ rect: CGRect, transform: CGAffineTransform = .identity) {
        let p1 = CGPoint(x: rect.minX, y: rect.minY).applying(transform)
        let p2 = CGPoint(x: rect.maxX, y: rect.minY).applying(transform)
        let p3 = CGPoint(x: rect.maxX, y: rect.maxY).applying(transform)
        let p4 = CGPoint(x: rect.minX, y: rect.maxY).applying(transform)

        commands.append(.moveTo(p1))
        commands.append(.lineTo(p2))
        commands.append(.lineTo(p3))
        commands.append(.lineTo(p4))
        commands.append(.closeSubpath)
    }

    /// Adds a set of rectangular subpaths to the path.
    public func addRects(_ rects: [CGRect], transform: CGAffineTransform = .identity) {
        for rect in rects {
            addRect(rect, transform: transform)
        }
    }

    /// Adds an ellipse that fits inside the specified rectangle.
    public func addEllipse(in rect: CGRect, transform: CGAffineTransform = .identity) {
        // Approximate ellipse with 4 bezier curves
        let cx = rect.midX
        let cy = rect.midY
        let rx = rect.width / 2
        let ry = rect.height / 2

        // Magic number for bezier approximation of circle: 4 * (sqrt(2) - 1) / 3
        let kappa = CGFloat(0.5522847498)
        let ox = rx * kappa
        let oy = ry * kappa

        let p0 = CGPoint(x: cx + rx, y: cy).applying(transform)
        let p1 = CGPoint(x: cx + rx, y: cy + oy).applying(transform)
        let p2 = CGPoint(x: cx + ox, y: cy + ry).applying(transform)
        let p3 = CGPoint(x: cx, y: cy + ry).applying(transform)
        let p4 = CGPoint(x: cx - ox, y: cy + ry).applying(transform)
        let p5 = CGPoint(x: cx - rx, y: cy + oy).applying(transform)
        let p6 = CGPoint(x: cx - rx, y: cy).applying(transform)
        let p7 = CGPoint(x: cx - rx, y: cy - oy).applying(transform)
        let p8 = CGPoint(x: cx - ox, y: cy - ry).applying(transform)
        let p9 = CGPoint(x: cx, y: cy - ry).applying(transform)
        let p10 = CGPoint(x: cx + ox, y: cy - ry).applying(transform)
        let p11 = CGPoint(x: cx + rx, y: cy - oy).applying(transform)

        commands.append(.moveTo(p0))
        commands.append(.curveTo(control1: p1, control2: p2, end: p3))
        commands.append(.curveTo(control1: p4, control2: p5, end: p6))
        commands.append(.curveTo(control1: p7, control2: p8, end: p9))
        commands.append(.curveTo(control1: p10, control2: p11, end: p0))
        commands.append(.closeSubpath)
    }

    /// Adds a subpath to the path, in the shape of a rectangle with rounded corners.
    public func addRoundedRect(in rect: CGRect, cornerWidth: CGFloat, cornerHeight: CGFloat,
                                transform: CGAffineTransform = .identity) {
        let cw = min(cornerWidth, rect.width / 2)
        let ch = min(cornerHeight, rect.height / 2)

        // Magic number for bezier approximation
        let kappa = CGFloat(0.5522847498)
        let ox = cw * kappa
        let oy = ch * kappa

        // Start from top-left after the corner
        let startPoint = CGPoint(x: rect.minX + cw, y: rect.minY).applying(transform)
        commands.append(.moveTo(startPoint))

        // Top edge and top-right corner
        commands.append(.lineTo(CGPoint(x: rect.maxX - cw, y: rect.minY).applying(transform)))
        commands.append(.curveTo(
            control1: CGPoint(x: rect.maxX - cw + ox, y: rect.minY).applying(transform),
            control2: CGPoint(x: rect.maxX, y: rect.minY + ch - oy).applying(transform),
            end: CGPoint(x: rect.maxX, y: rect.minY + ch).applying(transform)
        ))

        // Right edge and bottom-right corner
        commands.append(.lineTo(CGPoint(x: rect.maxX, y: rect.maxY - ch).applying(transform)))
        commands.append(.curveTo(
            control1: CGPoint(x: rect.maxX, y: rect.maxY - ch + oy).applying(transform),
            control2: CGPoint(x: rect.maxX - cw + ox, y: rect.maxY).applying(transform),
            end: CGPoint(x: rect.maxX - cw, y: rect.maxY).applying(transform)
        ))

        // Bottom edge and bottom-left corner
        commands.append(.lineTo(CGPoint(x: rect.minX + cw, y: rect.maxY).applying(transform)))
        commands.append(.curveTo(
            control1: CGPoint(x: rect.minX + cw - ox, y: rect.maxY).applying(transform),
            control2: CGPoint(x: rect.minX, y: rect.maxY - ch + oy).applying(transform),
            end: CGPoint(x: rect.minX, y: rect.maxY - ch).applying(transform)
        ))

        // Left edge and top-left corner
        commands.append(.lineTo(CGPoint(x: rect.minX, y: rect.minY + ch).applying(transform)))
        commands.append(.curveTo(
            control1: CGPoint(x: rect.minX, y: rect.minY + ch - oy).applying(transform),
            control2: CGPoint(x: rect.minX + cw - ox, y: rect.minY).applying(transform),
            end: startPoint
        ))

        commands.append(.closeSubpath)
    }

    /// Adds an arc of a circle to the path, specified with a radius and angles.
    public func addArc(center: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat,
                       clockwise: Bool, transform: CGAffineTransform = .identity) {
        // Calculate start and end points
        let startPoint = CGPoint(
            x: center.x + radius * cos(startAngle),
            y: center.y + radius * sin(startAngle)
        ).applying(transform)

        if commands.isEmpty {
            commands.append(.moveTo(startPoint))
        } else {
            commands.append(.lineTo(startPoint))
        }

        // Approximate arc with bezier curves
        var angle = startAngle
        let targetAngle = endAngle
        let direction: CGFloat = clockwise ? -1.0 : 1.0
        let step = CGFloat.pi / 2 * direction

        while (clockwise ? angle > targetAngle : angle < targetAngle) {
            let nextAngle: CGFloat
            if clockwise {
                nextAngle = max(targetAngle, angle + step)
            } else {
                nextAngle = min(targetAngle, angle + step)
            }

            addArcSegment(center: center, radius: radius, startAngle: angle,
                         endAngle: nextAngle, transform: transform)
            angle = nextAngle
        }
    }

    private func addArcSegment(center: CGPoint, radius: CGFloat, startAngle: CGFloat,
                               endAngle: CGFloat, transform: CGAffineTransform) {
        let angleDiff = endAngle - startAngle
        let halfAngle = angleDiff / 2

        // Control point distance
        let k = CGFloat(4.0 / 3.0) * (1.0 - cos(halfAngle)) / sin(halfAngle)

        let p0 = CGPoint(
            x: center.x + radius * cos(startAngle),
            y: center.y + radius * sin(startAngle)
        )
        let p3 = CGPoint(
            x: center.x + radius * cos(endAngle),
            y: center.y + radius * sin(endAngle)
        )
        let p1 = CGPoint(
            x: p0.x - k * radius * sin(startAngle),
            y: p0.y + k * radius * cos(startAngle)
        )
        let p2 = CGPoint(
            x: p3.x + k * radius * sin(endAngle),
            y: p3.y - k * radius * cos(endAngle)
        )

        commands.append(.curveTo(
            control1: p1.applying(transform),
            control2: p2.applying(transform),
            end: p3.applying(transform)
        ))
    }

    /// Adds an arc of a circle to the path, specified with a radius and two tangent lines.
    public func addArc(tangent1End: CGPoint, tangent2End: CGPoint, radius: CGFloat,
                       transform: CGAffineTransform = .identity) {
        guard !commands.isEmpty else { return }

        // Get current point
        let p0 = currentPoint

        // Calculate vectors
        let v1 = CGPoint(x: tangent1End.x - p0.x, y: tangent1End.y - p0.y)
        let v2 = CGPoint(x: tangent2End.x - tangent1End.x, y: tangent2End.y - tangent1End.y)

        // Normalize vectors
        let len1 = sqrt(v1.x * v1.x + v1.y * v1.y)
        let len2 = sqrt(v2.x * v2.x + v2.y * v2.y)

        if len1 < 0.0001 || len2 < 0.0001 {
            addLine(to: tangent1End, transform: transform)
            return
        }

        let n1 = CGPoint(x: v1.x / len1, y: v1.y / len1)
        let n2 = CGPoint(x: v2.x / len2, y: v2.y / len2)

        // Calculate angle between vectors
        let cross = n1.x * n2.y - n1.y * n2.x
        let dot = n1.x * n2.x + n1.y * n2.y

        if abs(cross) < 0.0001 {
            // Vectors are parallel, just draw line
            addLine(to: tangent1End, transform: transform)
            return
        }

        // Calculate arc parameters
        let angle = atan2(cross, dot)
        let tanHalfAngle = tan(abs(angle) / 2)
        let dist = radius / tanHalfAngle

        // Start point of arc
        let arcStart = CGPoint(
            x: tangent1End.x - dist * n1.x,
            y: tangent1End.y - dist * n1.y
        )

        // Draw line to arc start
        addLine(to: arcStart, transform: transform)

        // Calculate center and angles
        let perpDir: CGFloat = cross > 0 ? 1.0 : -1.0
        let perpX = -n1.y * perpDir
        let perpY = n1.x * perpDir
        let center = CGPoint(
            x: arcStart.x + perpX * radius,
            y: arcStart.y + perpY * radius
        )

        let startAngle = atan2(arcStart.y - center.y, arcStart.x - center.x)
        let endAngle = startAngle + angle

        addArc(center: center, radius: radius,
               startAngle: startAngle, endAngle: endAngle,
               clockwise: cross < 0, transform: transform)
    }

    /// Adds an arc of a circle to the path, specified with a radius and a difference in angle.
    public func addRelativeArc(center: CGPoint, radius: CGFloat, startAngle: CGFloat,
                               delta: CGFloat, transform: CGAffineTransform = .identity) {
        addArc(center: center, radius: radius, startAngle: startAngle,
               endAngle: startAngle + delta, clockwise: delta < 0, transform: transform)
    }

    /// Adds a cubic Bézier curve to the path, with the specified end point and control points.
    public func addCurve(to end: CGPoint, control1: CGPoint, control2: CGPoint,
                         transform: CGAffineTransform = .identity) {
        commands.append(.curveTo(
            control1: control1.applying(transform),
            control2: control2.applying(transform),
            end: end.applying(transform)
        ))
    }

    /// Adds a quadratic Bézier curve to the path, with the specified end point and control point.
    public func addQuadCurve(to end: CGPoint, control: CGPoint,
                             transform: CGAffineTransform = .identity) {
        commands.append(.quadCurveTo(
            control: control.applying(transform),
            end: end.applying(transform)
        ))
    }

    /// Appends another path object to the path.
    public func addPath(_ path: CGPath, transform: CGAffineTransform = .identity) {
        for command in path.commands {
            commands.append(command.applying(transform))
        }
    }

    /// Closes and completes a subpath in a mutable graphics path.
    public func closeSubpath() {
        commands.append(.closeSubpath)
    }
}


