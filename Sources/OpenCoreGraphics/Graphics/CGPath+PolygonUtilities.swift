//
//  CGPath+PolygonUtilities.swift
//  OpenCoreGraphics
//
//  Core polygon geometry used by boolean operations:
//  signed area, point-in-polygon, segment intersection, edge splitting.
//

import Foundation


// MARK: - Polygon Utilities

/// Signed area of a closed polygon (shoelace formula).
///
/// Positive for counter-clockwise, negative for clockwise (in CoreGraphics
/// coordinates where Y increases upward).
internal func _polygonSignedArea(_ points: [CGPoint]) -> CGFloat {
    guard points.count >= 3 else { return 0 }
    var area: CGFloat = 0
    for i in 0..<points.count {
        let a = points[i]
        let b = points[(i + 1) % points.count]
        area += (b.x - a.x) * (b.y + a.y)
    }
    return -area / 2   // shoelace with Y-up sign
}

/// Returns `true` iff the polygon is oriented counter-clockwise.
@inline(__always)
internal func _polygonIsCCW(_ points: [CGPoint]) -> Bool {
    return _polygonSignedArea(points) > 0
}

/// Bounding box of a polygon (returns `.null` when empty).
internal func _polygonBoundingBox(_ points: [CGPoint]) -> CGRect {
    guard let first = points.first else { return .null }
    var minX = first.x, minY = first.y
    var maxX = first.x, maxY = first.y
    for i in 1..<points.count {
        let p = points[i]
        if p.x < minX { minX = p.x }
        if p.y < minY { minY = p.y }
        if p.x > maxX { maxX = p.x }
        if p.y > maxY { maxY = p.y }
    }
    return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
}


// MARK: - Winding / Point-in-Polygon

/// Winding-number contribution of segment `p1`→`p2` for a test point `pt`.
///
/// +1 when the segment crosses the horizontal ray from `pt` going right, upward.
/// −1 when it crosses downward. 0 otherwise. Accumulated for an entire polygon,
/// this is the classical winding number (Sunday's algorithm).
@inline(__always)
internal func _windingContribution(_ pt: CGPoint, _ p1: CGPoint, _ p2: CGPoint) -> Int {
    if p1.y <= pt.y {
        if p2.y > pt.y {
            // Upward crossing
            let cross = (p2.x - p1.x) * (pt.y - p1.y) - (pt.x - p1.x) * (p2.y - p1.y)
            if cross > 0 { return 1 }
        }
    } else {
        if p2.y <= pt.y {
            // Downward crossing
            let cross = (p2.x - p1.x) * (pt.y - p1.y) - (pt.x - p1.x) * (p2.y - p1.y)
            if cross < 0 { return -1 }
        }
    }
    return 0
}

/// Returns the winding number of `pt` with respect to the flattened subpaths.
///
/// Closed subpaths contribute their signed winding; open subpaths are connected
/// conceptually (start→end) so that their contribution cancels at infinity —
/// which matches CoreGraphics' documented behavior of treating open subpaths
/// as if implicitly closed for fill-rule containment queries.
internal func _windingNumber(_ pt: CGPoint, in subpaths: [FlattenedSubpath]) -> Int {
    var w = 0
    for subpath in subpaths {
        let pts = subpath.points
        guard pts.count >= 2 else { continue }

        for i in 0..<(pts.count - 1) {
            w += _windingContribution(pt, pts[i], pts[i + 1])
        }
        // Implicit closing segment for the containment test
        if let last = pts.last, let first = pts.first, !_pointsEqual(last, first) {
            w += _windingContribution(pt, last, first)
        }
    }
    return w
}

/// Whether `pt` is interior to `subpaths` under the given fill rule.
@inline(__always)
internal func _isInside(_ pt: CGPoint, in subpaths: [FlattenedSubpath], rule: CGPathFillRule) -> Bool {
    switch rule {
    case .winding:
        return _windingNumber(pt, in: subpaths) != 0
    case .evenOdd:
        var crossings = 0
        for subpath in subpaths {
            let pts = subpath.points
            guard pts.count >= 2 else { continue }
            for i in 0..<(pts.count - 1) {
                crossings += _crossesRay(pt, pts[i], pts[i + 1])
            }
            if let last = pts.last, let first = pts.first, !_pointsEqual(last, first) {
                crossings += _crossesRay(pt, last, first)
            }
        }
        return (crossings & 1) == 1
    @unknown default:
        return _windingNumber(pt, in: subpaths) != 0
    }
}

