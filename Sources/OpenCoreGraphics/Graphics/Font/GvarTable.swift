//
//  GvarTable.swift
//  OpenCoreGraphics
//
//  OpenType `gvar` tuple variation decoding and IUP interpolation.
//

import Foundation

internal struct GvarTable: Sendable {
    private struct TupleHeader: Sendable {
        let dataSize: Int
        let peak: [CGFloat]
        let intermediateStart: [CGFloat]?
        let intermediateEnd: [CGFloat]?
        let hasPrivatePoints: Bool
    }

    private let data: Data
    private let axisCount: Int
    private let glyphDataStart: Int
    private let glyphOffsets: [Int]
    private let sharedTuples: [[CGFloat]]

    init?(data: Data, axisCount: Int, glyphCount: Int) {
        guard axisCount > 0, glyphCount > 0, data.count >= 20,
              data.readUInt16BE(at: 0) == 1,
              data.readUInt16BE(at: 2) == 0,
              Int(data.readUInt16BE(at: 4)) == axisCount,
              Int(data.readUInt16BE(at: 12)) == glyphCount else {
            return nil
        }

        let sharedTupleCount = Int(data.readUInt16BE(at: 6))
        guard let sharedTupleStart = Int(exactly: data.readUInt32BE(at: 8)),
              let glyphDataStart = Int(exactly: data.readUInt32BE(at: 16)) else {
            return nil
        }
        let flags = data.readUInt16BE(at: 14)
        guard flags & 0xFFFE == 0 else { return nil }

        let usesLongOffsets = flags & 1 != 0
        let offsetStride = usesLongOffsets ? 4 : 2
        let offsetCount = glyphCount + 1
        guard offsetCount <= (data.count - 20) / offsetStride,
              sharedTupleStart >= 20 + offsetCount * offsetStride,
              sharedTupleStart <= data.count,
              sharedTupleCount <= Int.max / axisCount,
              sharedTupleCount * axisCount <= (data.count - sharedTupleStart) / 2,
              glyphDataStart >= 20 + offsetCount * offsetStride,
              glyphDataStart <= data.count else {
            return nil
        }

        var offsets: [Int] = []
        offsets.reserveCapacity(offsetCount)
        for index in 0..<offsetCount {
            let stored: Int
            if usesLongOffsets {
                guard let longOffset = Int(exactly: data.readUInt32BE(at: 20 + index * 4)) else {
                    return nil
                }
                stored = longOffset
            } else {
                stored = Int(data.readUInt16BE(at: 20 + index * 2)) * 2
            }
            guard stored <= data.count - glyphDataStart,
                  offsets.last.map({ $0 <= stored }) ?? true else {
                return nil
            }
            offsets.append(stored)
        }

        var tuples: [[CGFloat]] = []
        tuples.reserveCapacity(sharedTupleCount)
        var tupleCursor = sharedTupleStart
        for _ in 0..<sharedTupleCount {
            var tuple: [CGFloat] = []
            tuple.reserveCapacity(axisCount)
            for _ in 0..<axisCount {
                tuple.append(data.readF2Dot14(at: tupleCursor))
                tupleCursor += 2
            }
            guard Self.validPeak(tuple, axisCount: axisCount) else { return nil }
            tuples.append(tuple)
        }

        self.data = data
        self.axisCount = axisCount
        self.glyphDataStart = glyphDataStart
        self.glyphOffsets = offsets
        self.sharedTuples = tuples

        for glyphIndex in 0..<glyphCount {
            guard validateGlyphStructure(glyphIndex: glyphIndex) else { return nil }
        }
    }

