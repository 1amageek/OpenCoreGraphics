//
//  CGPath+BooleanEngine.swift
//  OpenCoreGraphics
//
//  Polygon boolean operations engine.
//
//  For each operation the algorithm is:
//    1. Flatten subject (A) and clipping (B) paths into polygon edge lists.
//    2. Split every edge at every pairwise intersection — produces a set of
//       "atomic" edges that never cross another edge in the interior.
//    3. For each atomic edge probe the two sides (left/right of direction)
//       and classify as insideA / insideB under the requested fill rule.
//    4. For each operation compute `insideResult` on each side. An edge is
//       retained iff the two sides disagree — i.e. the edge sits on the
//       boundary of the result. When the "inside" sits on the right,
//       reverse the edge so the canonical "inside is on the left" invariant
//       is preserved.
//    5. Chain the retained edges at shared vertices to form closed subpaths.
//
//  Complexity is O((n+m)²) in the number of flattened edges, dominated by
//  pairwise intersection testing. Fine for the few-hundred-vertex shapes
//  typical of vector-illustration workloads.
//

import Foundation


// MARK: - Operation

internal enum _BooleanOp {
    case union
    case intersection
    case difference       // A minus B
    case xor              // symmetric difference
}


// MARK: - Engine Entry Point

/// Performs an area boolean operation between two paths.
internal func _pathBooleanOperation(
    subject: CGPath,
    clipping: CGPath,
    op: _BooleanOp,
    rule: CGPathFillRule,
    threshold: CGFloat = 0.6
) -> CGPath {
    let subA = subject._flattenToSubpaths(threshold: threshold)
    let subB = clipping._flattenToSubpaths(threshold: threshold)

    // Trivial short-circuits
    if subA.isEmpty {
        switch op {
        case .union, .xor:
            return CGPath._path(fromSubpaths: subB)
        case .intersection, .difference:
            return CGPath()
        }
    }
    if subB.isEmpty {
        switch op {
        case .union, .xor, .difference:
            return CGPath._path(fromSubpaths: subA)
        case .intersection:
            return CGPath()
        }
    }

    let edgesA = subA._toEdges(ownerTag: 0)
    let edgesB = subB._toEdges(ownerTag: 1)
    let split = _splitEdgesAtIntersections(edgesA + edgesB)

    let selected = _selectBoundaryEdges(
        edges: split, subA: subA, subB: subB, op: op, rule: rule
    )

    let chains = _chainEdges(selected)
    let subpaths = chains.map { FlattenedSubpath(points: $0, isClosed: true) }
    return CGPath._path(fromSubpaths: subpaths)
}


// MARK: - Edge Selection (step 3-4)

/// Selects edges that lie on the result boundary and orients them so the
/// "inside of result" is on the left of the edge direction.
private func _selectBoundaryEdges(
    edges: [_Edge],
    subA: [FlattenedSubpath],
    subB: [FlattenedSubpath],
    op: _BooleanOp,
    rule: CGPathFillRule
) -> [_Edge] {
    var out: [_Edge] = []
    out.reserveCapacity(edges.count)

    for edge in edges {
        guard let probe = _probePoints(for: edge) else { continue }

        let leftInA  = _isInside(probe.left,  in: subA, rule: rule)
        let rightInA = _isInside(probe.right, in: subA, rule: rule)
        let leftInB  = _isInside(probe.left,  in: subB, rule: rule)
        let rightInB = _isInside(probe.right, in: subB, rule: rule)

        let leftInside  = _resultInside(a: leftInA,  b: leftInB,  op: op)
        let rightInside = _resultInside(a: rightInA, b: rightInB, op: op)

        if leftInside == rightInside { continue }   // not a boundary

        if leftInside {
            out.append(edge)
        } else {
            out.append(_Edge(start: edge.end, end: edge.start, ownerTag: edge.ownerTag))
        }
    }
    return out
}

/// Combines per-polygon containment into result containment under `op`.
@inline(__always)
private func _resultInside(a: Bool, b: Bool, op: _BooleanOp) -> Bool {
    switch op {
    case .union:        return a || b
    case .intersection: return a && b
    case .difference:   return a && !b
    case .xor:          return a != b
    }
}

/// Midpoint probes offset slightly to the left/right of the edge direction.
/// Returns nil for degenerate (zero-length) edges.
@inline(__always)
private func _probePoints(for edge: _Edge) -> (left: CGPoint, right: CGPoint)? {
    let dx = edge.end.x - edge.start.x
    let dy = edge.end.y - edge.start.y
    let len = sqrt(dx * dx + dy * dy)
    guard len > 1e-9 else { return nil }

    // Probe at 1/10,000 of edge length, but no larger than a safety cap so
    // the probe cannot jump over nearby edges. Minimum guarantees any inside-
    // outside flip by the fill-rule test.
    let eps: CGFloat = max(min(len * 1e-4, 1e-3), 1e-7)

    let mx = (edge.start.x + edge.end.x) / 2
    let my = (edge.start.y + edge.end.y) / 2
    let nx = -dy / len
    let ny = dx / len

    return (
        left:  CGPoint(x: mx + eps * nx, y: my + eps * ny),
        right: CGPoint(x: mx - eps * nx, y: my - eps * ny)
    )
}


