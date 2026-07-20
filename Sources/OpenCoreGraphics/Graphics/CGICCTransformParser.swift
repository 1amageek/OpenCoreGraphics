//
//  CGICCTransformParser.swift
//  OpenCoreGraphics
//

import Foundation

internal enum CGICCTransformParser {
    enum Result {
        case absent
        case valid(CGICCTransformSet)
        case invalid
    }

    typealias Tag = (offset: Int, size: Int)

    static func parse(
        _ data: Data,
        tags: [UInt32: Tag],
        deviceComponentCount: Int,
        pcsSignature: UInt32,
        mediaWhitePoint: CGColorVector
    ) -> Result {
        let signatures = ["A2B0", "A2B1", "A2B2", "B2A0", "B2A1", "B2A2"].map(signature)
        guard signatures.contains(where: { tags[$0] != nil }) else { return .absent }
        guard pcsSignature == signature("XYZ ") || pcsSignature == signature("Lab ") else { return .invalid }

        func transform(_ name: String, direction: CGICCTransform.Direction) -> CGICCTransform?? {
            guard let tag = tags[signature(name)] else { return .some(nil) }
            guard let value = parseTransform(
                data,
                tag: tag,
                direction: direction,
                deviceComponentCount: deviceComponentCount,
                pcsSignature: pcsSignature
            ) else {
                return nil
            }
            return .some(value)
        }

        guard let a2b0 = transform("A2B0", direction: .toPCS),
              let a2b1 = transform("A2B1", direction: .toPCS),
              let a2b2 = transform("A2B2", direction: .toPCS),
              let b2a0 = transform("B2A0", direction: .fromPCS),
              let b2a1 = transform("B2A1", direction: .fromPCS),
              let b2a2 = transform("B2A2", direction: .fromPCS) else {
            return .invalid
        }

        return .valid(CGICCTransformSet(
            mediaWhitePoint: mediaWhitePoint,
            perceptualToPCS: a2b0,
            colorimetricToPCS: a2b1,
            saturationToPCS: a2b2,
            perceptualFromPCS: b2a0,
            colorimetricFromPCS: b2a1,
            saturationFromPCS: b2a2
        ))
    }

    private static func parseTransform(
        _ data: Data,
        tag: Tag,
        direction: CGICCTransform.Direction,
        deviceComponentCount: Int,
        pcsSignature: UInt32
    ) -> CGICCTransform? {
        guard let type = readUInt32(data, at: tag.offset) else { return nil }
        let encoding: CGICCTransform.PCSEncoding
        let pipeline: CGICCTransformPipeline

        switch type {
        case signature("mAB ") where direction == .toPCS:
            guard let lut = parseComplexLUT(data, tag: tag, direction: direction, deviceComponentCount: deviceComponentCount) else {
                return nil
            }
            pipeline = .aToB(lut)
            encoding = pcsSignature == signature("XYZ ") ? .xyz : .lab
        case signature("mBA ") where direction == .fromPCS:
            guard let lut = parseComplexLUT(data, tag: tag, direction: direction, deviceComponentCount: deviceComponentCount) else {
                return nil
            }
            pipeline = .bToA(lut)
            encoding = pcsSignature == signature("XYZ ") ? .xyz : .lab
        case signature("mft1"):
            guard pcsSignature != signature("XYZ "),
                  let lut = parseLegacyLUT(
                    data,
                    tag: tag,
                    precision: 1,
                    direction: direction,
                    deviceComponentCount: deviceComponentCount,
                    pcsSignature: pcsSignature
                  ) else {
                // ICC does not define an 8-bit PCSXYZ encoding, so accepting it would make the
                // actual colour meaning implementation-dependent.
                return nil
            }
            pipeline = .legacy(lut)
            encoding = .lab
        case signature("mft2"):
            guard let lut = parseLegacyLUT(
                data,
                tag: tag,
                precision: 2,
                direction: direction,
                deviceComponentCount: deviceComponentCount,
                pcsSignature: pcsSignature
            ) else {
                return nil
            }
            pipeline = .legacy(lut)
            encoding = pcsSignature == signature("XYZ ") ? .xyz : .legacyLab16
        default:
            return nil
        }
        return CGICCTransform(pipeline: pipeline, pcsEncoding: encoding, direction: direction)
    }

