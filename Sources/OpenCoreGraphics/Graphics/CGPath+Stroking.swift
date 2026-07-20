//
//  CGPath+Stroking.swift
//  OpenCoreGraphics
//

import Foundation


/// Shared stroke geometry consumed by public path conversion and both renderers.
internal struct CGStrokeGeometry: Sendable {
    private struct Segment: Sendable {
        let start: CGPoint
        let end: CGPoint
        let direction: CGPoint
        let normal: CGPoint
        var leftStart: CGPoint
        var rightStart: CGPoint
        var leftEnd: CGPoint
        var rightEnd: CGPoint
    }

    let contours: [[CGPoint]]
    let outlineContours: [[CGPoint]]

    var path: CGPath {
        let result = CGMutablePath()
        for contour in outlineContours {
            guard let first = contour.first else { continue }
            result.move(to: first)
            for point in contour.dropFirst() {
                result.addLine(to: point)
            }
            result.closeSubpath()
        }
        return result
    }

    var triangles: [CGPoint] {
        var result: [CGPoint] = []
        for contour in contours where contour.count >= 3 {
            for index in 1..<(contour.count - 1) {
                result.append(contour[0])
                result.append(contour[index])
                result.append(contour[index + 1])
            }
        }
        return result
    }

    static func make(
        path: CGPath,
        lineWidth: CGFloat,
        lineCap: CGLineCap,
        lineJoin: CGLineJoin,
        miterLimit: CGFloat,
        transform: CGAffineTransform = .identity
    ) -> CGStrokeGeometry {
        guard lineWidth.isFinite, lineWidth > 0 else {
            return CGStrokeGeometry(contours: [], outlineContours: [])
        }

        let tolerance = flatteningTolerance(for: path, lineWidth: lineWidth)
        let subpaths = path._flattenToSubpaths(threshold: tolerance)
        var contours: [[CGPoint]] = []
        var outlineContours: [[CGPoint]] = []
        for subpath in subpaths {
            outlineContours.append(contentsOf: strokeOutline(
                subpath: subpath,
                halfWidth: lineWidth / 2,
                lineCap: lineCap,
                lineJoin: lineJoin,
                miterLimit: miterLimit,
                tolerance: tolerance
            ))
            contours.append(contentsOf: stroke(
                subpath: subpath,
                halfWidth: lineWidth / 2,
                lineCap: lineCap,
                lineJoin: lineJoin,
                miterLimit: miterLimit,
                tolerance: tolerance
            ))
        }
        for center in degenerateSubpathCenters(in: path) {
            switch lineCap {
            case .butt:
                break
            case .round:
                appendCircle(
                    center: center,
                    radius: lineWidth / 2,
                    tolerance: tolerance,
                    to: &contours
                )
                appendCircle(
                    center: center,
                    radius: lineWidth / 2,
                    tolerance: tolerance,
                    to: &outlineContours
                )
            case .square:
                let radius = lineWidth / 2 * sqrt(2)
                appendContour([
                    CGPoint(x: center.x - radius, y: center.y),
                    CGPoint(x: center.x, y: center.y - radius),
                    CGPoint(x: center.x + radius, y: center.y),
                    CGPoint(x: center.x, y: center.y + radius),
                ], to: &contours)
                appendContour([
                    CGPoint(x: center.x - radius, y: center.y),
                    CGPoint(x: center.x, y: center.y - radius),
                    CGPoint(x: center.x + radius, y: center.y),
                    CGPoint(x: center.x, y: center.y + radius),
                ], to: &outlineContours)
            }
        }
        if !transform.isIdentity {
            contours = contours.map { contour in
                contour.map { $0.applying(transform) }
            }
            outlineContours = outlineContours.map { contour in
                contour.map { $0.applying(transform) }
            }
        }
        return CGStrokeGeometry(contours: contours, outlineContours: outlineContours)
    }

