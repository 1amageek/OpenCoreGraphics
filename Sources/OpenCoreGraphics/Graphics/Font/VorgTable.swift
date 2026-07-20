//
//  VorgTable.swift
//  OpenCoreGraphics
//

import Foundation

/// OpenType vertical origins for CFF and CFF2 glyphs.
internal struct VorgTable: Sendable {
    private let defaultOriginY: Int16
    private let originsByGlyph: [UInt16: Int16]
    private let glyphCount: Int

    init?(data: Data, glyphCount: Int) {
        guard glyphCount > 0, data.count >= 8,
              data.readUInt16BE(at: 0) == 1,
              data.readUInt16BE(at: 2) == 0 else {
            return nil
        }
        let recordCount = Int(data.readUInt16BE(at: 6))
        guard data.count == 8 + recordCount * 4 else { return nil }
        var origins: [UInt16: Int16] = [:]
        origins.reserveCapacity(recordCount)
        var previousGlyph: UInt16?
        for index in 0..<recordCount {
            let offset = 8 + index * 4
            let glyph = data.readUInt16BE(at: offset)
            if let previousGlyph, glyph <= previousGlyph { return nil }
            guard Int(glyph) < glyphCount,
                  origins.updateValue(data.readInt16BE(at: offset + 2), forKey: glyph) == nil else {
                return nil
            }
            previousGlyph = glyph
        }
        self.defaultOriginY = data.readInt16BE(at: 4)
        self.originsByGlyph = origins
        self.glyphCount = glyphCount
    }

    func originY(for glyphIndex: Int) -> Int16? {
        guard (0..<glyphCount).contains(glyphIndex) else { return nil }
        return originsByGlyph[UInt16(glyphIndex)] ?? defaultOriginY
    }
}