// MARK: - Edge Chaining (step 5)

/// Rounds coordinates to a quantization grid so vertices from different edges
/// that should coincide do so exactly in the adjacency map.
private struct _VertexKey: Hashable {
    let ix: Int64
    let iy: Int64

    init(_ p: CGPoint, scale: CGFloat = 1e7) {
        self.ix = Int64((p.x * scale).rounded())
        self.iy = Int64((p.y * scale).rounded())
    }
}

/// Chains directed edges at shared vertices into closed polygons.
///
/// At a junction where multiple outgoing edges share a start vertex, the
/// smallest clockwise turn (closest to continuing straight, then turning
/// right) is picked — this tends to traverse the outer boundary of the
/// current face and avoid crossing over.
private func _chainEdges(_ edges: [_Edge]) -> [[CGPoint]] {
    guard !edges.isEmpty else { return [] }

    // Adjacency: startKey -> indices into edges[]
    var adjacency: [_VertexKey: [Int]] = [:]
    for (i, e) in edges.enumerated() {
        adjacency[_VertexKey(e.start), default: []].append(i)
    }

    var visited = Array(repeating: false, count: edges.count)
    var chains: [[CGPoint]] = []

    for startIdx in edges.indices {
        if visited[startIdx] { continue }

        var chain: [CGPoint] = []
        var currentIdx = startIdx
        var safety = edges.count * 4

        while !visited[currentIdx] && safety > 0 {
            visited[currentIdx] = true
            safety -= 1

            let edge = edges[currentIdx]
            chain.append(edge.start)

            // Pick next edge from edge.end
            let nextKey = _VertexKey(edge.end)
            guard var candidates = adjacency[nextKey] else { break }
            candidates.removeAll { visited[$0] }
            if candidates.isEmpty { break }

            if candidates.count == 1 {
                currentIdx = candidates[0]
                continue
            }

            // Choose candidate that makes the smallest CCW turn relative to
            // the current edge direction — keeps walking on the same face.
            let inDx = edge.end.x - edge.start.x
            let inDy = edge.end.y - edge.start.y

            var bestIdx = candidates[0]
            var bestAngle: CGFloat = .greatestFiniteMagnitude
            for c in candidates {
                let ne = edges[c]
                let outDx = ne.end.x - ne.start.x
                let outDy = ne.end.y - ne.start.y
                let angle = _turnAngle(inDx, inDy, outDx, outDy)
                if angle < bestAngle {
                    bestAngle = angle
                    bestIdx = c
                }
            }
            currentIdx = bestIdx
        }

        if chain.count >= 3 {
            chains.append(chain)
        }
    }
    return chains
}

/// Returns the CCW turn angle from `in` direction to `out` direction, in
/// range [0, 2π). 0 = continue straight, π/2 = slight left, π = U-turn,
/// 3π/2 = sharp right. Smaller is preferred when tracing a CCW-oriented
/// boundary so that we continue along the same face.
@inline(__always)
private func _turnAngle(_ inDx: CGFloat, _ inDy: CGFloat, _ outDx: CGFloat, _ outDy: CGFloat) -> CGFloat {
    let inA = atan2(inDy, inDx)
    let outA = atan2(outDy, outDx)
    var diff = outA - inA
    while diff < 0 { diff += 2 * .pi }
    while diff >= 2 * .pi { diff -= 2 * .pi }
    return diff
}


// MARK: - Line vs Area