    private static func strokeOutline(
        subpath: FlattenedSubpath,
        halfWidth: CGFloat,
        lineCap: CGLineCap,
        lineJoin: CGLineJoin,
        miterLimit: CGFloat,
        tolerance: CGFloat
    ) -> [[CGPoint]] {
        var points = deduplicated(subpath.points)
        if subpath.isClosed, points.count > 1, pointsEqual(points[0], points[points.count - 1]) {
            points.removeLast()
        }
        guard points.count >= 2 else { return [] }

        let segmentCount = subpath.isClosed ? points.count : points.count - 1
        var segments: [Segment] = []
        segments.reserveCapacity(segmentCount)
        for index in 0..<segmentCount {
            let start = points[index]
            let end = points[(index + 1) % points.count]
            let delta = subtracting(end, start)
            let length = hypot(delta.x, delta.y)
            guard length > geometryEpsilon(for: start, end) else { continue }
            let direction = scaled(delta, by: 1 / length)
            let normal = CGPoint(x: -direction.y, y: direction.x)
            let offset = scaled(normal, by: halfWidth)
            segments.append(Segment(
                start: start,
                end: end,
                direction: direction,
                normal: normal,
                leftStart: adding(start, offset),
                rightStart: subtracting(start, offset),
                leftEnd: adding(end, offset),
                rightEnd: subtracting(end, offset)
            ))
        }
        guard !segments.isEmpty else { return [] }

        if !subpath.isClosed, lineCap == .square {
            let firstExtension = scaled(segments[0].direction, by: -halfWidth)
            segments[0].leftStart = adding(segments[0].leftStart, firstExtension)
            segments[0].rightStart = adding(segments[0].rightStart, firstExtension)
            let lastIndex = segments.count - 1
            let lastExtension = scaled(segments[lastIndex].direction, by: halfWidth)
            segments[lastIndex].leftEnd = adding(segments[lastIndex].leftEnd, lastExtension)
            segments[lastIndex].rightEnd = adding(segments[lastIndex].rightEnd, lastExtension)
        }

        if subpath.isClosed {
            let left = closedBoundary(
                segments: segments,
                side: 1,
                halfWidth: halfWidth,
                lineJoin: lineJoin,
                miterLimit: miterLimit,
                tolerance: tolerance
            )
            let right = closedBoundary(
                segments: segments,
                side: -1,
                halfWidth: halfWidth,
                lineJoin: lineJoin,
                miterLimit: miterLimit,
                tolerance: tolerance
            )
            guard left.count >= 3, right.count >= 3 else { return [] }
            let leftIsOuter = abs(_polygonSignedArea(left)) >= abs(_polygonSignedArea(right))
            return [
                oriented(leftIsOuter ? left : right, clockwise: false),
                oriented(leftIsOuter ? right : left, clockwise: true),
            ]
        }

        var left = [segments[0].leftStart]
        var right = [segments[0].rightStart]
        if segments.count > 1 {
            for index in 0..<(segments.count - 1) {
                let vertex = segments[index].end
                left.append(contentsOf: boundaryJoinPoints(
                    vertex: vertex,
                    previous: segments[index],
                    next: segments[index + 1],
                    side: 1,
                    halfWidth: halfWidth,
                    lineJoin: lineJoin,
                    miterLimit: miterLimit,
                    tolerance: tolerance
                ))
                right.append(contentsOf: boundaryJoinPoints(
                    vertex: vertex,
                    previous: segments[index],
                    next: segments[index + 1],
                    side: -1,
                    halfWidth: halfWidth,
                    lineJoin: lineJoin,
                    miterLimit: miterLimit,
                    tolerance: tolerance
                ))
            }
        }
        left.append(segments[segments.count - 1].leftEnd)
        right.append(segments[segments.count - 1].rightEnd)

        var outline = left
        if lineCap == .round {
            outline.append(contentsOf: arcPoints(
                center: segments[segments.count - 1].end,
                startAngle: atan2(
                    segments[segments.count - 1].leftEnd.y - segments[segments.count - 1].end.y,
                    segments[segments.count - 1].leftEnd.x - segments[segments.count - 1].end.x
                ),
                delta: -.pi,
                radius: halfWidth,
                tolerance: tolerance
            ).dropFirst())
        } else {
            outline.append(segments[segments.count - 1].rightEnd)
        }
        outline.append(contentsOf: right.reversed().dropFirst())
        if lineCap == .round {
            outline.append(contentsOf: arcPoints(
                center: segments[0].start,
                startAngle: atan2(
                    segments[0].rightStart.y - segments[0].start.y,
                    segments[0].rightStart.x - segments[0].start.x
                ),
                delta: -.pi,
                radius: halfWidth,
                tolerance: tolerance
            ).dropFirst())
        }
        return [oriented(outline, clockwise: false)]
    }