    func adjustments(
        glyphIndex: Int,
        pointCount: Int,
        normalizedCoordinates: [CGFloat],
        originalPoints: [CGPoint],
        contourRanges: [Range<Int>]
    ) -> [CGPoint]? {
        guard glyphOffsets.indices.contains(glyphIndex + 1),
              pointCount >= 4,
              normalizedCoordinates.count == axisCount,
              originalPoints.count == pointCount else {
            return nil
        }
        let start = glyphDataStart + glyphOffsets[glyphIndex]
        let end = glyphDataStart + glyphOffsets[glyphIndex + 1]
        if start == end { return [CGPoint](repeating: .zero, count: pointCount) }

        guard let parsed = parseHeaders(start: start, end: end) else { return nil }
        var serializedCursor = parsed.dataStart
        let sharedPoints: [Int]?
        if parsed.hasSharedPoints {
            guard let decoded = decodePoints(cursor: &serializedCursor, end: end, pointCount: pointCount) else {
                return nil
            }
            sharedPoints = decoded
        } else {
            sharedPoints = nil
        }

        var result = [CGPoint](repeating: .zero, count: pointCount)
        for header in parsed.headers {
            guard header.dataSize <= end - serializedCursor else { return nil }
            let tupleEnd = serializedCursor + header.dataSize
            var tupleCursor = serializedCursor
            let points: [Int]
            if header.hasPrivatePoints {
                guard let decoded = decodePoints(
                    cursor: &tupleCursor,
                    end: tupleEnd,
                    pointCount: pointCount
                ) else { return nil }
                points = decoded ?? Array(0..<pointCount)
            } else {
                points = sharedPoints ?? Array(0..<pointCount)
            }
            guard let xDeltas = decodeDeltas(cursor: &tupleCursor, end: tupleEnd, count: points.count),
                  let yDeltas = decodeDeltas(cursor: &tupleCursor, end: tupleEnd, count: points.count),
                  tupleCursor == tupleEnd else {
                return nil
            }

            let scalar = tupleScalar(header: header, coordinates: normalizedCoordinates)
            if scalar != 0 {
                var tupleDeltas = [CGPoint](repeating: .zero, count: pointCount)
                var touched = [Bool](repeating: false, count: pointCount)
                for index in points.indices {
                    let pointIndex = points[index]
                    tupleDeltas[pointIndex].x += xDeltas[index]
                    tupleDeltas[pointIndex].y += yDeltas[index]
                    touched[pointIndex] = true
                }
                inferUntouchedDeltas(
                    deltas: &tupleDeltas,
                    touched: touched,
                    originalPoints: originalPoints,
                    contourRanges: contourRanges
                )
                for index in result.indices {
                    result[index].x += tupleDeltas[index].x * scalar
                    result[index].y += tupleDeltas[index].y * scalar
                }
            }
            serializedCursor = tupleEnd
        }
        guard serializedCursor <= end else { return nil }
        return result
    }

    private func validateGlyphStructure(glyphIndex: Int) -> Bool {
        let start = glyphDataStart + glyphOffsets[glyphIndex]
        let end = glyphDataStart + glyphOffsets[glyphIndex + 1]
        if start == end { return true }
        guard let parsed = parseHeaders(start: start, end: end) else { return false }
        let serializedSize = parsed.headers.reduce(0) { partial, header in
            partial + header.dataSize
        }
        return serializedSize <= end - parsed.dataStart
    }

