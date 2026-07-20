//
//  CGICCMultiProcessParser.swift
//  OpenCoreGraphics
//

import Foundation

internal enum CGICCMultiProcessParser {
    enum Result {
        case valid(CGICCTransform)
        case unsupported
        case invalid
    }

    private enum ElementResult {
        case valid(CGICCMultiProcessElement)
        case unsupported
        case invalid
    }

    static func parse(
        _ data: Data,
        tag: CGICCTransformParser.Tag,
        direction: CGICCTransform.Direction,
        deviceComponentCount: Int,
        pcsSignature: UInt32
    ) -> Result {
        let end = tag.offset + tag.size
        guard tag.size >= 24,
              readUInt32(data, at: tag.offset) == signature("mpet"),
              data[tag.offset + 4..<tag.offset + 8].allSatisfy({ $0 == 0 }),
              let inputValue = readUInt16(data, at: tag.offset + 8),
              let outputValue = readUInt16(data, at: tag.offset + 10),
              let elementCountValue = readUInt32(data, at: tag.offset + 12) else {
            return .invalid
        }
        let inputChannels = Int(inputValue)
        let outputChannels = Int(outputValue)
        let elementCount = Int(elementCountValue)
        guard (1...15).contains(inputChannels),
              (1...15).contains(outputChannels),
              elementCount >= 1,
              elementCount <= (tag.size - 16) / 8 else {
            return .invalid
        }
        switch direction {
        case .toPCS:
            guard inputChannels == deviceComponentCount, outputChannels == 3 else { return .invalid }
        case .fromPCS:
            guard inputChannels == 3, outputChannels == deviceComponentCount else { return .invalid }
        }

        let tableEnd = tag.offset + 16 + elementCount * 8
        var positions: [(offset: Int, size: Int)] = []
        positions.reserveCapacity(elementCount)
        for index in 0..<elementCount {
            let entry = tag.offset + 16 + index * 8
            guard let relativeOffsetValue = readUInt32(data, at: entry),
                  let sizeValue = readUInt32(data, at: entry + 4) else {
                return .invalid
            }
            let relativeOffset = Int(relativeOffsetValue)
            let size = Int(sizeValue)
            guard relativeOffset.isMultiple(of: 4),
                  relativeOffset >= 16 + elementCount * 8,
                  size >= 12,
                  relativeOffset <= tag.size,
                  size <= tag.size - relativeOffset else {
                return .invalid
            }
            positions.append((tag.offset + relativeOffset, size))
        }
        guard positions.map(\.offset).min() == tableEnd else { return .invalid }

        var elements: [CGICCMultiProcessElement] = []
        elements.reserveCapacity(elementCount)
        var expectedInputChannels = inputChannels
        for position in positions {
            switch parseElement(data, offset: position.offset, size: position.size, containingEnd: end) {
            case .valid(let element):
                guard element.inputChannels == expectedInputChannels else { return .invalid }
                expectedInputChannels = element.outputChannels
                elements.append(element)
            case .unsupported:
                return .unsupported
            case .invalid:
                return .invalid
            }
        }
        guard expectedInputChannels == outputChannels else { return .invalid }
        let encoding: CGICCTransform.PCSEncoding = pcsSignature == signature("XYZ ") ? .floatXYZ : .floatLab
        return .valid(CGICCTransform(
            pipeline: .multiProcess(CGICCMultiProcessPipeline(
                inputChannels: inputChannels,
                outputChannels: outputChannels,
                elements: elements
            )),
            pcsEncoding: encoding,
            direction: direction
        ))
    }

    private static func parseElement(
        _ data: Data,
        offset: Int,
        size: Int,
        containingEnd: Int
    ) -> ElementResult {
        guard offset >= 0, size >= 12, offset <= containingEnd - size,
              let type = readUInt32(data, at: offset),
              data[offset + 4..<offset + 8].allSatisfy({ $0 == 0 }) else {
            return .invalid
        }
        switch type {
        case signature("cvst"):
            guard let value = parseCurveSet(data, offset: offset, size: size) else { return .invalid }
            return .valid(.curveSet(value))
        case signature("matf"):
            guard let value = parseMatrix(data, offset: offset, size: size) else { return .invalid }
            return .valid(.matrix(value))
        case signature("clut"):
            guard let value = parseCLUT(data, offset: offset, size: size) else { return .invalid }
            return .valid(.clut(value))
        case signature("bACS"), signature("eACS"):
            guard size == 16,
                  let input = readUInt16(data, at: offset + 8),
                  let output = readUInt16(data, at: offset + 10),
                  input == output,
                  input > 0,
                  input <= 15 else {
                return .invalid
            }
            return .valid(.passThrough(channels: Int(input)))
        default:
            return .unsupported
        }
    }