    private static func closedBoundary(
        segments: [Segment],
        side: CGFloat,
        halfWidth: CGFloat,
        lineJoin: CGLineJoin,
        miterLimit: CGFloat,
        tolerance: CGFloat
    ) -> [CGPoint] {
        var boundary: [CGPoint] = []
        for index in segments.indices {
            let previous = segments[(index - 1 + segments.count) % segments.count]
            let next = segments[index]
            boundary.append(contentsOf: boundaryJoinPoints(
                vertex: next.start,
                previous: previous,
                next: next,
                side: side,
                halfWidth: halfWidth,
                lineJoin: lineJoin,
                miterLimit: miterLimit,
                tolerance: tolerance
            ))
        }
        return deduplicated(boundary)
    }

    private static func boundaryJoinPoints(
        vertex: CGPoint,
        previous: Segment,
        next: Segment,
        side: CGFloat,
        halfWidth: CGFloat,
        lineJoin: CGLineJoin,
        miterLimit: CGFloat,
        tolerance: CGFloat
    ) -> [CGPoint] {
        let previousPoint = side > 0 ? previous.leftEnd : previous.rightEnd
        let nextPoint = side > 0 ? next.leftStart : next.rightStart
        let turn = crossProduct(previous.direction, next.direction)
        if abs(turn) <= 1e-10 {
            return [previousPoint, nextPoint]
        }

        let intersection = offsetIntersection(
            vertex: vertex,
            previous: previous,
            next: next,
            side: side,
            halfWidth: halfWidth
        )
        let isOuter = turn * side < 0
        guard isOuter else { return [previousPoint, nextPoint] }

        switch lineJoin {
        case .miter:
            if let intersection,
               distance(vertex, intersection) / halfWidth <= max(0, miterLimit) {
                return [previousPoint, intersection, nextPoint]
            }
            return [previousPoint, nextPoint]
        case .bevel:
            return [previousPoint, nextPoint]
        case .round:
            let startAngle = atan2(previousPoint.y - vertex.y, previousPoint.x - vertex.x)
            let endAngle = atan2(nextPoint.y - vertex.y, nextPoint.x - vertex.x)
            var delta = endAngle - startAngle
            if turn > 0 {
                while delta <= 0 { delta += 2 * .pi }
            } else {
                while delta >= 0 { delta -= 2 * .pi }
            }
            return arcPoints(
                center: vertex,
                startAngle: startAngle,
                delta: delta,
                radius: halfWidth,
                tolerance: tolerance
            )
        }
    }

    private static func oriented(_ rawPoints: [CGPoint], clockwise: Bool) -> [CGPoint] {
        var points = deduplicated(rawPoints)
        if points.count > 1, pointsEqual(points[0], points[points.count - 1]) {
            points.removeLast()
        }
        let isClockwise = _polygonSignedArea(points) < 0
        if isClockwise != clockwise {
            points.reverse()
        }
        return points
    }