    private func parseHeaders(
        start: Int,
        end: Int
    ) -> (headers: [TupleHeader], dataStart: Int, hasSharedPoints: Bool)? {
        guard start >= 0, start <= end - 4, end <= data.count else { return nil }
        let packedCount = data.readUInt16BE(at: start)
        guard packedCount & 0x7000 == 0 else { return nil }
        let tupleCount = Int(packedCount & 0x0FFF)
        guard tupleCount > 0 else { return nil }
        let dataOffset = Int(data.readUInt16BE(at: start + 2))
        guard dataOffset >= 4, dataOffset <= end - start else { return nil }

        var cursor = start + 4
        var headers: [TupleHeader] = []
        headers.reserveCapacity(tupleCount)
        for _ in 0..<tupleCount {
            guard cursor <= end - 4 else { return nil }
            let dataSize = Int(data.readUInt16BE(at: cursor))
            let tupleIndex = data.readUInt16BE(at: cursor + 2)
            guard tupleIndex & 0x1000 == 0 else { return nil }
            cursor += 4

            let peak: [CGFloat]
            if tupleIndex & 0x8000 != 0 {
                guard let tuple = readTuple(cursor: &cursor, end: end),
                      Self.validPeak(tuple, axisCount: axisCount) else { return nil }
                peak = tuple
            } else {
                let sharedIndex = Int(tupleIndex & 0x0FFF)
                guard sharedTuples.indices.contains(sharedIndex) else { return nil }
                peak = sharedTuples[sharedIndex]
            }

            var intermediateStart: [CGFloat]?
            var intermediateEnd: [CGFloat]?
            if tupleIndex & 0x4000 != 0 {
                guard let startTuple = readTuple(cursor: &cursor, end: end),
                      let endTuple = readTuple(cursor: &cursor, end: end),
                      validRegion(start: startTuple, peak: peak, end: endTuple) else {
                    return nil
                }
                intermediateStart = startTuple
                intermediateEnd = endTuple
            }
            headers.append(TupleHeader(
                dataSize: dataSize,
                peak: peak,
                intermediateStart: intermediateStart,
                intermediateEnd: intermediateEnd,
                hasPrivatePoints: tupleIndex & 0x2000 != 0
            ))
        }
        let dataStart = start + dataOffset
        guard cursor <= dataStart else { return nil }
        return (headers, dataStart, packedCount & 0x8000 != 0)
    }

    private func readTuple(cursor: inout Int, end: Int) -> [CGFloat]? {
        guard axisCount <= (end - cursor) / 2 else { return nil }
        var tuple: [CGFloat] = []
        tuple.reserveCapacity(axisCount)
        for _ in 0..<axisCount {
            tuple.append(data.readF2Dot14(at: cursor))
            cursor += 2
        }
        return tuple
    }

    private func validRegion(start: [CGFloat], peak: [CGFloat], end: [CGFloat]) -> Bool {
        guard start.count == axisCount, peak.count == axisCount, end.count == axisCount else {
            return false
        }
        for index in 0..<axisCount {
            guard start[index] >= -1, end[index] <= 1,
                  start[index] <= peak[index], peak[index] <= end[index],
                  (start[index] >= 0 && end[index] >= 0)
                    || (start[index] <= 0 && end[index] <= 0)
                    || peak[index] == 0 else {
                return false
            }
        }
        return true
    }

    private static func validPeak(_ peak: [CGFloat], axisCount: Int) -> Bool {
        peak.count == axisCount && peak.allSatisfy { $0 >= -1 && $0 <= 1 }
    }

    private func tupleScalar(header: TupleHeader, coordinates: [CGFloat]) -> CGFloat {
        var scalar: CGFloat = 1
        for index in 0..<axisCount {
            let peak = header.peak[index]
            if peak == 0 { continue }
            let start = header.intermediateStart?[index] ?? min(peak, 0)
            let end = header.intermediateEnd?[index] ?? max(peak, 0)
            let coordinate = coordinates[index]
            if coordinate == peak { continue }
            if coordinate <= start || coordinate >= end { return 0 }
            if coordinate < peak {
                guard peak != start else { return 0 }
                scalar *= (coordinate - start) / (peak - start)
            } else {
                guard end != peak else { return 0 }
                scalar *= (end - coordinate) / (end - peak)
            }
        }
        return scalar
    }