    private static func parseCurveSet(_ data: Data, offset: Int, size: Int) -> [CGICCFloatCurve]? {
        guard let inputValue = readUInt16(data, at: offset + 8),
              let outputValue = readUInt16(data, at: offset + 10),
              inputValue == outputValue else {
            return nil
        }
        let channelCount = Int(inputValue)
        guard (1...15).contains(channelCount), size >= 12 + channelCount * 8 else { return nil }
        let tableEnd = offset + 12 + channelCount * 8
        var positions: [(offset: Int, size: Int)] = []
        for index in 0..<channelCount {
            let entry = offset + 12 + index * 8
            guard let relativeOffsetValue = readUInt32(data, at: entry),
                  let curveSizeValue = readUInt32(data, at: entry + 4) else { return nil }
            let relativeOffset = Int(relativeOffsetValue)
            let curveSize = Int(curveSizeValue)
            guard relativeOffset.isMultiple(of: 4),
                  relativeOffset >= 12 + channelCount * 8,
                  curveSize >= 28,
                  relativeOffset <= size,
                  curveSize <= size - relativeOffset else {
                return nil
            }
            positions.append((offset + relativeOffset, curveSize))
        }
        guard positions.map(\.offset).min() == tableEnd else { return nil }
        var curves: [CGICCFloatCurve] = []
        for position in positions {
            guard let curve = parseFloatCurve(data, offset: position.offset, size: position.size) else { return nil }
            curves.append(curve)
        }
        return curves
    }

    private static func parseFloatCurve(_ data: Data, offset: Int, size: Int) -> CGICCFloatCurve? {
        let end = offset + size
        guard size >= 28,
              readUInt32(data, at: offset) == signature("curf"),
              data[offset + 4..<offset + 8].allSatisfy({ $0 == 0 }),
              let segmentCountValue = readUInt16(data, at: offset + 8),
              segmentCountValue >= 1,
              data[offset + 10] == 0,
              data[offset + 11] == 0 else {
            return nil
        }
        let segmentCount = Int(segmentCountValue)
        guard segmentCount <= (size - 8) / 4 else { return nil }
        var breakpoints: [CGFloat] = []
        for index in 0..<(segmentCount - 1) {
            guard let value = readFloat32(data, at: offset + 12 + index * 4),
                  value.isFinite,
                  breakpoints.last.map({ value >= $0 }) ?? true else {
                return nil
            }
            breakpoints.append(value)
        }

        var cursor = offset + 12 + (segmentCount - 1) * 4
        var segments: [CGICCFloatCurveSegment] = []
        for index in 0..<segmentCount {
            guard cursor <= end - 12,
                  let type = readUInt32(data, at: cursor),
                  data[cursor + 4..<cursor + 8].allSatisfy({ $0 == 0 }) else {
                return nil
            }
            switch type {
            case signature("parf"):
                guard let function = readUInt16(data, at: cursor + 8),
                      function <= 2,
                      data[cursor + 10] == 0,
                      data[cursor + 11] == 0 else { return nil }
                let parameterCount = function == 0 ? 4 : 5
                let segmentSize = 12 + parameterCount * 4
                guard segmentSize <= end - cursor else { return nil }
                var parameters: [CGFloat] = []
                for parameterIndex in 0..<parameterCount {
                    guard let value = readFloat32(data, at: cursor + 12 + parameterIndex * 4),
                          value.isFinite else { return nil }
                    parameters.append(value)
                }
                segments.append(.formula(CGICCFloatFormula(function: function, parameters: parameters)))
                cursor += segmentSize
            case signature("samf"):
                guard index > 0, index < segmentCount - 1,
                      let sampleCountValue = readUInt32(data, at: cursor + 8),
                      sampleCountValue >= 1 else { return nil }
                let sampleCount = Int(sampleCountValue)
                guard sampleCount <= (end - cursor - 12) / 4 else { return nil }
                var samples: [CGFloat] = []
                for sampleIndex in 0..<sampleCount {
                    guard let value = readFloat32(data, at: cursor + 12 + sampleIndex * 4),
                          value.isFinite else { return nil }
                    samples.append(value)
                }
                segments.append(.sampled(samples))
                cursor += 12 + sampleCount * 4
            default:
                return nil
            }
        }
        guard segments.first.map(Self.isFormula) == true,
              segments.last.map(Self.isFormula) == true,
              cursor <= end,
              data[cursor..<end].allSatisfy({ $0 == 0 }) else {
            return nil
        }
        return CGICCFloatCurve(breakpoints: breakpoints, segments: segments)
    }