    private static func stroke(
        subpath: FlattenedSubpath,
        halfWidth: CGFloat,
        lineCap: CGLineCap,
        lineJoin: CGLineJoin,
        miterLimit: CGFloat,
        tolerance: CGFloat
    ) -> [[CGPoint]] {
        var points = deduplicated(subpath.points)
        if subpath.isClosed, points.count > 1, pointsEqual(points[0], points[points.count - 1]) {
            points.removeLast()
        }
        guard points.count >= 2 else { return [] }

        let segmentCount = subpath.isClosed ? points.count : points.count - 1
        var segments: [Segment] = []
        segments.reserveCapacity(segmentCount)
        for index in 0..<segmentCount {
            let start = points[index]
            let end = points[(index + 1) % points.count]
            let delta = CGPoint(x: end.x - start.x, y: end.y - start.y)
            let length = hypot(delta.x, delta.y)
            guard length > geometryEpsilon(for: start, end) else { continue }
            let direction = CGPoint(x: delta.x / length, y: delta.y / length)
            let normal = CGPoint(x: -direction.y, y: direction.x)
            let offset = scaled(normal, by: halfWidth)
            segments.append(Segment(
                start: start,
                end: end,
                direction: direction,
                normal: normal,
                leftStart: adding(start, offset),
                rightStart: subtracting(start, offset),
                leftEnd: adding(end, offset),
                rightEnd: subtracting(end, offset)
            ))
        }
        guard !segments.isEmpty else { return [] }

        var patches: [[CGPoint]] = []
        let joinCount = subpath.isClosed ? segments.count : max(0, segments.count - 1)
        for joinIndex in 0..<joinCount {
            let previousIndex = joinIndex
            let nextIndex = (joinIndex + 1) % segments.count
            let vertex = segments[previousIndex].end
            appendJoin(
                vertex: vertex,
                previousIndex: previousIndex,
                nextIndex: nextIndex,
                segments: &segments,
                patches: &patches,
                halfWidth: halfWidth,
                lineJoin: lineJoin,
                miterLimit: miterLimit,
                tolerance: tolerance
            )
        }

        if !subpath.isClosed {
            appendCaps(
                segments: &segments,
                patches: &patches,
                halfWidth: halfWidth,
                lineCap: lineCap,
                tolerance: tolerance
            )
        }

        for segment in segments {
            appendContour([
                segment.leftStart,
                segment.rightStart,
                segment.rightEnd,
                segment.leftEnd,
            ], to: &patches)
        }
        return patches
    }

    private static func appendJoin(
        vertex: CGPoint,
        previousIndex: Int,
        nextIndex: Int,
        segments: inout [Segment],
        patches: inout [[CGPoint]],
        halfWidth: CGFloat,
        lineJoin: CGLineJoin,
        miterLimit: CGFloat,
        tolerance: CGFloat
    ) {
        let previous = segments[previousIndex]
        let next = segments[nextIndex]
        let turn = crossProduct(previous.direction, next.direction)
        let alignment = dotProduct(previous.direction, next.direction)
        let angularEpsilon: CGFloat = 1e-10

        if abs(turn) <= angularEpsilon {
            if alignment < 0, lineJoin == .round {
                appendCircle(
                    center: vertex,
                    radius: halfWidth,
                    tolerance: tolerance,
                    to: &patches
                )
            }
            return
        }

        let outerIsLeft = turn < 0
        let previousPoint = outerIsLeft ? previous.leftEnd : previous.rightEnd
        let nextPoint = outerIsLeft ? next.leftStart : next.rightStart
        let intersection = offsetIntersection(
            vertex: vertex,
            previous: previous,
            next: next,
            side: outerIsLeft ? 1 : -1,
            halfWidth: halfWidth
        )
        let innerIntersection = offsetIntersection(
            vertex: vertex,
            previous: previous,
            next: next,
            side: outerIsLeft ? -1 : 1,
            halfWidth: halfWidth
        )
        let joinAnchor = innerIntersection ?? vertex
        if outerIsLeft {
            segments[previousIndex].rightEnd = joinAnchor
            segments[nextIndex].rightStart = joinAnchor
        } else {
            segments[previousIndex].leftEnd = joinAnchor
            segments[nextIndex].leftStart = joinAnchor
        }

        switch lineJoin {
        case .miter:
            if let intersection,
               distance(vertex, intersection) / halfWidth <= max(0, miterLimit) {
                appendContour([joinAnchor, previousPoint, intersection, nextPoint], to: &patches)
            } else {
                appendContour([joinAnchor, previousPoint, nextPoint], to: &patches)
            }
        case .bevel:
            appendContour([joinAnchor, previousPoint, nextPoint], to: &patches)
        case .round:
            appendRoundSector(
                anchor: joinAnchor,
                center: vertex,
                start: previousPoint,
                end: nextPoint,
                turn: turn,
                radius: halfWidth,
                tolerance: tolerance,
                to: &patches
            )
        }
    }

