//
//  SFNTParser+GlyphOutline.swift
//  OpenCoreGraphics
//
//  TrueType `glyf` outline decoding.
//

import Foundation

extension SFNTParser {

    /// Decodes a TrueType glyph into a path in font design units.
    func parseGlyphPath(glyphIndex: Int, loca: LocaTable) -> CGPath? {
        guard let glyfData = tableData(for: FontTableTag.glyf) else { return nil }

        var activeGlyphs: Set<Int> = []
        guard let outline = parseGlyphOutline(
            glyphIndex: glyphIndex,
            loca: loca,
            glyfData: glyfData,
            activeGlyphs: &activeGlyphs,
            depth: 0
        ) else {
            return nil
        }

        return outline.path
    }
}

private extension SFNTParser {

    struct GlyphPoint {
        let position: CGPoint
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

    func parseGlyphOutline(
        glyphIndex: Int,
        loca: LocaTable,
        glyfData: Data,
        activeGlyphs: inout Set<Int>,
        depth: Int
    ) -> GlyphOutline? {
        guard depth <= 32,
              !activeGlyphs.contains(glyphIndex),
              let location = loca.glyphLocation(for: glyphIndex),
              location.length >= 0,
              location.offset >= 0,
              location.offset + location.length <= glyfData.count else {
            return nil
        }

        if location.length == 0 {
            return GlyphOutline(contours: [])
        }
        guard location.length >= 10 else { return nil }

        activeGlyphs.insert(glyphIndex)
        defer { activeGlyphs.remove(glyphIndex) }

        let numberOfContours = glyfData.readInt16BE(at: location.offset)
        if numberOfContours >= 0 {
            return parseSimpleGlyph(
                at: location.offset,
                length: location.length,
                numberOfContours: Int(numberOfContours),
                glyfData: glyfData
            )
        }

        return parseCompoundGlyph(
            at: location.offset,
            length: location.length,
            loca: loca,
            glyfData: glyfData,
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
        at glyphOffset: Int,
        length: Int,
        loca: LocaTable,
        glyfData: Data,
        activeGlyphs: inout Set<Int>,
        depth: Int
    ) -> GlyphOutline? {
        let glyphEnd = glyphOffset + length
        var cursor = glyphOffset + 10
        var contours: [[GlyphPoint]] = []
        var hasMoreComponents = true
        var lastFlags: UInt16 = 0

        while hasMoreComponents {
            guard cursor + 4 <= glyphEnd else { return nil }
            let flags = glyfData.readUInt16BE(at: cursor)
            let componentGlyph = Int(glyfData.readUInt16BE(at: cursor + 2))
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
            ), let component = parseGlyphOutline(
                glyphIndex: componentGlyph,
                loca: loca,
                glyfData: glyfData,
                activeGlyphs: &activeGlyphs,
                depth: depth + 1
            ) else {
                return nil
            }

            var transformedComponent = component.applying(linearTransform)
            let translation: CGPoint
            if argumentsAreXYValues {
                let rawOffset = CGPoint(x: CGFloat(argument1), y: CGFloat(argument2))
                if flags & 0x0800 != 0 {
                    translation = rawOffset.applying(linearTransform)
                } else {
                    translation = rawOffset
                }
            } else {
                let parentPoints = contours.flatMap { $0 }
                let componentPoints = transformedComponent.points
                guard argument1 < parentPoints.count, argument2 < componentPoints.count else {
                    return nil
                }
                translation = CGPoint(
                    x: parentPoints[argument1].position.x - componentPoints[argument2].position.x,
                    y: parentPoints[argument1].position.y - componentPoints[argument2].position.y
                )
            }

            transformedComponent = transformedComponent.applying(
                CGAffineTransform(translationX: translation.x, y: translation.y)
            )
            contours.append(contentsOf: transformedComponent.contours)
            hasMoreComponents = flags & 0x0020 != 0
        }

        if lastFlags & 0x0100 != 0 {
            guard cursor + 2 <= glyphEnd else { return nil }
            let instructionLength = Int(glyfData.readUInt16BE(at: cursor))
            guard cursor + 2 + instructionLength <= glyphEnd else { return nil }
        }

        return GlyphOutline(contours: contours)
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