    private static func parseComplexLUT(
        _ data: Data,
        tag: Tag,
        direction: CGICCTransform.Direction,
        deviceComponentCount: Int
    ) -> CGICCComplexLUT? {
        let end = tag.offset + tag.size
        guard tag.size >= 32,
              data[tag.offset + 4..<tag.offset + 8].allSatisfy({ $0 == 0 }),
              data[tag.offset + 10] == 0,
              data[tag.offset + 11] == 0 else {
            return nil
        }
        let inputChannels = Int(data[tag.offset + 8])
        let outputChannels = Int(data[tag.offset + 9])
        guard (1...15).contains(inputChannels), (1...15).contains(outputChannels) else { return nil }
        switch direction {
        case .toPCS:
            guard inputChannels == deviceComponentCount, outputChannels == 3 else { return nil }
        case .fromPCS:
            guard inputChannels == 3, outputChannels == deviceComponentCount else { return nil }
        }

        guard let bOffset = elementOffset(data, tag: tag, field: 12, required: true),
              let matrixOffset = elementOffset(data, tag: tag, field: 16, required: false),
              let mOffset = elementOffset(data, tag: tag, field: 20, required: false),
              let clutOffset = elementOffset(data, tag: tag, field: 24, required: false),
              let aOffset = elementOffset(data, tag: tag, field: 28, required: false) else {
            return nil
        }

        let bCount = direction == .toPCS ? outputChannels : inputChannels
        let mCount = direction == .toPCS ? outputChannels : inputChannels
        let aCount = direction == .toPCS ? inputChannels : outputChannels
        guard let bCurves = parseCurves(data, at: bOffset, count: bCount, end: end),
              (matrixOffset == 0) == (mOffset == 0),
              (clutOffset == 0) == (aOffset == 0),
              (inputChannels == outputChannels || clutOffset != 0) else {
            return nil
        }

        let matrix: CGColorMatrix?
        let offset: CGColorVector?
        if matrixOffset != 0 {
            guard mCount == 3,
                  let parsed = parseMatrix(data, at: matrixOffset, end: end) else { return nil }
            matrix = parsed.0
            offset = parsed.1
        } else {
            matrix = nil
            offset = nil
        }

        let mCurves: [CGTransferCurve]?
        if mOffset != 0 {
            guard let curves = parseCurves(data, at: mOffset, count: mCount, end: end) else { return nil }
            mCurves = curves
        } else {
            mCurves = nil
        }

        let clut: CGICCCLUT?
        if clutOffset != 0 {
            guard let parsed = parseCLUT(
                data,
                at: clutOffset,
                end: end,
                inputChannels: inputChannels,
                outputChannels: outputChannels
            ) else { return nil }
            clut = parsed
        } else {
            clut = nil
        }

        let aCurves: [CGTransferCurve]?
        if aOffset != 0 {
            guard let curves = parseCurves(data, at: aOffset, count: aCount, end: end) else { return nil }
            aCurves = curves
        } else {
            aCurves = nil
        }

        return CGICCComplexLUT(
            inputChannels: inputChannels,
            outputChannels: outputChannels,
            aCurves: aCurves,
            clut: clut,
            mCurves: mCurves,
            matrix: matrix,
            matrixOffset: offset,
            bCurves: bCurves
        )
    }