    private static func appendCaps(
        segments: inout [Segment],
        patches: inout [[CGPoint]],
        halfWidth: CGFloat,
        lineCap: CGLineCap,
        tolerance: CGFloat
    ) {
        guard let first = segments.first, let last = segments.last else { return }
        switch lineCap {
        case .butt:
            break
        case .square:
            let startExtension = scaled(first.direction, by: -halfWidth)
            segments[0].leftStart = adding(first.leftStart, startExtension)
            segments[0].rightStart = adding(first.rightStart, startExtension)
            let lastIndex = segments.count - 1
            let endExtension = scaled(last.direction, by: halfWidth)
            segments[lastIndex].leftEnd = adding(last.leftEnd, endExtension)
            segments[lastIndex].rightEnd = adding(last.rightEnd, endExtension)
        case .round:
            appendSemicircle(
                center: first.start,
                start: first.leftStart,
                delta: .pi,
                radius: halfWidth,
                tolerance: tolerance,
                to: &patches
            )
            appendSemicircle(
                center: last.end,
                start: last.rightEnd,
                delta: .pi,
                radius: halfWidth,
                tolerance: tolerance,
                to: &patches
            )
        }
    }

    private static func appendRoundSector(
        anchor: CGPoint,
        center: CGPoint,
        start: CGPoint,
        end: CGPoint,
        turn: CGFloat,
        radius: CGFloat,
        tolerance: CGFloat,
        to contours: inout [[CGPoint]]
    ) {
        let startAngle = atan2(start.y - center.y, start.x - center.x)
        let endAngle = atan2(end.y - center.y, end.x - center.x)
        var delta = endAngle - startAngle
        if turn > 0 {
            while delta <= 0 { delta += 2 * .pi }
        } else {
            while delta >= 0 { delta -= 2 * .pi }
        }
        let arc = arcPoints(
            center: center,
            startAngle: startAngle,
            delta: delta,
            radius: radius,
            tolerance: tolerance
        )
        appendContour([anchor] + arc, to: &contours)
    }

    private static func appendSemicircle(
        center: CGPoint,
        start: CGPoint,
        delta: CGFloat,
        radius: CGFloat,
        tolerance: CGFloat,
        to contours: inout [[CGPoint]]
    ) {
        appendArcSector(
            center: center,
            startAngle: atan2(start.y - center.y, start.x - center.x),
            delta: delta,
            radius: radius,
            tolerance: tolerance,
            to: &contours
        )
    }

    private static func appendArcSector(
        center: CGPoint,
        startAngle: CGFloat,
        delta: CGFloat,
        radius: CGFloat,
        tolerance: CGFloat,
        to contours: inout [[CGPoint]]
    ) {
        let arc = arcPoints(
            center: center,
            startAngle: startAngle,
            delta: delta,
            radius: radius,
            tolerance: tolerance
        )
        appendContour([center] + arc, to: &contours)
    }

