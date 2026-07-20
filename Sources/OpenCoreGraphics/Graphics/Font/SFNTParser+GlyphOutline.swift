//
//  SFNTParser+GlyphOutline.swift
//  OpenCoreGraphics
//
//  TrueType `glyf` outline decoding.
//

import Foundation

extension SFNTParser {

    /// Decodes a TrueType glyph into a path in font design units.
    func parseGlyphPath(
        glyphIndex: Int,
        loca: LocaTable,
        gvar: GvarTable? = nil,
        normalizedCoordinates: [CGFloat] = [],
        hmtx: HmtxTable? = nil,
        vmtx: VmtxTable? = nil
    ) -> CGPath? {
        guard let glyfData = tableData(for: FontTableTag.glyf) else { return nil }

        var activeGlyphs: Set<Int> = []
        guard let glyph = parseGlyphOutline(
            glyphIndex: glyphIndex,
            loca: loca,
            glyfData: glyfData,
            gvar: gvar,
            normalizedCoordinates: normalizedCoordinates,
            hmtx: hmtx,
            vmtx: vmtx,
            activeGlyphs: &activeGlyphs,
            depth: 0
        ) else {
            return nil
        }

        guard glyph.phantomPoints.count == 4,
              glyph.basePhantomPoints.count == 4 else {
            return nil
        }
        guard hmtx != nil else { return glyph.outline.path }
        let horizontalOrigin = glyph.phantomPoints[0].x
        let path = glyph.outline.path
        if horizontalOrigin == 0 { return path }
        var transform = CGAffineTransform(
            translationX: -horizontalOrigin,
            y: 0
        )
        return path.copy(using: &transform)
    }

    func parseGlyphVariationMetrics(
        glyphIndex: Int,
        loca: LocaTable,
        gvar: GvarTable,
        normalizedCoordinates: [CGFloat],
        hmtx: HmtxTable,
        vmtx: VmtxTable?
    ) -> (advanceWidth: CGFloat, leftSideBearing: CGFloat, advanceHeight: CGFloat?, topSideBearing: CGFloat?)? {
        guard let glyfData = tableData(for: FontTableTag.glyf) else { return nil }
        var activeGlyphs: Set<Int> = []
        guard let glyph = parseGlyphOutline(
            glyphIndex: glyphIndex,
            loca: loca,
            glyfData: glyfData,
            gvar: gvar,
            normalizedCoordinates: normalizedCoordinates,
            hmtx: hmtx,
            vmtx: vmtx,
            activeGlyphs: &activeGlyphs,
            depth: 0
        ) else { return nil }
        let bounds = glyph.outline.path.boundingBox
        let phantom = glyph.phantomPoints
        let basePhantom = glyph.basePhantomPoints
        guard phantom.count == 4, basePhantom.count == 4 else { return nil }
        let horizontalOriginDelta = phantom[0].x - basePhantom[0].x
        let advanceWidthDelta = phantom[1].x - basePhantom[1].x
        let verticalMetrics: (CGFloat, CGFloat)? = vmtx.map { _ in
            let baseAdvanceHeight = basePhantom[2].y - basePhantom[3].y
            let bottomDelta = phantom[3].y - basePhantom[3].y
            return (baseAdvanceHeight - bottomDelta, phantom[2].y - bounds.maxY)
        }
        return (
            basePhantom[1].x - basePhantom[0].x + advanceWidthDelta,
            bounds.minX - basePhantom[0].x - horizontalOriginDelta,
            verticalMetrics?.0,
            verticalMetrics?.1
        )
    }
}

private extension SFNTParser {

    struct GlyphPoint {
        var position: CGPoint
        let isOnCurve: Bool

        func applying(_ transform: CGAffineTransform) -> GlyphPoint {
            GlyphPoint(position: position.applying(transform), isOnCurve: isOnCurve)
        }
    }