/// Clips a subject's stroke lines against the area of clipping.
/// - Parameter keepInside: when true, keeps line portions inside the clipping
///   area (lineIntersection). When false, keeps portions outside (lineSubtracting).
internal func _pathLineOperation(
    subject: CGPath,
    clipping: CGPath,
    keepInside: Bool,
    rule: CGPathFillRule,
    threshold: CGFloat = 0.6
) -> CGPath {
    let subA = subject._flattenToSubpaths(threshold: threshold)
    let subB = clipping._flattenToSubpaths(threshold: threshold)

    if subA.isEmpty { return CGPath() }
    if subB.isEmpty { return keepInside ? CGPath() : CGPath._path(fromSubpaths: subA) }

    // Build edges for A — note lines preserve open/closed status, so we do
    // NOT implicitly close open subpaths here (unlike area operations).
    let edgesA = _subpathsToOpenEdges(subA, ownerTag: 0)
    let edgesB = subB._toEdges(ownerTag: 1)

    let split = _splitEdgesAtIntersections(edgesA + edgesB)

    var kept: [_Edge] = []
    kept.reserveCapacity(split.count)

    for edge in split where edge.ownerTag == 0 {
        guard let probe = _probePoints(for: edge) else { continue }
        let mid = CGPoint(
            x: (probe.left.x + probe.right.x) / 2,
            y: (probe.left.y + probe.right.y) / 2
        )
        let inB = _isInside(mid, in: subB, rule: rule)
        if inB == keepInside {
            kept.append(edge)
        }
    }

    // Rebuild a path with open subpaths, chaining contiguous kept edges.
    return _assembleOpenChains(kept)
}

/// Same as `_toEdges(ownerTag:)` but does NOT insert an implicit closing edge
/// for open subpaths. Used for line-vs-area operations.
private func _subpathsToOpenEdges(_ subpaths: [FlattenedSubpath], ownerTag: Int) -> [_Edge] {
    var result: [_Edge] = []
    for subpath in subpaths {
        let pts = subpath.points
        guard pts.count >= 2 else { continue }
        for i in 0..<(pts.count - 1) {
            if !_pointsEqual(pts[i], pts[i + 1]) {
                result.append(_Edge(start: pts[i], end: pts[i + 1], ownerTag: ownerTag))
            }
        }
        if subpath.isClosed, let first = pts.first, let last = pts.last, !_pointsEqual(first, last) {
            result.append(_Edge(start: last, end: first, ownerTag: ownerTag))
        }
    }
    return result
}

/// Stitches compatible edges (sharing a vertex) into polylines. Open-path form.
private func _assembleOpenChains(_ edges: [_Edge]) -> CGPath {
    let path = CGMutablePath()
    guard !edges.isEmpty else { return path }

    var adjacency: [_VertexKey: [Int]] = [:]
    for (i, e) in edges.enumerated() {
        adjacency[_VertexKey(e.start), default: []].append(i)
    }
    var visited = Array(repeating: false, count: edges.count)

    for startIdx in edges.indices {
        if visited[startIdx] { continue }
        visited[startIdx] = true
        let first = edges[startIdx]

        var chain: [CGPoint] = [first.start, first.end]
        var current = first
        while true {
            let key = _VertexKey(current.end)
            guard let cands = adjacency[key] else { break }
            let available = cands.filter { !visited[$0] }
            guard let next = available.first else { break }
            visited[next] = true
            current = edges[next]
            chain.append(current.end)
        }

        guard chain.count >= 2, let first = chain.first else { continue }
        path.move(to: first)
        for i in 1..<chain.count {
            path.addLine(to: chain[i])
        }
    }
    return path
}


// MARK: - Self-Intersection Resolution

/// Rewrites `path` so that its interior under `rule` is represented by simple,
/// non-self-intersecting closed subpaths whose winding interpretation matches
/// the requested fill rule.
///
/// This is the workhorse used by normalization and by the tessellator to turn
/// either fill rule into an equivalent set of simple rings. Ear-clipping
/// triangulation cannot evaluate winding numbers on overlapping contours, so
/// the boundary must be resolved before triangulation.
///
/// Algorithm: flatten to edges, split at every pairwise intersection, then
/// retain each atomic edge whose midpoint-left and midpoint-right probes
/// disagree about being inside the polygon under `rule`. Orient the retained
/// edges so "inside" is always on the left, and chain them into closed rings.
internal func _resolveSelfIntersections(
    path: CGPath,
    rule: CGPathFillRule,
    threshold: CGFloat = 0.6
) -> CGPath {
    let subpaths = path._flattenToSubpaths(threshold: threshold)
    if subpaths.isEmpty { return CGPath() }

    let edges = subpaths._toEdges(ownerTag: 0)
    let split = _splitEdgesAtIntersections(edges)

    var selected: [_Edge] = []
    selected.reserveCapacity(split.count)

    for edge in split {
        guard let probe = _probePoints(for: edge) else { continue }
        let leftInside = _isInside(probe.left, in: subpaths, rule: rule)
        let rightInside = _isInside(probe.right, in: subpaths, rule: rule)
        if leftInside == rightInside { continue }   // not on the boundary
        if leftInside {
            selected.append(edge)
        } else {
            selected.append(_Edge(start: edge.end, end: edge.start, ownerTag: edge.ownerTag))
        }
    }

    let chains = _chainEdges(selected)
    let newSubpaths = chains.map { FlattenedSubpath(points: $0, isClosed: true) }
    return CGPath._path(fromSubpaths: newSubpaths)
}