    private static func arcPoints(
        center: CGPoint,
        startAngle: CGFloat,
        delta: CGFloat,
        radius: CGFloat,
        tolerance: CGFloat
    ) -> [CGPoint] {
        guard radius > 0, abs(delta) > 0 else { return [] }
        let maximumStep = maximumArcStep(radius: radius, tolerance: tolerance)
        let direction: CGFloat = delta > 0 ? 1 : -1
        let span = abs(delta)
        let quarterTurn = CGFloat.pi / 2
        let minimumAngle = min(startAngle, startAngle + delta)
        let maximumAngle = max(startAngle, startAngle + delta)
        let firstQuarter = Int(floor(minimumAngle / quarterTurn)) - 1
        let lastQuarter = Int(ceil(maximumAngle / quarterTurn)) + 1
        var breakpoints: [CGFloat] = [0]
        for quarter in firstQuarter...lastQuarter {
            let cardinalAngle = CGFloat(quarter) * quarterTurn
            let progress = (cardinalAngle - startAngle) * direction
            if progress > 1e-12, progress < span - 1e-12 {
                breakpoints.append(progress)
            }
        }
        breakpoints.sort()
        breakpoints.append(span)

        var points: [CGPoint] = []
        for intervalIndex in 0..<(breakpoints.count - 1) {
            let intervalStart = breakpoints[intervalIndex]
            let intervalEnd = breakpoints[intervalIndex + 1]
            let segmentCount = max(1, Int(ceil((intervalEnd - intervalStart) / maximumStep)))
            let firstIndex = intervalIndex == 0 ? 0 : 1
            for index in firstIndex...segmentCount {
                let progress = intervalStart
                    + (intervalEnd - intervalStart) * CGFloat(index) / CGFloat(segmentCount)
                let angle = startAngle + direction * progress
                points.append(CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius
                ))
            }
        }
        return points
    }

    private static func appendCircle(
        center: CGPoint,
        radius: CGFloat,
        tolerance: CGFloat,
        to contours: inout [[CGPoint]]
    ) {
        let maximumStep = maximumArcStep(radius: radius, tolerance: tolerance)
        let requiredSegmentCount = max(8, Int(ceil(2 * CGFloat.pi / maximumStep)))
        let segmentCount = ((requiredSegmentCount + 3) / 4) * 4
        var contour: [CGPoint] = []
        contour.reserveCapacity(segmentCount)
        for index in 0..<segmentCount {
            let angle = 2 * CGFloat.pi * CGFloat(index) / CGFloat(segmentCount)
            contour.append(CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            ))
        }
        appendContour(contour, to: &contours)
    }

    private static func degenerateSubpathCenters(in path: CGPath) -> [CGPoint] {
        var centers: [CGPoint] = []
        var start: CGPoint?
        var hasDrawingElement = false
        var hasNonzeroGeometry = false

        func finishSubpath() {
            if let start, hasDrawingElement, !hasNonzeroGeometry {
                centers.append(start)
            }
            start = nil
            hasDrawingElement = false
            hasNonzeroGeometry = false
        }

        for command in path.commands {
            switch command {
            case .moveTo(let point):
                finishSubpath()
                start = point
            case .lineTo(let point):
                guard let start else { continue }
                hasDrawingElement = true
                hasNonzeroGeometry = hasNonzeroGeometry || !pointsEqual(start, point)
            case .quadCurveTo(let control, let end):
                guard let start else { continue }
                hasDrawingElement = true
                hasNonzeroGeometry = hasNonzeroGeometry
                    || !pointsEqual(start, control)
                    || !pointsEqual(start, end)
            case .curveTo(let control1, let control2, let end):
                guard let start else { continue }
                hasDrawingElement = true
                hasNonzeroGeometry = hasNonzeroGeometry
                    || !pointsEqual(start, control1)
                    || !pointsEqual(start, control2)
                    || !pointsEqual(start, end)
            case .closeSubpath:
                guard start != nil else { continue }
                hasDrawingElement = true
                finishSubpath()
            }
        }
        finishSubpath()
        return centers
    }

    private static func appendContour(_ rawContour: [CGPoint], to contours: inout [[CGPoint]]) {
        var contour = deduplicated(rawContour)
        guard contour.count >= 3 else { return }
        if _polygonSignedArea(contour) < 0 {
            contour.reverse()
        }
        guard abs(_polygonSignedArea(contour)) > geometryEpsilon(for: contour[0], contour[1]) else {
            return
        }
        contours.append(contour)
    }

    private static func offsetIntersection(
        vertex: CGPoint,
        previous: Segment,
        next: Segment,
        side: CGFloat,
        halfWidth: CGFloat
    ) -> CGPoint? {
        let first = adding(vertex, scaled(previous.normal, by: side * halfWidth))
        let second = adding(vertex, scaled(next.normal, by: side * halfWidth))
        let denominator = crossProduct(previous.direction, next.direction)
        guard abs(denominator) > 1e-12 else { return nil }
        let between = subtracting(second, first)
        let parameter = crossProduct(between, next.direction) / denominator
        let point = adding(first, scaled(previous.direction, by: parameter))
        guard point.x.isFinite, point.y.isFinite else { return nil }
        return point
    }

    private static func flatteningTolerance(for path: CGPath, lineWidth: CGFloat) -> CGFloat {
        let bounds = path.boundingBox
        let coordinateScale: CGFloat
        if bounds.isNull {
            coordinateScale = 1
        } else {
            coordinateScale = max(
                1,
                max(abs(bounds.minX), max(abs(bounds.maxX), max(abs(bounds.minY), abs(bounds.maxY))))
            )
        }
        let numericalFloor = coordinateScale * CGFloat.ulpOfOne * 64
        return min(0.005, max(numericalFloor, abs(lineWidth) / 16384))
    }

    private static func maximumArcStep(radius: CGFloat, tolerance: CGFloat) -> CGFloat {
        let relative = min(1, max(0, tolerance / max(radius, CGFloat.leastNonzeroMagnitude)))
        let step = 2 * acos(max(-1, min(1, 1 - relative)))
        return min(.pi / 64, max(.pi / 512, step))
    }

    private static func deduplicated(_ points: [CGPoint]) -> [CGPoint] {
        var result: [CGPoint] = []
        result.reserveCapacity(points.count)
        for point in points {
            if let last = result.last, pointsEqual(last, point) { continue }
            result.append(point)
        }
        return result
    }

    @inline(__always)
    private static func adding(_ lhs: CGPoint, _ rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    @inline(__always)
    private static func subtracting(_ lhs: CGPoint, _ rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    @inline(__always)
    private static func scaled(_ point: CGPoint, by scalar: CGFloat) -> CGPoint {
        CGPoint(x: point.x * scalar, y: point.y * scalar)
    }

    @inline(__always)
    private static func dotProduct(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        lhs.x * rhs.x + lhs.y * rhs.y
    }

    @inline(__always)
    private static func crossProduct(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        lhs.x * rhs.y - lhs.y * rhs.x
    }

    @inline(__always)
    private static func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }

    @inline(__always)
    private static func geometryEpsilon(for first: CGPoint, _ second: CGPoint) -> CGFloat {
        max(
            1,
            max(abs(first.x), max(abs(first.y), max(abs(second.x), abs(second.y))))
        ) * CGFloat.ulpOfOne * 64
    }

    @inline(__always)
    private static func pointsEqual(_ lhs: CGPoint, _ rhs: CGPoint) -> Bool {
        distance(lhs, rhs) <= geometryEpsilon(for: lhs, rhs)
    }
}