    struct GlyphOutline {
        var contours: [[GlyphPoint]]

        var points: [GlyphPoint] {
            contours.flatMap { $0 }
        }

        var contourRanges: [Range<Int>] {
            var start = 0
            return contours.map { contour in
                defer { start += contour.count }
                return start..<(start + contour.count)
            }
        }

        var path: CGPath {
            let path = CGMutablePath()
            for contour in contours where !contour.isEmpty {
                append(contour: contour, to: path)
            }
            return path
        }

        func applying(_ transform: CGAffineTransform) -> GlyphOutline {
            GlyphOutline(contours: contours.map { contour in
                contour.map { $0.applying(transform) }
            })
        }

        private func append(contour: [GlyphPoint], to path: CGMutablePath) {
            let first = contour[0]
            let last = contour[contour.count - 1]
            let start: CGPoint
            let remaining: ArraySlice<GlyphPoint>

            if first.isOnCurve {
                start = first.position
                remaining = contour.dropFirst()
            } else if last.isOnCurve {
                start = last.position
                remaining = contour.dropLast()
            } else {
                start = midpoint(last.position, first.position)
                remaining = contour[...]
            }

            path.move(to: start)
            let points = Array(remaining)
            var index = 0

            while index < points.count {
                let point = points[index]
                if point.isOnCurve {
                    path.addLine(to: point.position)
                    index += 1
                    continue
                }

                if index + 1 < points.count {
                    let next = points[index + 1]
                    if next.isOnCurve {
                        path.addQuadCurve(to: next.position, control: point.position)
                        index += 2
                    } else {
                        path.addQuadCurve(
                            to: midpoint(point.position, next.position),
                            control: point.position
                        )
                        index += 1
                    }
                } else {
                    path.addQuadCurve(to: start, control: point.position)
                    index += 1
                }
            }

            path.closeSubpath()
        }

        private func midpoint(_ lhs: CGPoint, _ rhs: CGPoint) -> CGPoint {
            CGPoint(x: (lhs.x + rhs.x) / 2, y: (lhs.y + rhs.y) / 2)
        }
    }

    struct ParsedGlyph {
        var outline: GlyphOutline
        var basePhantomPoints: [CGPoint]
        var phantomPoints: [CGPoint]
    }

    struct CompoundComponent {
        let flags: UInt16
        let glyphIndex: Int
        let argument1: Int
        let argument2: Int
        let linearTransform: CGAffineTransform
    }

