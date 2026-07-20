//
//  Type2CharStringInterpreter.swift
//  OpenCoreGraphics
//

import Foundation

internal final class Type2CharStringInterpreter {
    enum Format {
        case cff1
        case cff2
    }

    private enum Control {
        case returned
        case ended
    }

    private let data: Data
    private let charString: Range<Int>
    private let localSubroutines: [Range<Int>]?
    private let globalSubroutines: [Range<Int>]
    private let format: Format
    private let variationStore: CFF2VariationStore?
    private let normalizedCoordinates: [CGFloat]
    private let stackLimit: Int
    private let path = CGMutablePath()
    private var stack: [CGFloat] = []
    private var transient = Array(repeating: CGFloat.zero, count: 32)
    private var current = CGPoint.zero
    private var hasOpenContour = false
    private var widthSeen = false
    private var hintCount = 0
    private var randomState: UInt32
    private var isValid = true
    private var variationDataIndex: Int
    private var hasSeenVariationIndex = false
    private var hasSeenBlend = false

    init(
        data: Data,
        charString: Range<Int>,
        localSubroutines: [Range<Int>]?,
        globalSubroutines: [Range<Int>],
        randomSeed: UInt32,
        format: Format = .cff1,
        variationStore: CFF2VariationStore? = nil,
        normalizedCoordinates: [CGFloat] = [],
        defaultVariationDataIndex: Int = 0
    ) {
        self.data = data
        self.charString = charString
        self.localSubroutines = localSubroutines
        self.globalSubroutines = globalSubroutines
        self.randomState = randomSeed
        self.format = format
        self.variationStore = variationStore
        self.normalizedCoordinates = normalizedCoordinates
        self.variationDataIndex = defaultVariationDataIndex
        self.stackLimit = format == .cff2 ? 513 : 48
    }

    func parse() -> CGPath? {
        guard charString.count <= 65_535,
              let control = execute(range: charString, depth: 0, isSubroutine: false),
              control == .ended,
              isValid else {
            return nil
        }
        return path.copy()
    }

    private func execute(range: Range<Int>, depth: Int, isSubroutine: Bool) -> Control? {
        guard depth <= 10, range.lowerBound >= 0, range.upperBound <= data.count else { return nil }
        var cursor = range.lowerBound
        while cursor < range.upperBound {
            let byte = data.readUInt8(at: cursor)
            if byte == 28 || byte >= 32 {
                guard stack.count < stackLimit,
                      let value = decodeNumber(cursor: &cursor, end: range.upperBound) else {
                    return nil
                }
                stack.append(value)
                continue
            }
            cursor += 1

            switch byte {
            case 1, 3, 18, 23:
                guard consumeStemArguments() else { return nil }
            case 4:
                guard prepareMove(argumentCount: 1) else { return nil }
                move(dx: 0, dy: stack[0])
                stack.removeAll(keepingCapacity: true)
            case 5:
                guard stack.count >= 2, stack.count.isMultiple(of: 2) else { return nil }
                for index in stride(from: 0, to: stack.count, by: 2) {
                    line(dx: stack[index], dy: stack[index + 1])
                }
                stack.removeAll(keepingCapacity: true)
            case 6, 7:
                guard !stack.isEmpty else { return nil }
                var horizontal = byte == 6
                for value in stack {
                    line(dx: horizontal ? value : 0, dy: horizontal ? 0 : value)
                    horizontal.toggle()
                }
                stack.removeAll(keepingCapacity: true)
            case 8:
                guard !stack.isEmpty, stack.count.isMultiple(of: 6) else { return nil }
                for index in stride(from: 0, to: stack.count, by: 6) {
                    curve(Array(stack[index..<(index + 6)]))
                }
                stack.removeAll(keepingCapacity: true)
            case 10:
                guard let control = callSubroutine(localSubroutines, depth: depth) else { return nil }
                if control == .ended { return .ended }
            case 11:
                if format == .cff1 {
                    return isSubroutine ? .returned : nil
                }
                stack.removeAll(keepingCapacity: true)
            case 12:
                guard cursor < range.upperBound else { return nil }
                let escaped = data.readUInt8(at: cursor)
                cursor += 1
                guard applyEscapedOperator(escaped) else { return nil }
            case 14:
                if format == .cff2 {
                    stack.removeAll(keepingCapacity: true)
                } else {
                    if !widthSeen, stack.count == 1 || stack.count == 5 {
                        stack.removeFirst()
                        widthSeen = true
                    }
                    guard stack.isEmpty else { return nil }
                    closeContour()
                    return .ended
                }
            case 15:
                guard applyVariationIndex() else { return nil }
            case 16:
                guard applyBlend() else { return nil }
            case 19, 20:
                guard consumeStemArguments(allowEmpty: true), hintCount > 0 else { return nil }
                let maskSize = (hintCount + 7) / 8
                guard maskSize <= range.upperBound - cursor else { return nil }
                if hintCount % 8 != 0 {
                    let unusedBits = 8 - hintCount % 8
                    let mask = UInt8((1 << unusedBits) - 1)
                    guard data.readUInt8(at: cursor + maskSize - 1) & mask == 0 else { return nil }
                }
                cursor += maskSize
            case 21:
                guard prepareMove(argumentCount: 2) else { return nil }
                move(dx: stack[0], dy: stack[1])
                stack.removeAll(keepingCapacity: true)
            case 22:
                guard prepareMove(argumentCount: 1) else { return nil }
                move(dx: stack[0], dy: 0)
                stack.removeAll(keepingCapacity: true)
            case 24:
                guard stack.count >= 8, (stack.count - 2).isMultiple(of: 6) else { return nil }
                var index = 0
                while index < stack.count - 2 {
                    curve(Array(stack[index..<(index + 6)]))
                    index += 6
                }
                line(dx: stack[index], dy: stack[index + 1])
                stack.removeAll(keepingCapacity: true)
            case 25:
                guard stack.count >= 8, (stack.count - 6).isMultiple(of: 2) else { return nil }
                var index = 0
                while index < stack.count - 6 {
                    line(dx: stack[index], dy: stack[index + 1])
                    index += 2
                }
                curve(Array(stack[index..<(index + 6)]))
                stack.removeAll(keepingCapacity: true)
            case 26:
                guard applyAxisCurves(vertical: true) else { return nil }
            case 27:
                guard applyAxisCurves(vertical: false) else { return nil }
            case 29:
                guard let control = callSubroutine(globalSubroutines, depth: depth) else { return nil }
                if control == .ended { return .ended }
            case 30, 31:
                guard applyAlternatingCurves(startsVertical: byte == 30) else { return nil }
            default:
                if format == .cff2 {
                    stack.removeAll(keepingCapacity: true)
                } else {
                    return nil
                }
            }
        }
        guard format == .cff2 else { return nil }
        if isSubroutine { return .returned }
        closeContour()
        return .ended
    }