    private static func parseLegacyLUT(
        _ data: Data,
        tag: Tag,
        precision: Int,
        direction: CGICCTransform.Direction,
        deviceComponentCount: Int,
        pcsSignature: UInt32
    ) -> CGICCLegacyLUT? {
        let headerSize = precision == 1 ? 48 : 52
        guard tag.size >= headerSize,
              data[tag.offset + 4..<tag.offset + 8].allSatisfy({ $0 == 0 }),
              data[tag.offset + 11] == 0 else {
            return nil
        }
        let inputChannels = Int(data[tag.offset + 8])
        let outputChannels = Int(data[tag.offset + 9])
        let gridPointCount = Int(data[tag.offset + 10])
        guard (1...15).contains(inputChannels), (1...15).contains(outputChannels), gridPointCount >= 2 else {
            return nil
        }
        switch direction {
        case .toPCS:
            guard inputChannels == deviceComponentCount, outputChannels == 3 else { return nil }
        case .fromPCS:
            guard inputChannels == 3, outputChannels == deviceComponentCount else { return nil }
        }

        var matrixValues: [CGFloat] = []
        for index in 0..<9 {
            guard let value = readS15Fixed16(data, at: tag.offset + 12 + index * 4) else { return nil }
            matrixValues.append(value)
        }
        let matrix = CGColorMatrix(
            m00: matrixValues[0], m01: matrixValues[1], m02: matrixValues[2],
            m10: matrixValues[3], m11: matrixValues[4], m12: matrixValues[5],
            m20: matrixValues[6], m21: matrixValues[7], m22: matrixValues[8]
        )
        let appliesMatrix = direction == .fromPCS && pcsSignature == signature("XYZ ")
        if !appliesMatrix, matrix != .identity { return nil }

        let inputEntryCount: Int
        let outputEntryCount: Int
        if precision == 1 {
            inputEntryCount = 256
            outputEntryCount = 256
        } else {
            guard let inputCount = readUInt16(data, at: tag.offset + 48),
                  let outputCount = readUInt16(data, at: tag.offset + 50),
                  (2...4096).contains(Int(inputCount)),
                  (2...4096).contains(Int(outputCount)) else {
                return nil
            }
            inputEntryCount = Int(inputCount)
            outputEntryCount = Int(outputCount)
        }

        guard let clutPointCount = checkedPower(gridPointCount, exponent: inputChannels),
              let inputValueCount = checkedMultiply(inputChannels, inputEntryCount),
              let clutValueCount = checkedMultiply(clutPointCount, outputChannels),
              let outputValueCount = checkedMultiply(outputChannels, outputEntryCount) else {
            return nil
        }
        let totalValueCount = inputValueCount + clutValueCount + outputValueCount
        guard totalValueCount >= inputValueCount,
              let byteCount = checkedMultiply(totalValueCount, precision),
              headerSize <= tag.size,
              byteCount <= tag.size - headerSize else {
            return nil
        }

        var cursor = tag.offset + headerSize
        guard let inputValues = readNormalizedValues(data, at: cursor, count: inputValueCount, precision: precision) else {
            return nil
        }
        cursor += inputValueCount * precision
        guard let clutValues = readNormalizedValues(data, at: cursor, count: clutValueCount, precision: precision) else {
            return nil
        }
        cursor += clutValueCount * precision
        guard let outputValues = readNormalizedValues(data, at: cursor, count: outputValueCount, precision: precision) else {
            return nil
        }

        return CGICCLegacyLUT(
            inputChannels: inputChannels,
            outputChannels: outputChannels,
            matrix: matrix,
            appliesMatrix: appliesMatrix,
            inputTables: partition(inputValues, count: inputChannels, size: inputEntryCount),
            clut: CGICCCLUT(
                gridPoints: Array(repeating: gridPointCount, count: inputChannels),
                outputChannels: outputChannels,
                values: clutValues
            ),
            outputTables: partition(outputValues, count: outputChannels, size: outputEntryCount)
        )
    }

    private static func parseCurves(
        _ data: Data,
        at offset: Int,
        count: Int,
        end: Int
    ) -> [CGTransferCurve]? {
        var curves: [CGTransferCurve] = []
        curves.reserveCapacity(count)
        var cursor = offset
        for _ in 0..<count {
            guard let parsed = parseCurve(data, at: cursor, end: end) else { return nil }
            curves.append(parsed.curve)
            cursor += parsed.alignedLength
        }
        return curves
    }

    private static func parseCurve(
        _ data: Data,
        at offset: Int,
        end: Int
    ) -> (curve: CGTransferCurve, alignedLength: Int)? {
        guard offset.isMultiple(of: 4), offset >= 0, offset <= end - 12,
              let type = readUInt32(data, at: offset),
              data[offset + 4..<offset + 8].allSatisfy({ $0 == 0 }) else {
            return nil
        }
        let curve: CGTransferCurve
        let length: Int
        switch type {
        case signature("curv"):
            guard let countValue = readUInt32(data, at: offset + 8) else { return nil }
            let count = Int(countValue)
            guard count <= (end - offset - 12) / 2 else { return nil }
            length = 12 + count * 2
            if count == 0 {
                curve = .identity
            } else if count == 1 {
                guard let raw = readUInt16(data, at: offset + 12) else { return nil }
                curve = .gamma(CGFloat(raw) / 256)
            } else {
                var values: [CGFloat] = []
                values.reserveCapacity(count)
                for index in 0..<count {
                    guard let raw = readUInt16(data, at: offset + 12 + index * 2) else { return nil }
                    values.append(CGFloat(raw) / 65_535)
                }
                curve = .table(values)
            }
        case signature("para"):
            guard let function = readUInt16(data, at: offset + 8), function <= 4,
                  data[offset + 10] == 0, data[offset + 11] == 0 else { return nil }
            let parameterCount = [1, 3, 4, 5, 7][Int(function)]
            length = 12 + parameterCount * 4
            guard length <= end - offset else { return nil }
            var parameters: [CGFloat] = []
            for index in 0..<parameterCount {
                guard let value = readS15Fixed16(data, at: offset + 12 + index * 4) else { return nil }
                parameters.append(value)
            }
            curve = .parametric(function: function, parameters: parameters)
        default:
            return nil
        }
        let alignedLength = (length + 3) & ~3
        guard alignedLength <= end - offset, curve.isValid else { return nil }
        return (curve, alignedLength)
    }

