//
//  CFF2FontProgram.swift
//  OpenCoreGraphics
//

import Foundation

internal struct CFF2FontProgram: Sendable {
    private struct PrivateProgram: Sendable {
        let localSubroutines: CFF2Index?
        let variationDataIndex: Int
    }

    let data: Data
    let charStrings: CFF2Index
    private let globalSubroutines: CFF2Index
    private let privatePrograms: [PrivateProgram]
    private let fontDictionarySelection: [Int]?
    private let variationStore: CFF2VariationStore?
    private let axisCount: Int

    init?(data: Data, axisCount: Int, unitsPerEm: Int) {
        guard data.count >= 5,
              data.readUInt8(at: 0) == 2,
              data.readUInt8(at: 1) == 0,
              data.readUInt8(at: 2) == 5 else {
            return nil
        }
        let headerSize = Int(data.readUInt8(at: 2))
        let topDictionarySize = Int(data.readUInt16BE(at: 3))
        guard topDictionarySize > 0, topDictionarySize <= data.count - headerSize else { return nil }
        let topRange = headerSize..<(headerSize + topDictionarySize)
        guard let topDictionary = CFFDictionary.parse(data: data, range: topRange),
              Set(topDictionary.keys).isSubset(of: [17, 24, 0x0C24, 0x0C25, 0x0C07]),
              let charStringsOffset = CFFDictionary.integers(topDictionary, key: 17, count: 1)?.first,
              let fontDictionariesOffset = CFFDictionary.integers(
                  topDictionary,
                  key: 0x0C24,
                  count: 1
              )?.first,
              charStringsOffset >= 0, fontDictionariesOffset >= 0,
              let globalSubroutines = CFF2Index(data: data, offset: topRange.upperBound),
              globalSubroutines.ranges.count <= 65_536,
              let charStrings = CFF2Index(data: data, offset: charStringsOffset),
              !charStrings.ranges.isEmpty,
              charStrings.ranges.count <= 65_535,
              let fontDictionaries = CFF2Index(data: data, offset: fontDictionariesOffset),
              !fontDictionaries.ranges.isEmpty else {
            return nil
        }
        guard Self.validateFontMatrix(topDictionary[0x0C07], unitsPerEm: unitsPerEm) else { return nil }

        let parsedVariationStore: CFF2VariationStore?
        if let variationOffset = CFFDictionary.integers(topDictionary, key: 24, count: 1)?.first {
            guard variationOffset >= 0, axisCount > 0,
                  let store = CFF2VariationStore(
                      data: data,
                      offset: variationOffset,
                      axisCount: axisCount
                  ) else {
                return nil
            }
            parsedVariationStore = store
        } else {
            guard topDictionary[24] == nil else { return nil }
            parsedVariationStore = nil
        }

        let selection: [Int]?
        if fontDictionaries.ranges.count == 1 {
            guard topDictionary[0x0C25] == nil else { return nil }
            selection = nil
        } else {
            guard let selectionOffset = CFFDictionary.integers(
                topDictionary,
                key: 0x0C25,
                count: 1
            )?.first,
            let parsed = Self.parseFDSelect(
                data: data,
                offset: selectionOffset,
                glyphCount: charStrings.ranges.count,
                dictionaryCount: fontDictionaries.ranges.count
            ) else {
                return nil
            }
            selection = parsed
        }

        var programs: [PrivateProgram] = []
        programs.reserveCapacity(fontDictionaries.ranges.count)
        for fontDictionaryRange in fontDictionaries.ranges {
            guard let dictionary = CFFDictionary.parse(data: data, range: fontDictionaryRange),
                  Set(dictionary.keys) == [18],
                  let privateValues = CFFDictionary.integers(dictionary, key: 18, count: 2),
                  privateValues[0] >= 0, privateValues[1] >= 0 else {
                return nil
            }
            if privateValues == [0, 0] {
                programs.append(PrivateProgram(localSubroutines: nil, variationDataIndex: 0))
                continue
            }
            let privateSize = privateValues[0]
            let privateOffset = privateValues[1]
            guard privateSize > 0, privateOffset > 0,
                  privateOffset <= data.count, privateSize <= data.count - privateOffset,
                  let privateDictionary = CFF2PrivateDictionary(
                      data: data,
                      range: privateOffset..<(privateOffset + privateSize),
                      variationStore: parsedVariationStore
                  ) else {
                return nil
            }
            let localSubroutines: CFF2Index?
            if let relative = privateDictionary.localSubroutinesOffset {
                guard relative <= data.count - privateOffset,
                      let index = CFF2Index(data: data, offset: privateOffset + relative),
                      index.ranges.count <= 65_536 else {
                    return nil
                }
                localSubroutines = index
            } else {
                localSubroutines = nil
            }
            programs.append(PrivateProgram(
                localSubroutines: localSubroutines,
                variationDataIndex: privateDictionary.variationDataIndex
            ))
        }

        self.data = data
        self.charStrings = charStrings
        self.globalSubroutines = globalSubroutines
        self.privatePrograms = programs
        self.fontDictionarySelection = selection
        self.variationStore = parsedVariationStore
        self.axisCount = axisCount
    }