    private func decodeNumber(cursor: inout Int, end: Int) -> CGFloat? {
        guard cursor < end else { return nil }
        let byte = data.readUInt8(at: cursor)
        cursor += 1
        switch byte {
        case 28:
            guard cursor <= end - 2 else { return nil }
            let value = CGFloat(data.readInt16BE(at: cursor))
            cursor += 2
            return value
        case 32...246:
            return CGFloat(Int(byte) - 139)
        case 247...250:
            guard cursor < end else { return nil }
            let next = Int(data.readUInt8(at: cursor))
            cursor += 1
            return CGFloat((Int(byte) - 247) * 256 + next + 108)
        case 251...254:
            guard cursor < end else { return nil }
            let next = Int(data.readUInt8(at: cursor))
            cursor += 1
            return CGFloat(-((Int(byte) - 251) * 256) - next - 108)
        case 255:
            guard cursor <= end - 4 else { return nil }
            let value = data.readInt32BE(at: cursor)
            cursor += 4
            return CGFloat(value) / 65_536
        default:
            return nil
        }
    }

    private func consumeStemArguments(allowEmpty: Bool = false) -> Bool {
        if format == .cff1, !widthSeen {
            if !stack.count.isMultiple(of: 2) { stack.removeFirst() }
            widthSeen = true
        }
        guard stack.count.isMultiple(of: 2), allowEmpty || !stack.isEmpty,
              hintCount + stack.count / 2 <= 96 else {
            return false
        }
        hintCount += stack.count / 2
        stack.removeAll(keepingCapacity: true)
        return true
    }

    private func prepareMove(argumentCount: Int) -> Bool {
        if format == .cff1, !widthSeen, stack.count == argumentCount + 1 {
            stack.removeFirst()
        }
        widthSeen = true
        return stack.count == argumentCount
    }

    private func move(dx: CGFloat, dy: CGFloat) {
        closeContour()
        current = CGPoint(x: current.x + dx, y: current.y + dy)
        guard current.x.isFinite, current.y.isFinite else {
            isValid = false
            return
        }
        path.move(to: current)
        hasOpenContour = true
    }

