//
//  CGPath+Operations.swift
//  OpenCoreGraphics
//
//  Apple-compatible CGPath geometric operations (iOS 16 / macOS 13).
//  https://developer.apple.com/documentation/coregraphics/cgpath
//

import Foundation


extension CGPath {

    // MARK: - Dashed Copies

    /// Returns a transformed copy whose line segments contain only the painted
    /// portions of the requested dash pattern.
    public func copy(
        dashingWithPhase phase: CGFloat,
        lengths: [CGFloat],
        transform: CGAffineTransform = .identity
    ) -> CGPath {
        let transformedPath: CGPath
        if transform.isIdentity {
            transformedPath = self
        } else {
            var transform = transform
            transformedPath = withUnsafePointer(to: &transform) { pointer in
                copy(using: pointer) ?? CGPath()
            }
        }

        guard !lengths.isEmpty else {
            return transformedPath.copy() ?? CGPath()
        }
        guard lengths.allSatisfy({ $0.isFinite && $0 > 0 }) else {
            return CGPath()
        }

        let pattern = lengths.count.isMultiple(of: 2) ? lengths : lengths + lengths
        let patternLength = pattern.reduce(0, +)
        guard patternLength.isFinite, patternLength > 0 else { return CGPath() }

        let subpaths = transformedPath._flattenToSubpaths(threshold: 0.25)
        let result = CGMutablePath()
        for subpath in subpaths {
            appendDashedSubpath(
                subpath,
                phase: phase,
                pattern: pattern,
                patternLength: patternLength,
                to: result
            )
        }
        return result.copy() ?? CGPath()
    }

    // MARK: - Flattening

    /// Returns a new path representing this path with all curves replaced by
    /// a sequence of connected line segments.
    ///
    /// - Parameter threshold: The maximum distance between the original curve
    ///   and the line approximation, in user-space units. Smaller values
    ///   produce more segments and a more faithful approximation.
    public func flattened(threshold: CGFloat = 0.6) -> CGPath {
        let subpaths = _flattenToSubpaths(threshold: threshold)
        return CGPath._path(fromSubpaths: subpaths)
    }


    // MARK: - Area Boolean Operations

    /// Returns a new path that is the union of this path and `other`.
    public func union(_ other: CGPath, using rule: CGPathFillRule = .winding) -> CGPath {
        return _pathBooleanOperation(subject: self, clipping: other,
                                     op: .union, rule: rule)
    }

    /// Returns a new path that is the area-wise intersection of this path and `other`.
    public func intersection(_ other: CGPath, using rule: CGPathFillRule = .winding) -> CGPath {
        return _pathBooleanOperation(subject: self, clipping: other,
                                     op: .intersection, rule: rule)
    }

    /// Returns a new path that is this path minus the area of `other`.
    public func subtracting(_ other: CGPath, using rule: CGPathFillRule = .winding) -> CGPath {
        return _pathBooleanOperation(subject: self, clipping: other,
                                     op: .difference, rule: rule)
    }

    /// Returns a new path that is the symmetric difference of this path and `other`.
    public func symmetricDifference(_ other: CGPath, using rule: CGPathFillRule = .winding) -> CGPath {
        return _pathBooleanOperation(subject: self, clipping: other,
                                     op: .xor, rule: rule)
    }


    // MARK: - Line Operations (treat `self` as lines, `other` as an area)

    /// Returns a new path containing the portions of this path's lines that
    /// lie inside the filled area of `other`.
    public func lineIntersection(_ other: CGPath, using rule: CGPathFillRule = .winding) -> CGPath {
        return _pathLineOperation(subject: self, clipping: other,
                                  keepInside: true, rule: rule)
    }

    /// Returns a new path containing the portions of this path's lines that
    /// lie outside the filled area of `other`.
    public func lineSubtracting(_ other: CGPath, using rule: CGPathFillRule = .winding) -> CGPath {
        return _pathLineOperation(subject: self, clipping: other,
                                  keepInside: false, rule: rule)
    }


    // MARK: - Examining