/// Unsigned ray-crossing count contribution — 1 if segment crosses the horizontal
/// ray from `pt` going right, 0 otherwise. Used for even-odd fill rule.
@inline(__always)
private func _crossesRay(_ pt: CGPoint, _ a: CGPoint, _ b: CGPoint) -> Int {
    if (a.y > pt.y) != (b.y > pt.y) {
        let dy = b.y - a.y
        if abs(dy) < 1e-12 { return 0 }
        let xInt = a.x + (pt.y - a.y) * (b.x - a.x) / dy
        if pt.x < xInt { return 1 }
    }
    return 0
}


// MARK: - Segment Intersection

/// Intersection between two closed line segments.
internal enum _SegmentIntersection {
    /// No intersection.
    case none
    /// Single point (parameter `tA` on segment A in [0,1], `tB` on segment B in [0,1]).
    case point(CGPoint, tA: CGFloat, tB: CGFloat)
    /// Overlap along a sub-range — returns overlap endpoints and their parameters.
    case overlap(start: CGPoint, end: CGPoint, tA0: CGFloat, tA1: CGFloat, tB0: CGFloat, tB1: CGFloat)
}

/// Robust segment-segment intersection.
///
/// Handles both the general case (single crossing point) and the collinear-overlap
/// case. Endpoint touches are reported with parameter at 0 or 1.
internal func _segmentIntersection(
    _ a0: CGPoint, _ a1: CGPoint,
    _ b0: CGPoint, _ b1: CGPoint,
    epsilon: CGFloat = 1e-9
) -> _SegmentIntersection {
    let rx = a1.x - a0.x
    let ry = a1.y - a0.y
    let sx = b1.x - b0.x
    let sy = b1.y - b0.y
    let denom = rx * sy - ry * sx

    let dx = b0.x - a0.x
    let dy = b0.y - a0.y

    if abs(denom) < epsilon {
        // Parallel lines. Check for collinearity.
        let crossStart = dx * ry - dy * rx
        if abs(crossStart) > epsilon {
            return .none
        }
        // Collinear — project both endpoints of B onto A's parameter space.
        let lenA2 = rx * rx + ry * ry
        guard lenA2 > epsilon else { return .none }

        let t0Raw = (dx * rx + dy * ry) / lenA2
        let t1Raw = ((b1.x - a0.x) * rx + (b1.y - a0.y) * ry) / lenA2
        let tMin = min(t0Raw, t1Raw)
        let tMax = max(t0Raw, t1Raw)

        let clipMin = max(tMin, 0)
        let clipMax = min(tMax, 1)
        if clipMax < clipMin - epsilon {
            return .none
        }
        if clipMax - clipMin < epsilon {
            // Touch at a single endpoint
            let t = clipMin
            let p = CGPoint(x: a0.x + t * rx, y: a0.y + t * ry)
            // Compute tB for the touch
            let lenB2 = sx * sx + sy * sy
            let tB = lenB2 > epsilon
                ? ((p.x - b0.x) * sx + (p.y - b0.y) * sy) / lenB2
                : 0
            return .point(p, tA: t, tB: tB)
        }
        let pStart = CGPoint(x: a0.x + clipMin * rx, y: a0.y + clipMin * ry)
        let pEnd   = CGPoint(x: a0.x + clipMax * rx, y: a0.y + clipMax * ry)

        // Compute tB0/tB1 for the overlap endpoints.
        let lenB2 = sx * sx + sy * sy
        let tB0 = lenB2 > epsilon
            ? ((pStart.x - b0.x) * sx + (pStart.y - b0.y) * sy) / lenB2
            : 0
        let tB1 = lenB2 > epsilon
            ? ((pEnd.x - b0.x) * sx + (pEnd.y - b0.y) * sy) / lenB2
            : 1
        return .overlap(start: pStart, end: pEnd,
                        tA0: clipMin, tA1: clipMax,
                        tB0: tB0, tB1: tB1)
    }

    let tA = (dx * sy - dy * sx) / denom
    let tB = (dx * ry - dy * rx) / denom

    if tA < -epsilon || tA > 1 + epsilon { return .none }
    if tB < -epsilon || tB > 1 + epsilon { return .none }

    let tAClamped = max(0, min(1, tA))
    let tBClamped = max(0, min(1, tB))
    let p = CGPoint(x: a0.x + tAClamped * rx, y: a0.y + tAClamped * ry)
    return .point(p, tA: tAClamped, tB: tBClamped)
}