    func parseGlyphOutline(
        glyphIndex: Int,
        loca: LocaTable,
        glyfData: Data,
        gvar: GvarTable?,
        normalizedCoordinates: [CGFloat],
        hmtx: HmtxTable?,
        vmtx: VmtxTable?,
        activeGlyphs: inout Set<Int>,
        depth: Int
    ) -> ParsedGlyph? {
        guard depth <= 32,
              !activeGlyphs.contains(glyphIndex),
              let location = loca.glyphLocation(for: glyphIndex),
              location.length >= 0,
              location.offset >= 0,
              location.offset + location.length <= glyfData.count else {
            return nil
        }

        if location.length == 0 {
            guard let phantom = phantomPoints(
                glyphIndex: glyphIndex,
                glyphOffset: location.offset,
                glyfData: glyfData,
                hmtx: hmtx,
                vmtx: vmtx
            ) else { return nil }
            let deltas: [CGPoint]
            if let gvar {
                guard let resolved = gvar.adjustments(
                    glyphIndex: glyphIndex,
                    pointCount: 4,
                    normalizedCoordinates: normalizedCoordinates,
                    originalPoints: phantom,
                    contourRanges: []
                ) else { return nil }
                deltas = resolved
            } else {
                deltas = [CGPoint](repeating: .zero, count: 4)
            }
            guard deltas.count == 4 else { return nil }
            return ParsedGlyph(
                outline: GlyphOutline(contours: []),
                basePhantomPoints: phantom,
                phantomPoints: zip(phantom, deltas).map { point, delta in
                    CGPoint(x: point.x + delta.x, y: point.y + delta.y)
                }
            )
        }
        guard location.length >= 10 else { return nil }

        activeGlyphs.insert(glyphIndex)
        defer { activeGlyphs.remove(glyphIndex) }

        let numberOfContours = glyfData.readInt16BE(at: location.offset)
        if numberOfContours >= 0 {
            guard var outline = parseSimpleGlyph(
                at: location.offset,
                length: location.length,
                numberOfContours: Int(numberOfContours),
                glyfData: glyfData
            ), let phantom = phantomPoints(
                glyphIndex: glyphIndex,
                glyphOffset: location.offset,
                glyfData: glyfData,
                hmtx: hmtx,
                vmtx: vmtx
            ) else { return nil }
            var originalPoints = outline.points.map(\.position)
            originalPoints.append(contentsOf: phantom)
            let contourRanges = outline.contourRanges
            let deltas: [CGPoint]
            if let gvar {
                guard let resolved = gvar.adjustments(
                    glyphIndex: glyphIndex,
                    pointCount: originalPoints.count,
                    normalizedCoordinates: normalizedCoordinates,
                    originalPoints: originalPoints,
                    contourRanges: contourRanges
                ) else { return nil }
                deltas = resolved
            } else {
                deltas = [CGPoint](repeating: .zero, count: originalPoints.count)
            }
            var deltaIndex = 0
            for contourIndex in outline.contours.indices {
                for pointIndex in outline.contours[contourIndex].indices {
                    outline.contours[contourIndex][pointIndex].position.x += deltas[deltaIndex].x
                    outline.contours[contourIndex][pointIndex].position.y += deltas[deltaIndex].y
                    deltaIndex += 1
                }
            }
            let variedPhantom = (0..<4).map { index in
                let delta = deltas[deltaIndex + index]
                return CGPoint(x: phantom[index].x + delta.x, y: phantom[index].y + delta.y)
            }
            return ParsedGlyph(
                outline: outline,
                basePhantomPoints: phantom,
                phantomPoints: variedPhantom
            )
        }

        return parseCompoundGlyph(
            glyphIndex: glyphIndex,
            at: location.offset,
            length: location.length,
            loca: loca,
            glyfData: glyfData,
            gvar: gvar,
            normalizedCoordinates: normalizedCoordinates,
            hmtx: hmtx,
            vmtx: vmtx,
            activeGlyphs: &activeGlyphs,
            depth: depth
        )
    }