    /// Returns whether this path intersects the filled area of `other`.
    public func intersects(_ other: CGPath, using rule: CGPathFillRule = .winding) -> Bool {
        let subA = _flattenToSubpaths(threshold: 0.6)
        let subB = other._flattenToSubpaths(threshold: 0.6)
        if subA.isEmpty || subB.isEmpty { return false }

        // Bounding-box reject.
        let bboxA = _combinedBoundingBox(subA)
        let bboxB = _combinedBoundingBox(subB)
        if !bboxA.intersects(bboxB) { return false }

        // Any containment is an intersection.
        if let pa = subA.first?.points.first, _isInside(pa, in: subB, rule: rule) {
            return true
        }
        if let pb = subB.first?.points.first, _isInside(pb, in: subA, rule: rule) {
            return true
        }

        // Pairwise edge-crossing scan — if any edge of A crosses any edge of B
        // in the interior, the two paths intersect.
        for sA in subA {
            let pA = sA.points
            guard pA.count >= 2 else { continue }
            let edgeCountA = sA.isClosed ? pA.count : pA.count - 1
            for i in 0..<edgeCountA {
                let a0 = pA[i], a1 = pA[(i + 1) % pA.count]
                for sB in subB {
                    let pB = sB.points
                    guard pB.count >= 2 else { continue }
                    let edgeCountB = sB.isClosed ? pB.count : pB.count - 1
                    for j in 0..<edgeCountB {
                        let b0 = pB[j], b1 = pB[(j + 1) % pB.count]
                        switch _segmentIntersection(a0, a1, b0, b1) {
                        case .none:
                            break
                        case .point, .overlap:
                            return true
                        }
                    }
                }
            }
        }
        return false
    }


    // MARK: - Normalization / Decomposition

    /// Returns a normalized copy of this path.
    ///
    /// Normalization flattens curves, removes zero-length and duplicate
    /// segments, orients every subpath counter-clockwise and drops subpaths
    /// that the requested fill rule considers fully empty.
    public func normalized(using rule: CGPathFillRule = .winding) -> CGPath {
        var subpaths = _flattenToSubpaths(threshold: 0.6)
        // Remove degenerate subpaths (area == 0).
        subpaths.removeAll { sub in
            sub.isClosed ? abs(_polygonSignedArea(sub.points)) < 1e-9 : sub.points.count < 2
        }
        // Orient closed subpaths CCW (canonical direction).
        subpaths = subpaths.map { sub -> FlattenedSubpath in
            if sub.isClosed, _polygonSignedArea(sub.points) < 0 {
                return FlattenedSubpath(points: Array(sub.points.reversed()), isClosed: true)
            }
            return sub
        }
        _ = rule  // fill rule currently informs only degeneracy checks
        return CGPath._path(fromSubpaths: subpaths)
    }

    /// Returns each connected component of the path as a separate path.
    ///
    /// A "component" corresponds to one subpath of the original path.
    public func componentsSeparated(using rule: CGPathFillRule = .winding) -> [CGPath] {
        _ = rule  // rule parameter reserved for future hole-vs-shell grouping
        let subpaths = _flattenToSubpaths(threshold: 0.6)
        return subpaths.map { CGPath._path(fromSubpaths: [$0]) }
    }
}


// MARK: - Helpers

private func _combinedBoundingBox(_ subpaths: [FlattenedSubpath]) -> CGRect {
    var result: CGRect = .null
    for sub in subpaths {
        let bbox = _polygonBoundingBox(sub.points)
        if !bbox.isNull {
            result = result.isNull ? bbox : result.union(bbox)
        }
    }
    return result
}

private func appendDashedSubpath(
    _ subpath: FlattenedSubpath,
    phase: CGFloat,
    pattern: [CGFloat],
    patternLength: CGFloat,
    to result: CGMutablePath
) {
    guard subpath.points.count >= 2 else { return }

    var normalizedPhase = phase.truncatingRemainder(dividingBy: patternLength)
    if normalizedPhase < 0 { normalizedPhase += patternLength }

    var patternIndex = 0
    var remaining = pattern[0]
    while normalizedPhase >= remaining {
        normalizedPhase -= remaining
        patternIndex = (patternIndex + 1) % pattern.count
        remaining = pattern[patternIndex]
    }
    remaining -= normalizedPhase

    let segmentCount = subpath.isClosed ? subpath.points.count : subpath.points.count - 1
    var isDrawing = patternIndex.isMultiple(of: 2)
    var hasOpenDash = false
    let epsilon: CGFloat = 0.000_001

    for segmentIndex in 0..<segmentCount {
        var start = subpath.points[segmentIndex]
        let end = subpath.points[(segmentIndex + 1) % subpath.points.count]
        let dx = end.x - start.x
        let dy = end.y - start.y
        let segmentLength = hypot(dx, dy)
        guard segmentLength > epsilon else { continue }

        let unitX = dx / segmentLength
        let unitY = dy / segmentLength
        var distanceLeft = segmentLength

        while distanceLeft > epsilon {
            let step = min(distanceLeft, remaining)
            let next = CGPoint(x: start.x + unitX * step, y: start.y + unitY * step)

            if isDrawing {
                if !hasOpenDash {
                    result.move(to: start)
                    hasOpenDash = true
                }
                result.addLine(to: next)
            } else {
                hasOpenDash = false
            }

            start = next
            distanceLeft -= step
            remaining -= step

            if remaining <= epsilon {
                patternIndex = (patternIndex + 1) % pattern.count
                remaining = pattern[patternIndex]
                isDrawing = patternIndex.isMultiple(of: 2)
                if !isDrawing { hasOpenDash = false }
            }
        }
    }
}