    private func line(dx: CGFloat, dy: CGFloat) {
        guard hasOpenContour else {
            isValid = false
            return
        }
        current = CGPoint(x: current.x + dx, y: current.y + dy)
        guard current.x.isFinite, current.y.isFinite else {
            isValid = false
            return
        }
        path.addLine(to: current)
    }

    private func curve(_ values: [CGFloat]) {
        guard hasOpenContour else {
            isValid = false
            return
        }
        let control1 = CGPoint(x: current.x + values[0], y: current.y + values[1])
        let control2 = CGPoint(x: control1.x + values[2], y: control1.y + values[3])
        let end = CGPoint(x: control2.x + values[4], y: control2.y + values[5])
        guard control1.x.isFinite, control1.y.isFinite,
              control2.x.isFinite, control2.y.isFinite,
              end.x.isFinite, end.y.isFinite else {
            isValid = false
            return
        }
        path.addCurve(to: end, control1: control1, control2: control2)
        current = end
    }

    private func closeContour() {
        if hasOpenContour {
            path.closeSubpath()
            hasOpenContour = false
        }
    }

    private func callSubroutine(_ ranges: [Range<Int>]?, depth: Int) -> Control? {
        guard let ranges, let encoded = popInteger() else { return nil }
        let count = ranges.count
        let bias = count < 1_240 ? 107 : (count < 33_900 ? 1_131 : 32_768)
        let subroutineIndex = encoded + bias
        guard ranges.indices.contains(subroutineIndex) else { return nil }
        let range = ranges[subroutineIndex]
        return execute(range: range, depth: depth + 1, isSubroutine: true)
    }

    private func applyAxisCurves(vertical: Bool) -> Bool {
        guard stack.count >= 4 else { return false }
        var values = stack
        var firstOffset: CGFloat = 0
        if values.count % 4 == 1 { firstOffset = values.removeFirst() }
        guard values.count.isMultiple(of: 4) else { return false }
        var first = true
        for index in stride(from: 0, to: values.count, by: 4) {
            if vertical {
                curve([first ? firstOffset : 0, values[index], values[index + 1], values[index + 2], 0, values[index + 3]])
            } else {
                curve([values[index], first ? firstOffset : 0, values[index + 1], values[index + 2], values[index + 3], 0])
            }
            first = false
        }
        stack.removeAll(keepingCapacity: true)
        return true
    }

    private func applyAlternatingCurves(startsVertical: Bool) -> Bool {
        guard stack.count >= 4, stack.count % 4 == 0 || stack.count % 4 == 1 else { return false }
        var values = stack
        var vertical = startsVertical
        while !values.isEmpty {
            guard values.count >= 4 else { return false }
            let finalExtra = values.count == 5 ? values[4] : 0
            let four = Array(values.prefix(4))
            values.removeFirst(4)
            if values.count == 1 { values.removeFirst() }
            if vertical {
                curve([0, four[0], four[1], four[2], four[3], finalExtra])
            } else {
                curve([four[0], 0, four[1], four[2], finalExtra, four[3]])
            }
            vertical.toggle()
        }
        stack.removeAll(keepingCapacity: true)
        return true
    }

