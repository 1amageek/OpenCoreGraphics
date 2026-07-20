//
//  CFFFontProgram.swift
//  OpenCoreGraphics
//

import Foundation

internal struct CFFFontProgram: Sendable {
    private struct PrivateProgram: Sendable {
        let localSubroutines: CFFIndex?
    }

    let data: Data
    let charStrings: CFFIndex
    let globalSubroutines: CFFIndex
    private let privatePrograms: [PrivateProgram]
    private let fontDictionarySelection: [Int]?

    init?(data: Data) {
        guard data.count >= 4,
              data.readUInt8(at: 0) == 1,
              data.readUInt8(at: 1) == 0 else {
            return nil
        }
        let headerSize = Int(data.readUInt8(at: 2))
        let headerOffSize = Int(data.readUInt8(at: 3))
        guard headerSize >= 4, headerSize <= data.count, (1...4).contains(headerOffSize),
              let nameIndex = CFFIndex(data: data, offset: headerSize), nameIndex.ranges.count == 1,
              let topDictionaryIndex = CFFIndex(data: data, offset: nameIndex.endOffset),
              topDictionaryIndex.ranges.count == 1,
              let topRange = topDictionaryIndex.range(at: 0),
              let topDictionary = CFFDictionary.parse(data: data, range: topRange),
              let stringIndex = CFFIndex(data: data, offset: topDictionaryIndex.endOffset),
              let globalSubroutines = CFFIndex(data: data, offset: stringIndex.endOffset),
              let charStringsValues = CFFDictionary.integers(topDictionary, key: 17, count: 1),
              charStringsValues[0] >= 0,
              let charStrings = CFFIndex(data: data, offset: charStringsValues[0]),
              !charStrings.ranges.isEmpty else {
            return nil
        }
        if let charStringType = topDictionary[0x0C06] {
            guard charStringType == [2] else { return nil }
        }

        let isCID = topDictionary[0x0C1E] != nil
        let programs: [PrivateProgram]
        let selection: [Int]?
        if isCID {
            guard let fdArrayValues = CFFDictionary.integers(topDictionary, key: 0x0C24, count: 1),
                  let fdSelectValues = CFFDictionary.integers(topDictionary, key: 0x0C25, count: 1),
                  let fontDictionaries = CFFIndex(data: data, offset: fdArrayValues[0]),
                  !fontDictionaries.ranges.isEmpty,
                  let parsedSelection = Self.parseFDSelect(
                    data: data,
                    offset: fdSelectValues[0],
                    glyphCount: charStrings.ranges.count,
                    dictionaryCount: fontDictionaries.ranges.count
                  ) else {
                return nil
            }
            var parsedPrograms: [PrivateProgram] = []
            for range in fontDictionaries.ranges {
                guard let dictionary = CFFDictionary.parse(data: data, range: range),
                      let program = Self.parsePrivateProgram(data: data, dictionary: dictionary) else {
                    return nil
                }
                parsedPrograms.append(program)
            }
            programs = parsedPrograms
            selection = parsedSelection
        } else {
            guard let program = Self.parsePrivateProgram(data: data, dictionary: topDictionary) else { return nil }
            programs = [program]
            selection = nil
        }

        self.data = data
        self.charStrings = charStrings
        self.globalSubroutines = globalSubroutines
        self.privatePrograms = programs
        self.fontDictionarySelection = selection
    }

    func path(glyphIndex: Int) -> CGPath? {
        guard let charString = charStrings.range(at: glyphIndex) else { return nil }
        let dictionaryIndex = fontDictionarySelection?[glyphIndex] ?? 0
        guard privatePrograms.indices.contains(dictionaryIndex) else { return nil }
        return Type2CharStringInterpreter(
            data: data,
            charString: charString,
            localSubroutines: privatePrograms[dictionaryIndex].localSubroutines?.ranges,
            globalSubroutines: globalSubroutines.ranges,
            randomSeed: UInt32(truncatingIfNeeded: glyphIndex) &+ 1
        ).parse()
    }

    private static func parsePrivateProgram(
        data: Data,
        dictionary: [UInt16: [CGFloat]]
    ) -> PrivateProgram? {
        guard let privateValues = dictionary[18] else { return PrivateProgram(localSubroutines: nil) }
        guard privateValues.count == 2,
              let values = CFFDictionary.integers(dictionary, key: 18, count: 2),
              values[0] >= 0, values[1] >= 0,
              values[1] <= data.count, values[0] <= data.count - values[1] else {
            return nil
        }
        if values[0] == 0 { return PrivateProgram(localSubroutines: nil) }
        let range = values[1]..<(values[1] + values[0])
        guard let privateDictionary = CFFDictionary.parse(data: data, range: range) else { return nil }
        guard let subrValues = privateDictionary[19] else { return PrivateProgram(localSubroutines: nil) }
        guard subrValues.count == 1,
              let relative = CFFDictionary.integers(privateDictionary, key: 19, count: 1)?.first,
              relative >= 0,
              let index = CFFIndex(data: data, offset: values[1] + relative) else {
            return nil
        }
        return PrivateProgram(localSubroutines: index)
    }

    private static func parseFDSelect(
        data: Data,
        offset: Int,
        glyphCount: Int,
        dictionaryCount: Int
    ) -> [Int]? {
        guard offset >= 0, offset < data.count else { return nil }
        let format = data.readUInt8(at: offset)
        if format == 0 {
            guard glyphCount <= data.count - offset - 1 else { return nil }
            let values = (0..<glyphCount).map { Int(data.readUInt8(at: offset + 1 + $0)) }
            return values.allSatisfy({ $0 < dictionaryCount }) ? values : nil
        }
        guard format == 3, offset <= data.count - 3 else { return nil }
        let rangeCount = Int(data.readUInt16BE(at: offset + 1))
        guard rangeCount > 0, rangeCount <= (data.count - offset - 5) / 3 else { return nil }
        var starts: [(glyph: Int, dictionary: Int)] = []
        for index in 0..<rangeCount {
            let entry = offset + 3 + index * 3
            starts.append((
                glyph: Int(data.readUInt16BE(at: entry)),
                dictionary: Int(data.readUInt8(at: entry + 2))
            ))
        }
        let sentinelOffset = offset + 3 + rangeCount * 3
        let sentinel = Int(data.readUInt16BE(at: sentinelOffset))
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