// MARK: - Edge Splitting

/// A single oriented edge with parametric position on its parent subpath.
///
/// `ownerTag == 0` for subject polygon A, `1` for clipping polygon B. This
/// identity is preserved through splitting so boolean operations can classify
/// each resulting edge by its original polygon.
internal struct _Edge {
    var start: CGPoint
    var end: CGPoint
    var ownerTag: Int
}

/// Splits polygon edges at every pairwise intersection, producing collinear
/// sub-edges that never cross each other in the interior.
///
/// Input `edges` should already carry correct `ownerTag` values. The returned
/// array is the concatenation of the split result for every input edge.
internal func _splitEdgesAtIntersections(_ edges: [_Edge]) -> [_Edge] {
    let n = edges.count
    // For each edge i, accumulate parameters in (0,1) where intersections landed.
    var splitParams: [[CGFloat]] = Array(repeating: [], count: n)

    let eps: CGFloat = 1e-7
    for i in 0..<n {
        for j in (i + 1)..<n {
            // Skip edges owned by the same polygon's own self-consistency —
            // we still want splits between the two inputs (A vs B) and also
            // between edges of the same polygon when they genuinely cross
            // (which signals a self-intersection we need to respect).
            let a = edges[i]
            let b = edges[j]

            // Fast bbox reject
            if max(a.start.x, a.end.x) < min(b.start.x, b.end.x) - eps { continue }
            if min(a.start.x, a.end.x) > max(b.start.x, b.end.x) + eps { continue }
            if max(a.start.y, a.end.y) < min(b.start.y, b.end.y) - eps { continue }
            if min(a.start.y, a.end.y) > max(b.start.y, b.end.y) + eps { continue }

            switch _segmentIntersection(a.start, a.end, b.start, b.end) {
            case .none:
                break
            case .point(_, let tA, let tB):
                if tA > eps && tA < 1 - eps { splitParams[i].append(tA) }
                if tB > eps && tB < 1 - eps { splitParams[j].append(tB) }
            case .overlap(_, _, let tA0, let tA1, let tB0, let tB1):
                for t in [tA0, tA1] where t > eps && t < 1 - eps {
                    splitParams[i].append(t)
                }
                for t in [tB0, tB1] where t > eps && t < 1 - eps {
                    splitParams[j].append(t)
                }
            }
        }
    }

    var result: [_Edge] = []
    result.reserveCapacity(n * 2)

    for i in 0..<n {
        let edge = edges[i]
        var params = splitParams[i]
        guard !params.isEmpty else {
            result.append(edge)
            continue
        }
        params.sort()
        // Deduplicate
        var unique: [CGFloat] = []
        unique.reserveCapacity(params.count)
        for p in params {
            if let last = unique.last, abs(p - last) < eps { continue }
            unique.append(p)
        }

        let dx = edge.end.x - edge.start.x
        let dy = edge.end.y - edge.start.y
        var prevPoint = edge.start
        for t in unique {
            let p = CGPoint(x: edge.start.x + t * dx, y: edge.start.y + t * dy)
            if !_pointsEqual(prevPoint, p) {
                result.append(_Edge(start: prevPoint, end: p, ownerTag: edge.ownerTag))
            }
            prevPoint = p
        }
        if !_pointsEqual(prevPoint, edge.end) {
            result.append(_Edge(start: prevPoint, end: edge.end, ownerTag: edge.ownerTag))
        }
    }

    return result
}


// MARK: - Subpath → Edges

extension Array where Element == FlattenedSubpath {
    /// Converts a list of flattened subpaths into directed edges, implicitly
    /// closing any open subpath. `ownerTag` is applied to every produced edge.
    internal func _toEdges(ownerTag: Int) -> [_Edge] {
        var result: [_Edge] = []
        for subpath in self {
            let pts = subpath.points
            guard pts.count >= 2 else { continue }
            for i in 0..<(pts.count - 1) {
                if !_pointsEqual(pts[i], pts[i + 1]) {
                    result.append(_Edge(start: pts[i], end: pts[i + 1], ownerTag: ownerTag))
                }
            }
            // Implicit closing edge — required for containment semantics.
            if let first = pts.first, let last = pts.last, !_pointsEqual(first, last) {
                result.append(_Edge(start: last, end: first, ownerTag: ownerTag))
            }
        }
        return result
    }
}
