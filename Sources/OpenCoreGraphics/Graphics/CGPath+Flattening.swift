//
//  CGPath+Flattening.swift
//  OpenCoreGraphics
//
//  Bezier curve flattening shared between public `flattened(threshold:)`
//  and the internal polygon boolean engine.
//

import Foundation


// MARK: - Internal Flattened Subpath

/// A flattened subpath (curves converted to line segments).
///
/// `points` always contains at least one vertex. For a closed subpath the first
/// point is NOT duplicated at the end — closure is carried on `isClosed`.
internal struct FlattenedSubpath: Sendable {
    var points: [CGPoint]
    var isClosed: Bool
}


// MARK: - Flattening

extension CGPath {

    /// Flattens every subpath to polygonal chains using recursive De Casteljau subdivision.
    ///
    /// Subpaths of length 0/1 are discarded. Consecutive duplicate points are collapsed.
    internal func _flattenToSubpaths(threshold: CGFloat) -> [FlattenedSubpath] {
        let t = max(threshold, 1e-4)
        var subpaths: [FlattenedSubpath] = []
        var current: [CGPoint] = []
        var currentPoint = CGPoint.zero
        var subpathStart = CGPoint.zero
        var subpathStartSet = false

        @inline(__always)
        func appendUnique(_ point: CGPoint) {
            if let last = current.last, _pointsEqual(last, point) { return }
            current.append(point)
        }

        func finishSubpath(closed: Bool) {
            if current.count >= 2 {
                subpaths.append(FlattenedSubpath(points: current, isClosed: closed))
            }
            current = []
            subpathStartSet = false
        }

        for command in commands {
            switch command {
            case .moveTo(let p):
                finishSubpath(closed: false)
                current.append(p)
                currentPoint = p
                subpathStart = p
                subpathStartSet = true

            case .lineTo(let p):
                if !subpathStartSet {
                    current.append(currentPoint)
                    subpathStart = currentPoint
                    subpathStartSet = true
                }
                appendUnique(p)
                currentPoint = p

            case .quadCurveTo(let control, let end):
                if !subpathStartSet {
                    current.append(currentPoint)
                    subpathStart = currentPoint
                    subpathStartSet = true
                }
                _subdivideQuad(start: currentPoint, control: control, end: end,
                               threshold: t, into: &current)
                currentPoint = end

            case .curveTo(let c1, let c2, let end):
                if !subpathStartSet {
                    current.append(currentPoint)
                    subpathStart = currentPoint
                    subpathStartSet = true
                }
                _subdivideCubic(start: currentPoint, control1: c1, control2: c2,
                                end: end, threshold: t, into: &current)
                currentPoint = end

            case .closeSubpath:
                if subpathStartSet {
                    // Drop the trailing point if it equals the start — we carry closure on the flag.
                    if let last = current.last, _pointsEqual(last, subpathStart), current.count > 1 {
                        // keep as-is
                    }
                    finishSubpath(closed: true)
                    currentPoint = subpathStart
                }
            }
        }

        finishSubpath(closed: false)
        return subpaths
    }

    /// Rebuilds a `CGPath` from flattened subpaths.
    internal static func _path(fromSubpaths subpaths: [FlattenedSubpath]) -> CGPath {
        let path = CGMutablePath()
        for subpath in subpaths {
            guard let first = subpath.points.first else { continue }
            path.move(to: first)
            for i in 1..<subpath.points.count {
                path.addLine(to: subpath.points[i])
            }
            if subpath.isClosed {
                path.closeSubpath()
            }
        }
        return path
    }
}


// MARK: - Bezier Subdivision

@inline(__always)
internal func _pointsEqual(_ a: CGPoint, _ b: CGPoint, epsilon: CGFloat = 1e-9) -> Bool {
    return abs(a.x - b.x) < epsilon && abs(a.y - b.y) < epsilon
}

@inline(__always)
private func _midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
    return CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
}

/// Perpendicular distance from `p` to the line through `a`–`b`.
/// Returns distance from `p` to `a` if `a == b`.
@inline(__always)
private func _pointLineDistance(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
    let dx = b.x - a.x
    let dy = b.y - a.y
    let len2 = dx * dx + dy * dy
    if len2 < 1e-12 {
        let ex = p.x - a.x
        let ey = p.y - a.y
        return sqrt(ex * ex + ey * ey)
    }
    let num = abs(dy * p.x - dx * p.y + b.x * a.y - b.y * a.x)
    return num / sqrt(len2)
}

/// Recursively subdivides a quadratic Bézier curve into line segments and appends them to `out`.
private func _subdivideQuad(
    start: CGPoint,
    control: CGPoint,
    end: CGPoint,
    threshold: CGFloat,
    depth: Int = 0,
    into out: inout [CGPoint]
) {
    let flatness = _pointLineDistance(control, start, end)
    if flatness <= threshold || depth > 20 {
        if let last = out.last, _pointsEqual(last, end) { return }
        out.append(end)
        return
    }
    let m01 = _midpoint(start, control)
    let m12 = _midpoint(control, end)
    let m012 = _midpoint(m01, m12)
    _subdivideQuad(start: start, control: m01, end: m012,
                   threshold: threshold, depth: depth + 1, into: &out)
    _subdivideQuad(start: m012, control: m12, end: end,
                   threshold: threshold, depth: depth + 1, into: &out)
}

/// Recursively subdivides a cubic Bézier curve into line segments and appends them to `out`.
private func _subdivideCubic(
    start: CGPoint,
    control1: CGPoint,
    control2: CGPoint,
    end: CGPoint,
    threshold: CGFloat,
    depth: Int = 0,
    into out: inout [CGPoint]
) {
    let d1 = _pointLineDistance(control1, start, end)
    let d2 = _pointLineDistance(control2, start, end)
    if max(d1, d2) <= threshold || depth > 20 {
        if let last = out.last, _pointsEqual(last, end) { return }
        out.append(end)
        return
    }
    let p01 = _midpoint(start, control1)
    let p12 = _midpoint(control1, control2)
    let p23 = _midpoint(control2, end)
    let p012 = _midpoint(p01, p12)
    let p123 = _midpoint(p12, p23)
    let p0123 = _midpoint(p012, p123)
    _subdivideCubic(start: start, control1: p01, control2: p012, end: p0123,
                    threshold: threshold, depth: depth + 1, into: &out)
    _subdivideCubic(start: p0123, control1: p123, control2: p23, end: end,
                    threshold: threshold, depth: depth + 1, into: &out)
}
