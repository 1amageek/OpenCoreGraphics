//
//  CFF2PrivateDictionary.swift
//  OpenCoreGraphics
//

import Foundation

internal struct CFF2PrivateDictionary: Sendable {
    let localSubroutinesOffset: Int?
    let variationDataIndex: Int

    init?(
        data: Data,
        range: Range<Int>,
        variationStore: CFF2VariationStore?
    ) {
        guard range.lowerBound >= 0, range.upperBound <= data.count else { return nil }
        var stack: [CGFloat] = []
        var cursor = range.lowerBound
        var parsedSubroutinesOffset: Int?
        var parsedVariationDataIndex = 0
        var sawVariationIndex = false

        while cursor < range.upperBound {
            let byte = data.readUInt8(at: cursor)
            if byte >= 28 {
                guard stack.count < 513,
                      let number = CFFDictionary.decodeNumber(
                          data: data,
                          cursor: &cursor,
                          end: range.upperBound
                      ) else {
                    return nil
                }
                stack.append(number)
                continue
            }
            cursor += 1
            let key: UInt16
            if byte == 12 {
                guard cursor < range.upperBound else { return nil }
                key = 0x0C00 | UInt16(data.readUInt8(at: cursor))
                cursor += 1
            } else {
                key = UInt16(byte)
            }

            if key == 23 {
                guard let variationStore,
                      let count = Self.popInteger(from: &stack), count >= 1,
                      let regionCount = variationStore.regionCount(for: parsedVariationDataIndex),
                      count <= 513 / max(regionCount + 1, 1) else {
                    return nil
                }
                let operandCount = count * (regionCount + 1)
                guard operandCount <= stack.count else { return nil }
                let start = stack.count - operandCount
                let defaults = stack[start..<(start + count)]
                stack.replaceSubrange(start..., with: defaults)
                continue
            }

            guard Self.validOperators.contains(key) else { return nil }
            if key == 19 {
                guard parsedSubroutinesOffset == nil, stack.count == 1,
                      let offset = Self.integer(stack[0]), offset >= 0 else {
                    return nil
                }
                parsedSubroutinesOffset = offset
            } else if key == 22 {
                guard !sawVariationIndex, stack.count == 1,
                      let index = Self.integer(stack[0]), index >= 0,
                      let variationStore,
                      variationStore.regionCount(for: index) != nil else {
                    return nil
                }
                parsedVariationDataIndex = index
                sawVariationIndex = true
            }
            stack.removeAll(keepingCapacity: true)
        }
        guard stack.isEmpty else { return nil }
        self.localSubroutinesOffset = parsedSubroutinesOffset
        self.variationDataIndex = parsedVariationDataIndex
    }

    private static let validOperators: Set<UInt16> = [
        6, 7, 8, 9, 10, 11, 19, 22,
        0x0C09, 0x0C0A, 0x0C0B, 0x0C0C, 0x0C0D, 0x0C11, 0x0C12
    ]

    private static func popInteger(from stack: inout [CGFloat]) -> Int? {
        guard let value = stack.popLast() else { return nil }
        return integer(value)
    }

    private static func integer(_ value: CGFloat) -> Int? {
        guard value.isFinite, value.rounded(.towardZero) == value,
              value >= CGFloat(Int.min), value <= CGFloat(Int.max) else {
            return nil
        }
        return Int(value)
    }
}