    private func decodePoints(cursor: inout Int, end: Int, pointCount: Int) -> [Int]?? {
        guard cursor < end else { return nil }
        let first = data.readUInt8(at: cursor)
        cursor += 1
        if first == 0 { return .some(nil) }
        let count: Int
        if first & 0x80 != 0 {
            guard cursor < end else { return nil }
            count = (Int(first & 0x7F) << 8) | Int(data.readUInt8(at: cursor))
            cursor += 1
        } else {
            count = Int(first)
        }
        guard count > 0, count <= 0x7FFF else { return nil }

        var points: [Int] = []
        points.reserveCapacity(count)
        var current = 0
        while points.count < count {
            guard cursor < end else { return nil }
            let control = data.readUInt8(at: cursor)
            cursor += 1
            let runCount = Int(control & 0x7F) + 1
            guard runCount <= count - points.count else { return nil }
            for _ in 0..<runCount {
                let delta: Int
                if control & 0x80 != 0 {
                    guard cursor <= end - 2 else { return nil }
                    delta = Int(data.readUInt16BE(at: cursor))
                    cursor += 2
                } else {
                    guard cursor < end else { return nil }
                    delta = Int(data.readUInt8(at: cursor))
                    cursor += 1
                }
                guard current <= Int.max - delta else { return nil }
                current += delta
                guard current < pointCount else { return nil }
                points.append(current)
            }
        }
        return .some(points)
    }

    private func decodeDeltas(cursor: inout Int, end: Int, count: Int) -> [CGFloat]? {
        var deltas: [CGFloat] = []
        deltas.reserveCapacity(count)
        while deltas.count < count {
            guard cursor < end else { return nil }
            let control = data.readUInt8(at: cursor)
            cursor += 1
            let runCount = Int(control & 0x3F) + 1
            guard runCount <= count - deltas.count else { return nil }
            if control & 0x80 != 0 {
                deltas.append(contentsOf: repeatElement(0, count: runCount))
            } else if control & 0x40 != 0 {
                guard runCount <= (end - cursor) / 2 else { return nil }
                for _ in 0..<runCount {
                    deltas.append(CGFloat(data.readInt16BE(at: cursor)))
                    cursor += 2
                }
            } else {
                guard runCount <= end - cursor else { return nil }
                for _ in 0..<runCount {
                    deltas.append(CGFloat(data.readInt8(at: cursor)))
                    cursor += 1
                }
            }
        }
        return deltas
    }

    private func inferUntouchedDeltas(
        deltas: inout [CGPoint],
        touched: [Bool],
        originalPoints: [CGPoint],
        contourRanges: [Range<Int>]
    ) {
        for range in contourRanges where !range.isEmpty {
            let touchedIndices = range.filter { touched[$0] }
            guard !touchedIndices.isEmpty, touchedIndices.count < range.count else { continue }
            for index in range where !touched[index] {
                let preceding = touchedIndices.last(where: { $0 < index }) ?? touchedIndices.last!
                let following = touchedIndices.first(where: { $0 > index }) ?? touchedIndices.first!
                deltas[index].x = inferredDelta(
                    coordinate: originalPoints[index].x,
                    precedingCoordinate: originalPoints[preceding].x,
                    followingCoordinate: originalPoints[following].x,
                    precedingDelta: deltas[preceding].x,
                    followingDelta: deltas[following].x
                )
                deltas[index].y = inferredDelta(
                    coordinate: originalPoints[index].y,
                    precedingCoordinate: originalPoints[preceding].y,
                    followingCoordinate: originalPoints[following].y,
                    precedingDelta: deltas[preceding].y,
                    followingDelta: deltas[following].y
                )
            }
        }
    }

    private func inferredDelta(
        coordinate: CGFloat,
        precedingCoordinate: CGFloat,
        followingCoordinate: CGFloat,
        precedingDelta: CGFloat,
        followingDelta: CGFloat
    ) -> CGFloat {
        if precedingCoordinate == followingCoordinate {
            return precedingDelta == followingDelta ? precedingDelta : 0
        }
        let minimum = min(precedingCoordinate, followingCoordinate)
        let maximum = max(precedingCoordinate, followingCoordinate)
        if coordinate <= minimum {
            return precedingCoordinate < followingCoordinate ? precedingDelta : followingDelta
        }
        if coordinate >= maximum {
            return precedingCoordinate > followingCoordinate ? precedingDelta : followingDelta
        }
        let proportion = (coordinate - precedingCoordinate)
            / (followingCoordinate - precedingCoordinate)
        return precedingDelta + proportion * (followingDelta - precedingDelta)
    }
}