    func parseSimpleGlyph(
        at glyphOffset: Int,
        length: Int,
        numberOfContours: Int,
        glyfData: Data
    ) -> GlyphOutline? {
        if numberOfContours == 0 {
            return GlyphOutline(contours: [])
        }

        let glyphEnd = glyphOffset + length
        let endPointsOffset = glyphOffset + 10
        guard numberOfContours > 0,
              endPointsOffset + numberOfContours * 2 + 2 <= glyphEnd else {
            return nil
        }

        let endPoints = (0..<numberOfContours).map {
            Int(glyfData.readUInt16BE(at: endPointsOffset + $0 * 2))
        }
        guard let lastEndPoint = endPoints.last,
              zip(endPoints, endPoints.dropFirst()).allSatisfy({ $0 < $1 }) else {
            return nil
        }

        let pointCount = lastEndPoint + 1
        let instructionLengthOffset = endPointsOffset + numberOfContours * 2
        let instructionLength = Int(glyfData.readUInt16BE(at: instructionLengthOffset))
        var cursor = instructionLengthOffset + 2 + instructionLength
        guard cursor <= glyphEnd else { return nil }

        var flags: [UInt8] = []
        flags.reserveCapacity(pointCount)
        while flags.count < pointCount {
            guard cursor < glyphEnd else { return nil }
            let flag = glyfData.readUInt8(at: cursor)
            cursor += 1
            flags.append(flag)

            if flag & 0x08 != 0 {
                guard cursor < glyphEnd else { return nil }
                let repeatCount = Int(glyfData.readUInt8(at: cursor))
                cursor += 1
                guard flags.count + repeatCount <= pointCount else { return nil }
                flags.append(contentsOf: repeatElement(flag, count: repeatCount))
            }
        }

        guard let xCoordinates = decodeCoordinates(
            flags: flags,
            cursor: &cursor,
            glyphEnd: glyphEnd,
            shortFlag: 0x02,
            sameOrPositiveFlag: 0x10,
            data: glyfData
        ), let yCoordinates = decodeCoordinates(
            flags: flags,
            cursor: &cursor,
            glyphEnd: glyphEnd,
            shortFlag: 0x04,
            sameOrPositiveFlag: 0x20,
            data: glyfData
        ) else {
            return nil
        }

        let points = (0..<pointCount).map { index in
            GlyphPoint(
                position: CGPoint(x: xCoordinates[index], y: yCoordinates[index]),
                isOnCurve: flags[index] & 0x01 != 0
            )
        }

        var contours: [[GlyphPoint]] = []
        var contourStart = 0
        for contourEnd in endPoints {
            guard contourEnd >= contourStart, contourEnd < points.count else { return nil }
            contours.append(Array(points[contourStart...contourEnd]))
            contourStart = contourEnd + 1
        }
        return GlyphOutline(contours: contours)
    }

    func decodeCoordinates(
        flags: [UInt8],
        cursor: inout Int,
        glyphEnd: Int,
        shortFlag: UInt8,
        sameOrPositiveFlag: UInt8,
        data: Data
    ) -> [CGFloat]? {
        var coordinates: [CGFloat] = []
        coordinates.reserveCapacity(flags.count)
        var current = 0

        for flag in flags {
            let delta: Int
            if flag & shortFlag != 0 {
                guard cursor < glyphEnd else { return nil }
                let magnitude = Int(data.readUInt8(at: cursor))
                cursor += 1
                delta = flag & sameOrPositiveFlag != 0 ? magnitude : -magnitude
            } else if flag & sameOrPositiveFlag != 0 {
                delta = 0
            } else {
                guard cursor + 2 <= glyphEnd else { return nil }
                delta = Int(data.readInt16BE(at: cursor))
                cursor += 2
            }

            current += delta
            coordinates.append(CGFloat(current))
        }
        return coordinates
    }