    private static func parseMatrix(
        _ data: Data,
        at offset: Int,
        end: Int
    ) -> (CGColorMatrix, CGColorVector)? {
        guard offset.isMultiple(of: 4), offset >= 0, offset <= end - 48 else { return nil }
        var values: [CGFloat] = []
        for index in 0..<12 {
            guard let value = readS15Fixed16(data, at: offset + index * 4) else { return nil }
            values.append(value)
        }
        return (
            CGColorMatrix(
                m00: values[0], m01: values[1], m02: values[2],
                m10: values[3], m11: values[4], m12: values[5],
                m20: values[6], m21: values[7], m22: values[8]
            ),
            CGColorVector(x: values[9], y: values[10], z: values[11])
        )
    }

    private static func parseCLUT(
        _ data: Data,
        at offset: Int,
        end: Int,
        inputChannels: Int,
        outputChannels: Int
    ) -> CGICCCLUT? {
        guard offset.isMultiple(of: 4), offset >= 0, offset <= end - 20 else { return nil }
        let gridPoints = (0..<inputChannels).map { Int(data[offset + $0]) }
        guard gridPoints.allSatisfy({ $0 >= 2 }),
              data[offset + inputChannels..<offset + 16].allSatisfy({ $0 == 0 }),
              (data[offset + 16] == 1 || data[offset + 16] == 2),
              data[offset + 17..<offset + 20].allSatisfy({ $0 == 0 }) else {
            return nil
        }
        let precision = Int(data[offset + 16])
        guard let pointCount = checkedProduct(gridPoints),
              let valueCount = checkedMultiply(pointCount, outputChannels),
              let byteCount = checkedMultiply(valueCount, precision),
              byteCount <= end - offset - 20,
              let values = readNormalizedValues(data, at: offset + 20, count: valueCount, precision: precision) else {
            return nil
        }
        return CGICCCLUT(gridPoints: gridPoints, outputChannels: outputChannels, values: values)
    }

    private static func elementOffset(
        _ data: Data,
        tag: Tag,
        field: Int,
        required: Bool
    ) -> Int? {
        guard let relativeValue = readUInt32(data, at: tag.offset + field) else { return nil }
        let relative = Int(relativeValue)
        if relative == 0 { return required ? nil : 0 }
        guard relative >= 32, relative.isMultiple(of: 4), relative <= tag.size - 8 else { return nil }
        return tag.offset + relative
    }

    private static func readNormalizedValues(
        _ data: Data,
        at offset: Int,
        count: Int,
        precision: Int
    ) -> [CGFloat]? {
        guard count >= 0, precision == 1 || precision == 2,
              let byteCount = checkedMultiply(count, precision),
              offset >= 0, offset <= data.count - byteCount else {
            return nil
        }
        var values: [CGFloat] = []
        values.reserveCapacity(count)
        if precision == 1 {
            for index in 0..<count { values.append(CGFloat(data[offset + index]) / 255) }
        } else {
            for index in 0..<count {
                guard let value = readUInt16(data, at: offset + index * 2) else { return nil }
                values.append(CGFloat(value) / 65_535)
            }
        }
        return values
    }

    private static func partition(_ values: [CGFloat], count: Int, size: Int) -> [[CGFloat]] {
        (0..<count).map { index in
            Array(values[(index * size)..<((index + 1) * size)])
        }
    }

    private static func checkedPower(_ base: Int, exponent: Int) -> Int? {
        var result = 1
        for _ in 0..<exponent {
            guard let multiplied = checkedMultiply(result, base) else { return nil }
            result = multiplied
        }
        return result
    }

    private static func checkedProduct(_ values: [Int]) -> Int? {
        var result = 1
        for value in values {
            guard let multiplied = checkedMultiply(result, value) else { return nil }
            result = multiplied
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

    private static func readS15Fixed16(_ data: Data, at offset: Int) -> CGFloat? {
        guard let bits = readUInt32(data, at: offset) else { return nil }
        return CGFloat(Int32(bitPattern: bits)) / 65_536
    }
}