    private static func parseMatrix(_ data: Data, offset: Int, size: Int) -> CGICCFloatMatrix? {
        guard let inputValue = readUInt16(data, at: offset + 8),
              let outputValue = readUInt16(data, at: offset + 10) else { return nil }
        let inputChannels = Int(inputValue)
        let outputChannels = Int(outputValue)
        guard (1...15).contains(inputChannels), (1...15).contains(outputChannels),
              let coefficientCount = checkedMultiply(inputChannels, outputChannels),
              let valueCount = checkedMultiply(outputChannels, inputChannels + 1),
              let byteCount = checkedMultiply(valueCount, 4),
              byteCount <= size - 12 else {
            return nil
        }
        var values: [CGFloat] = []
        for index in 0..<valueCount {
            guard let value = readFloat32(data, at: offset + 12 + index * 4), value.isFinite else { return nil }
            values.append(value)
        }
        let usedEnd = offset + 12 + byteCount
        guard data[usedEnd..<(offset + size)].allSatisfy({ $0 == 0 }) else { return nil }
        return CGICCFloatMatrix(
            inputChannels: inputChannels,
            outputChannels: outputChannels,
            coefficients: Array(values.prefix(coefficientCount)),
            offsets: Array(values.dropFirst(coefficientCount))
        )
    }

    private static func parseCLUT(_ data: Data, offset: Int, size: Int) -> CGICCCLUT? {
        guard size >= 28,
              let inputValue = readUInt16(data, at: offset + 8),
              let outputValue = readUInt16(data, at: offset + 10) else { return nil }
        let inputChannels = Int(inputValue)
        let outputChannels = Int(outputValue)
        guard (1...15).contains(inputChannels), (1...15).contains(outputChannels) else { return nil }
        let gridPoints = (0..<inputChannels).map { Int(data[offset + 12 + $0]) }
        guard gridPoints.allSatisfy({ $0 >= 2 }),
              data[(offset + 12 + inputChannels)..<(offset + 28)].allSatisfy({ $0 == 0 }),
              let pointCount = checkedProduct(gridPoints),
              let valueCount = checkedMultiply(pointCount, outputChannels),
              let byteCount = checkedMultiply(valueCount, 4),
              byteCount <= size - 28 else {
            return nil
        }
        var values: [CGFloat] = []
        values.reserveCapacity(valueCount)
        for index in 0..<valueCount {
            guard let value = readFloat32(data, at: offset + 28 + index * 4), value.isFinite else { return nil }
            values.append(value)
        }
        let usedEnd = offset + 28 + byteCount
        guard data[usedEnd..<(offset + size)].allSatisfy({ $0 == 0 }) else { return nil }
        return CGICCCLUT(gridPoints: gridPoints, outputChannels: outputChannels, values: values)
    }

    private static func isFormula(_ segment: CGICCFloatCurveSegment) -> Bool {
        if case .formula = segment { return true }
        return false
    }

    private static func checkedProduct(_ values: [Int]) -> Int? {
        var result = 1
        for value in values {
            guard let next = checkedMultiply(result, value) else { return nil }
            result = next
        }
        return result
    }

    private static func checkedMultiply(_ lhs: Int, _ rhs: Int) -> Int? {
        let result = lhs.multipliedReportingOverflow(by: rhs)
        return result.overflow ? nil : result.partialValue
    }

    private static func signature(_ value: String) -> UInt32 {
        value.utf8.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    }

    private static func readUInt16(_ data: Data, at offset: Int) -> UInt16? {
        guard offset >= 0, offset <= data.count - 2 else { return nil }
        return UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
    }

    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32? {
        guard offset >= 0, offset <= data.count - 4 else { return nil }
        return UInt32(data[offset]) << 24
            | UInt32(data[offset + 1]) << 16
            | UInt32(data[offset + 2]) << 8
            | UInt32(data[offset + 3])
    }

    private static func readFloat32(_ data: Data, at offset: Int) -> CGFloat? {
        guard let bits = readUInt32(data, at: offset) else { return nil }
        let value = Float(bitPattern: bits)
        guard value.isZero || value.isNormal else { return nil }
        return CGFloat(value)
    }
}