    func parseCompoundGlyph(
        glyphIndex: Int,
        at glyphOffset: Int,
        length: Int,
        loca: LocaTable,
        glyfData: Data,
        gvar: GvarTable?,
        normalizedCoordinates: [CGFloat],
        hmtx: HmtxTable?,
        vmtx: VmtxTable?,
        activeGlyphs: inout Set<Int>,
        depth: Int
    ) -> ParsedGlyph? {
        let glyphEnd = glyphOffset + length
        var cursor = glyphOffset + 10
        var components: [CompoundComponent] = []
        var hasMoreComponents = true
        var lastFlags: UInt16 = 0

        while hasMoreComponents {
            guard cursor + 4 <= glyphEnd else { return nil }
            let flags = glyfData.readUInt16BE(at: cursor)
            let componentGlyph = Int(glyfData.readUInt16BE(at: cursor + 2))
            guard flags & 0xE010 == 0,
                  [flags & 0x0008, flags & 0x0040, flags & 0x0080].filter({ $0 != 0 }).count <= 1,
                  !(flags & 0x0800 != 0 && flags & 0x1000 != 0) else {
                return nil
            }
            cursor += 4
            lastFlags = flags

            let argumentsAreWords = flags & 0x0001 != 0
            let argumentsAreXYValues = flags & 0x0002 != 0
            let argument1: Int
            let argument2: Int

            if argumentsAreWords {
                guard cursor + 4 <= glyphEnd else { return nil }
                if argumentsAreXYValues {
                    argument1 = Int(glyfData.readInt16BE(at: cursor))
                    argument2 = Int(glyfData.readInt16BE(at: cursor + 2))
                } else {
                    argument1 = Int(glyfData.readUInt16BE(at: cursor))
                    argument2 = Int(glyfData.readUInt16BE(at: cursor + 2))
                }
                cursor += 4
            } else {
                guard cursor + 2 <= glyphEnd else { return nil }
                if argumentsAreXYValues {
                    argument1 = Int(glyfData.readInt8(at: cursor))
                    argument2 = Int(glyfData.readInt8(at: cursor + 1))
                } else {
                    argument1 = Int(glyfData.readUInt8(at: cursor))
                    argument2 = Int(glyfData.readUInt8(at: cursor + 1))
                }
                cursor += 2
            }

            guard let linearTransform = readComponentTransform(
                flags: flags,
                cursor: &cursor,
                glyphEnd: glyphEnd,
                data: glyfData
            ) else { return nil }
            components.append(CompoundComponent(
                flags: flags,
                glyphIndex: componentGlyph,
                argument1: argument1,
                argument2: argument2,
                linearTransform: linearTransform
            ))
            hasMoreComponents = flags & 0x0020 != 0
        }

        if lastFlags & 0x0100 != 0 {
            guard cursor + 2 <= glyphEnd else { return nil }
            let instructionLength = Int(glyfData.readUInt16BE(at: cursor))
            guard cursor + 2 + instructionLength <= glyphEnd else { return nil }
        }

        guard let basePhantom = phantomPoints(
            glyphIndex: glyphIndex,
            glyphOffset: glyphOffset,
            glyfData: glyfData,
            hmtx: hmtx,
            vmtx: vmtx
        ) else { return nil }
        var pseudoPoints = components.map { component in
            guard component.flags & 0x0002 != 0 else { return CGPoint.zero }
            return CGPoint(x: CGFloat(component.argument1), y: CGFloat(component.argument2))
        }
        pseudoPoints.append(contentsOf: basePhantom)
        let componentDeltas: [CGPoint]
        if let gvar {
            guard let resolved = gvar.adjustments(
                glyphIndex: glyphIndex,
                pointCount: pseudoPoints.count,
                normalizedCoordinates: normalizedCoordinates,
                originalPoints: pseudoPoints,
                contourRanges: []
            ) else { return nil }
            componentDeltas = resolved
        } else {
            componentDeltas = [CGPoint](repeating: .zero, count: pseudoPoints.count)
        }

        var contours: [[GlyphPoint]] = []
        var inheritedBasePhantom = basePhantom
        var variedPhantom = (0..<4).map { index in
            let delta = componentDeltas[components.count + index]
            return CGPoint(
                x: basePhantom[index].x + delta.x,
                y: basePhantom[index].y + delta.y
            )
        }
        for componentIndex in components.indices {
            let component = components[componentIndex]
            guard let child = parseGlyphOutline(
                glyphIndex: component.glyphIndex,
                loca: loca,
                glyfData: glyfData,
                gvar: gvar,
                normalizedCoordinates: normalizedCoordinates,
                hmtx: hmtx,
                vmtx: vmtx,
                activeGlyphs: &activeGlyphs,
                depth: depth + 1
            ) else { return nil }

            var transformedOutline = child.outline.applying(component.linearTransform)
            let translation: CGPoint
            if component.flags & 0x0002 != 0 {
                let delta = componentDeltas[componentIndex]
                let adjustedOffset = CGPoint(
                    x: CGFloat(component.argument1) + delta.x,
                    y: CGFloat(component.argument2) + delta.y
                )
                translation = component.flags & 0x0800 != 0
                    ? adjustedOffset.applying(component.linearTransform)
                    : adjustedOffset
            } else {
                let parentPoints = contours.flatMap { $0 }
                let childPoints = transformedOutline.points
                guard component.argument1 >= 0, component.argument2 >= 0,
                      component.argument1 < parentPoints.count,
                      component.argument2 < childPoints.count else {
                    return nil
                }
                translation = CGPoint(
                    x: parentPoints[component.argument1].position.x
                        - childPoints[component.argument2].position.x,
                    y: parentPoints[component.argument1].position.y
                        - childPoints[component.argument2].position.y
                )
            }
            let translationTransform = CGAffineTransform(
                translationX: translation.x,
                y: translation.y
            )
            transformedOutline = transformedOutline.applying(translationTransform)
            contours.append(contentsOf: transformedOutline.contours)

            if component.flags & 0x0200 != 0 {
                inheritedBasePhantom = child.basePhantomPoints.map { point in
                    point.applying(component.linearTransform).applying(translationTransform)
                }
                variedPhantom = child.phantomPoints.map { point in
                    point.applying(component.linearTransform).applying(translationTransform)
                }
            }
        }
        return ParsedGlyph(
            outline: GlyphOutline(contours: contours),
            basePhantomPoints: inheritedBasePhantom,
            phantomPoints: variedPhantom
        )
    }