    func path(glyphIndex: Int, normalizedCoordinates: [CGFloat]) -> CGPath? {
        guard normalizedCoordinates.count == axisCount,
              let charString = charStrings.range(at: glyphIndex) else {
            return nil
        }
        let dictionaryIndex = fontDictionarySelection?[glyphIndex] ?? 0
        guard privatePrograms.indices.contains(dictionaryIndex) else { return nil }
        let privateProgram = privatePrograms[dictionaryIndex]
        return Type2CharStringInterpreter(
            data: data,
            charString: charString,
            localSubroutines: privateProgram.localSubroutines?.ranges,
            globalSubroutines: globalSubroutines.ranges,
            randomSeed: UInt32(truncatingIfNeeded: glyphIndex) &+ 1,
            format: .cff2,
            variationStore: variationStore,
            normalizedCoordinates: normalizedCoordinates,
            defaultVariationDataIndex: privateProgram.variationDataIndex
        ).parse()
    }

    private static func validateFontMatrix(_ values: [CGFloat]?, unitsPerEm: Int) -> Bool {
        guard unitsPerEm > 0 else { return false }
        if values == nil { return unitsPerEm == 1_000 }
        guard let values, values.count == 6,
              values[0] == values[3],
              values[1] == 0, values[2] == 0, values[4] == 0, values[5] == 0 else {
            return false
        }
        return abs(values[0] - 1 / CGFloat(unitsPerEm)) <= 0.000_000_1
    }

    private static func parseFDSelect(
        data: Data,
        offset: Int,
        glyphCount: Int,
        dictionaryCount: Int
    ) -> [Int]? {
        guard offset >= 0, offset < data.count else { return nil }
        switch data.readUInt8(at: offset) {
        case 0:
            guard glyphCount <= data.count - offset - 1 else { return nil }
            let values = (0..<glyphCount).map { Int(data.readUInt8(at: offset + 1 + $0)) }
            return values.allSatisfy({ $0 < dictionaryCount }) ? values : nil
        case 3:
            guard offset <= data.count - 3 else { return nil }
            let count = Int(data.readUInt16BE(at: offset + 1))
            return parseRanges(
                data: data,
                entriesOffset: offset + 3,
                rangeCount: count,
                entrySize: 3,
                glyphCount: glyphCount,
                dictionaryCount: dictionaryCount,
                readsGlyph: { Int(data.readUInt16BE(at: $0)) },
                readsDictionary: { Int(data.readUInt8(at: $0 + 2)) },
                readsSentinel: { Int(data.readUInt16BE(at: $0)) }
            )
        case 4:
            guard offset <= data.count - 5 else { return nil }
            let countValue = data.readUInt32BE(at: offset + 1)
            guard let count = Int(exactly: countValue) else { return nil }
            return parseRanges(
                data: data,
                entriesOffset: offset + 5,
                rangeCount: count,
                entrySize: 6,
                glyphCount: glyphCount,
                dictionaryCount: dictionaryCount,
                readsGlyph: { Int(data.readUInt32BE(at: $0)) },
                readsDictionary: { Int(data.readUInt16BE(at: $0 + 4)) },
                readsSentinel: { Int(data.readUInt32BE(at: $0)) }
            )
        default:
            return nil
        }
    }

    private static func parseRanges(
        data: Data,
        entriesOffset: Int,
        rangeCount: Int,
        entrySize: Int,
        glyphCount: Int,
        dictionaryCount: Int,
        readsGlyph: (Int) -> Int,
        readsDictionary: (Int) -> Int,
        readsSentinel: (Int) -> Int
    ) -> [Int]? {
        let sentinelSize = entrySize == 3 ? 2 : 4
        guard rangeCount > 0,
              rangeCount <= (data.count - entriesOffset - sentinelSize) / entrySize else {
            return nil
        }
        var starts: [(glyph: Int, dictionary: Int)] = []
        starts.reserveCapacity(rangeCount)
        for index in 0..<rangeCount {
            let entry = entriesOffset + index * entrySize
            starts.append((readsGlyph(entry), readsDictionary(entry)))
        }
        let sentinel = readsSentinel(entriesOffset + rangeCount * entrySize)
        guard starts.first?.glyph == 0, sentinel == glyphCount,
              zip(starts, starts.dropFirst()).allSatisfy({ $0.glyph < $1.glyph }),
              starts.allSatisfy({ $0.dictionary < dictionaryCount }) else {
            return nil
        }
        var selection = Array(repeating: 0, count: glyphCount)
        for index in starts.indices {
            let end = index + 1 < starts.count ? starts[index + 1].glyph : sentinel
            guard starts[index].glyph < end else { return nil }
            for glyph in starts[index].glyph..<end { selection[glyph] = starts[index].dictionary }
        }
        return selection
    }
}