    private func applyEscapedOperator(_ operation: UInt8) -> Bool {
        if format == .cff2, !(34...37).contains(operation) {
            stack.removeAll(keepingCapacity: true)
            return true
        }
        switch operation {
        case 0:
            return stack.isEmpty
        case 3:
            return binary { ($0 != 0 && $1 != 0) ? 1 : 0 }
        case 4:
            return binary { ($0 != 0 || $1 != 0) ? 1 : 0 }
        case 5:
            guard let value = stack.popLast() else { return false }
            stack.append(value == 0 ? 1 : 0)
        case 9:
            guard let value = stack.popLast() else { return false }
            stack.append(abs(value))
        case 10:
            return binary(+)
        case 11:
            return binary(-)
        case 12:
            return binary { lhs, rhs in rhs == 0 ? .nan : lhs / rhs }
        case 14:
            guard let value = stack.popLast() else { return false }
            stack.append(-value)
        case 15:
            return binary { $0 == $1 ? 1 : 0 }
        case 18:
            return stack.popLast() != nil
        case 20:
            guard let index = popInteger(), transient.indices.contains(index), let value = stack.popLast() else { return false }
            transient[index] = value
        case 21:
            guard let index = popInteger(), transient.indices.contains(index) else { return false }
            stack.append(transient[index])
        case 22:
            guard let comparison2 = stack.popLast(), let comparison1 = stack.popLast(),
                  let second = stack.popLast(), let first = stack.popLast() else { return false }
            stack.append(comparison1 <= comparison2 ? first : second)
        case 23:
            randomState = randomState &* 1_664_525 &+ 1_013_904_223
            stack.append((CGFloat(randomState >> 8) + 1) / 16_777_217)
        case 24:
            return binary(*)
        case 26:
            guard let value = stack.popLast(), value >= 0 else { return false }
            stack.append(sqrt(value))
        case 27:
            guard let value = stack.last, stack.count < stackLimit else { return false }
            stack.append(value)
        case 28:
            guard stack.count >= 2 else { return false }
            stack.swapAt(stack.count - 1, stack.count - 2)
        case 29:
            guard var index = popInteger(), !stack.isEmpty, stack.count < stackLimit else { return false }
            if index < 0 { index = 0 }
            index = min(index, stack.count - 1)
            stack.append(stack[stack.count - 1 - index])
        case 30:
            guard let shift = popInteger(), let count = popInteger(), count >= 0, count <= stack.count else { return false }
            if count > 1 {
                var normalized = shift % count
                if normalized < 0 { normalized += count }
                let start = stack.count - count
                let suffix = Array(stack[start...])
                let split = count - normalized
                stack.replaceSubrange(start..., with: suffix[split...] + suffix[..<split])
            }
        case 34:
            guard stack.count == 7 else { return false }
            let value = stack
            curve([value[0], 0, value[1], value[2], value[3], 0])
            curve([value[4], 0, value[5], -value[2], value[6], 0])
            stack.removeAll(keepingCapacity: true)
        case 35:
            guard stack.count == 13 else { return false }
            curve(Array(stack[0..<6]))
            curve(Array(stack[6..<12]))
            stack.removeAll(keepingCapacity: true)
        case 36:
            guard stack.count == 9 else { return false }
            let value = stack
            curve([value[0], value[1], value[2], value[3], value[4], 0])
            curve([value[5], 0, value[6], value[7], value[8], -(value[1] + value[3] + value[7])])
            stack.removeAll(keepingCapacity: true)
        case 37:
            guard stack.count == 11 else { return false }
            let value = stack
            let sumX = value[0] + value[2] + value[4] + value[6] + value[8]
            let sumY = value[1] + value[3] + value[5] + value[7] + value[9]
            curve(Array(value[0..<6]))
            let finalX = abs(sumX) > abs(sumY) ? value[10] : -sumX
            let finalY = abs(sumX) > abs(sumY) ? -sumY : value[10]
            curve([value[6], value[7], value[8], value[9], finalX, finalY])
            stack.removeAll(keepingCapacity: true)
        default:
            return false
        }
        return stack.count <= stackLimit && stack.allSatisfy(\.isFinite)
    }

    private func applyVariationIndex() -> Bool {
        guard format == .cff2, !hasSeenVariationIndex, !hasSeenBlend,
              stack.count == 1, let index = popInteger(), index >= 0,
              let variationStore,
              variationStore.scalars(for: index, coordinates: normalizedCoordinates) != nil else {
            return false
        }
        variationDataIndex = index
        hasSeenVariationIndex = true
        return true
    }

    private func applyBlend() -> Bool {
        guard format == .cff2, let variationStore,
              let count = popInteger(), count >= 1,
              let scalars = variationStore.scalars(
                  for: variationDataIndex,
                  coordinates: normalizedCoordinates
              ),
              count <= stackLimit / max(scalars.count + 1, 1) else {
            return false
        }
        let operandCount = count * (scalars.count + 1)
        guard operandCount <= stack.count else { return false }
        let start = stack.count - operandCount
        var blended: [CGFloat] = []
        blended.reserveCapacity(count)
        for valueIndex in 0..<count {
            var value = stack[start + valueIndex]
            let deltaStart = start + count + valueIndex * scalars.count
            for scalarIndex in scalars.indices {
                value += stack[deltaStart + scalarIndex] * scalars[scalarIndex]
            }
            guard value.isFinite else { return false }
            blended.append(value)
        }
        stack.replaceSubrange(start..., with: blended)
        hasSeenBlend = true
        return stack.count <= stackLimit
    }

    private func binary(_ operation: (CGFloat, CGFloat) -> CGFloat) -> Bool {
        guard let rhs = stack.popLast(), let lhs = stack.popLast() else { return false }
        let result = operation(lhs, rhs)
        guard result.isFinite else { return false }
        stack.append(result)
        return true
    }

    private func popInteger() -> Int? {
        guard let value = stack.popLast(), value.isFinite,
              value.rounded(.towardZero) == value,
              value >= CGFloat(Int.min), value <= CGFloat(Int.max) else {
            return nil
        }
        return Int(value)
    }
}