    func phantomPoints(
        glyphIndex: Int,
        glyphOffset: Int,
        glyfData: Data,
        hmtx: HmtxTable?,
        vmtx: VmtxTable?
    ) -> [CGPoint]? {
        let hasHeader = glyphOffset >= 0 && glyphOffset <= glyfData.count - 10
        let xMin = hasHeader ? CGFloat(glyfData.readInt16BE(at: glyphOffset + 2)) : 0
        let yMax = hasHeader ? CGFloat(glyfData.readInt16BE(at: glyphOffset + 8)) : 0
        let advanceWidth = hmtx?.advanceWidth(for: glyphIndex).map(CGFloat.init) ?? 0
        let leftSideBearing = hmtx?.leftSideBearing(for: glyphIndex).map(CGFloat.init) ?? 0
        let left = xMin - leftSideBearing
        let advanceHeight = vmtx?.advanceHeight(for: glyphIndex).map(CGFloat.init) ?? 0
        let topSideBearing = vmtx?.topSideBearing(for: glyphIndex).map(CGFloat.init) ?? 0
        let top = yMax + topSideBearing
        return [
            CGPoint(x: left, y: 0),
            CGPoint(x: left + advanceWidth, y: 0),
            CGPoint(x: 0, y: top),
            CGPoint(x: 0, y: top - advanceHeight)
        ]
    }

    func readComponentTransform(
        flags: UInt16,
        cursor: inout Int,
        glyphEnd: Int,
        data: Data
    ) -> CGAffineTransform? {
        if flags & 0x0080 != 0 {
            guard cursor + 8 <= glyphEnd else { return nil }
            let transform = CGAffineTransform(
                a: data.readF2Dot14(at: cursor),
                b: data.readF2Dot14(at: cursor + 2),
                c: data.readF2Dot14(at: cursor + 4),
                d: data.readF2Dot14(at: cursor + 6),
                tx: 0,
                ty: 0
            )
            cursor += 8
            return transform
        }
        if flags & 0x0040 != 0 {
            guard cursor + 4 <= glyphEnd else { return nil }
            let transform = CGAffineTransform(
                scaleX: data.readF2Dot14(at: cursor),
                y: data.readF2Dot14(at: cursor + 2)
            )
            cursor += 4
            return transform
        }
        if flags & 0x0008 != 0 {
            guard cursor + 2 <= glyphEnd else { return nil }
            let scale = data.readF2Dot14(at: cursor)
            cursor += 2
            return CGAffineTransform(scaleX: scale, y: scale)
        }
        return .identity
    }
}
