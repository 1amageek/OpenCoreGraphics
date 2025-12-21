//
//  SFNTParser.swift
//  OpenCoreGraphics
//
//  Internal parser for SFNT-based font files (TrueType, OpenType).
//


#if arch(wasm32)
import Foundation

// MARK: - Parser Errors

internal enum FontParserError: Error {
    case invalidData
    case invalidMagicNumber
    case tableNotFound(String)
    case invalidTableFormat(String)
    case unsupportedVersion(String)
}

// MARK: - SFNT Parser

/// Internal parser for SFNT (Spline Font) format files.
/// Supports TrueType (.ttf) and OpenType (.otf with TrueType outlines) fonts.
internal struct SFNTParser: Sendable {

    // MARK: - Table Record

    /// Represents a table record in the font's table directory.
    struct TableRecord: Sendable {
        let tag: UInt32
        let checksum: UInt32
        let offset: UInt32
        let length: UInt32

        var tagString: String {
            FontTableTag.toString(tag)
        }
    }

    // MARK: - Properties

    /// Raw font data.
    let data: Data

    /// Parsed table directory.
    private let tableDirectory: [UInt32: TableRecord]

    /// Number of tables.
    let numTables: UInt16

    // MARK: - Initialization

    init?(data: Data) {
        guard data.count >= 12 else { return nil }

        // Check SFNT version/magic number
        let sfntVersion = data.readUInt32BE(at: 0)

        // Valid values:
        // 0x00010000 - TrueType
        // 0x4F54544F ('OTTO') - OpenType with CFF (not supported)
        // 0x74727565 ('true') - TrueType (Mac)
        // 0x74797031 ('typ1') - Old-style PostScript (not supported)
        guard sfntVersion == 0x00010000 || sfntVersion == 0x74727565 else {
            return nil
        }

        self.data = data
        self.numTables = data.readUInt16BE(at: 4)

        // Parse table directory
        var directory: [UInt32: TableRecord] = [:]
        let tableDirectoryOffset = 12

        for i in 0..<Int(numTables) {
            let recordOffset = tableDirectoryOffset + i * 16
            guard recordOffset + 16 <= data.count else { break }

            let record = TableRecord(
                tag: data.readUInt32BE(at: recordOffset),
                checksum: data.readUInt32BE(at: recordOffset + 4),
                offset: data.readUInt32BE(at: recordOffset + 8),
                length: data.readUInt32BE(at: recordOffset + 12)
            )
            directory[record.tag] = record
        }

        self.tableDirectory = directory
    }

    // MARK: - Table Access

    /// Returns all table tags.
    var tableTags: [UInt32] {
        Array(tableDirectory.keys)
    }

    /// Returns the raw data for a table.
    func tableData(for tag: UInt32) -> Data? {
        guard let record = tableDirectory[tag] else { return nil }
        return data.slice(from: Int(record.offset), length: Int(record.length))
    }

    /// Checks if a table exists.
    func hasTable(_ tag: UInt32) -> Bool {
        tableDirectory[tag] != nil
    }

    // MARK: - Head Table

    func parseHeadTable() throws -> HeadTable {
        guard let tableData = tableData(for: FontTableTag.head) else {
            throw FontParserError.tableNotFound("head")
        }
        guard tableData.count >= 54 else {
            throw FontParserError.invalidTableFormat("head")
        }

        return HeadTable(
            majorVersion: tableData.readUInt16BE(at: 0),
            minorVersion: tableData.readUInt16BE(at: 2),
            fontRevision: tableData.readFixed(at: 4),
            checksumAdjustment: tableData.readUInt32BE(at: 8),
            magicNumber: tableData.readUInt32BE(at: 12),
            flags: tableData.readUInt16BE(at: 16),
            unitsPerEm: tableData.readUInt16BE(at: 18),
            created: tableData.readLongDateTime(at: 20),
            modified: tableData.readLongDateTime(at: 28),
            xMin: tableData.readInt16BE(at: 36),
            yMin: tableData.readInt16BE(at: 38),
            xMax: tableData.readInt16BE(at: 40),
            yMax: tableData.readInt16BE(at: 42),
            macStyle: tableData.readUInt16BE(at: 44),
            lowestRecPPEM: tableData.readUInt16BE(at: 46),
            fontDirectionHint: tableData.readInt16BE(at: 48),
            indexToLocFormat: tableData.readInt16BE(at: 50),
            glyphDataFormat: tableData.readInt16BE(at: 52)
        )
    }

    // MARK: - Hhea Table

    func parseHheaTable() throws -> HheaTable {
        guard let tableData = tableData(for: FontTableTag.hhea) else {
            throw FontParserError.tableNotFound("hhea")
        }
        guard tableData.count >= 36 else {
            throw FontParserError.invalidTableFormat("hhea")
        }

        return HheaTable(
            majorVersion: tableData.readUInt16BE(at: 0),
            minorVersion: tableData.readUInt16BE(at: 2),
            ascent: tableData.readInt16BE(at: 4),
            descent: tableData.readInt16BE(at: 6),
            lineGap: tableData.readInt16BE(at: 8),
            advanceWidthMax: tableData.readUInt16BE(at: 10),
            minLeftSideBearing: tableData.readInt16BE(at: 12),
            minRightSideBearing: tableData.readInt16BE(at: 14),
            xMaxExtent: tableData.readInt16BE(at: 16),
            caretSlopeRise: tableData.readInt16BE(at: 18),
            caretSlopeRun: tableData.readInt16BE(at: 20),
            caretOffset: tableData.readInt16BE(at: 22),
            // 8 bytes reserved (24-31)
            numberOfHMetrics: tableData.readUInt16BE(at: 34)
        )
    }

    // MARK: - Maxp Table

    func parseMaxpTable() throws -> MaxpTable {
        guard let tableData = tableData(for: FontTableTag.maxp) else {
            throw FontParserError.tableNotFound("maxp")
        }
        guard tableData.count >= 6 else {
            throw FontParserError.invalidTableFormat("maxp")
        }

        let version = tableData.readFixed(at: 0)
        let numGlyphs = tableData.readUInt16BE(at: 4)

        // Version 0.5 (CFF) has only 6 bytes
        if version < 1.0 || tableData.count < 32 {
            return MaxpTable(
                version: version,
                numGlyphs: numGlyphs,
                maxPoints: nil,
                maxContours: nil,
                maxCompositePoints: nil,
                maxCompositeContours: nil,
                maxZones: nil,
                maxTwilightPoints: nil,
                maxStorage: nil,
                maxFunctionDefs: nil,
                maxInstructionDefs: nil,
                maxStackElements: nil,
                maxSizeOfInstructions: nil,
                maxComponentElements: nil,
                maxComponentDepth: nil
            )
        }

        // Version 1.0 (TrueType)
        return MaxpTable(
            version: version,
            numGlyphs: numGlyphs,
            maxPoints: tableData.readUInt16BE(at: 6),
            maxContours: tableData.readUInt16BE(at: 8),
            maxCompositePoints: tableData.readUInt16BE(at: 10),
            maxCompositeContours: tableData.readUInt16BE(at: 12),
            maxZones: tableData.readUInt16BE(at: 14),
            maxTwilightPoints: tableData.readUInt16BE(at: 16),
            maxStorage: tableData.readUInt16BE(at: 18),
            maxFunctionDefs: tableData.readUInt16BE(at: 20),
            maxInstructionDefs: tableData.readUInt16BE(at: 22),
            maxStackElements: tableData.readUInt16BE(at: 24),
            maxSizeOfInstructions: tableData.readUInt16BE(at: 26),
            maxComponentElements: tableData.readUInt16BE(at: 28),
            maxComponentDepth: tableData.readUInt16BE(at: 30)
        )
    }

    // MARK: - Hmtx Table

    func parseHmtxTable(numberOfGlyphs: Int, numberOfHMetrics: Int) throws -> HmtxTable {
        guard let tableData = tableData(for: FontTableTag.hmtx) else {
            throw FontParserError.tableNotFound("hmtx")
        }

        var hMetrics: [HmtxTable.LongHorMetric] = []
        hMetrics.reserveCapacity(numberOfHMetrics)

        for i in 0..<numberOfHMetrics {
            let offset = i * 4
            guard offset + 4 <= tableData.count else { break }
            hMetrics.append(HmtxTable.LongHorMetric(
                advanceWidth: tableData.readUInt16BE(at: offset),
                leftSideBearing: tableData.readInt16BE(at: offset + 2)
            ))
        }

        // Remaining glyphs have only left side bearings
        let lsbCount = numberOfGlyphs - numberOfHMetrics
        var leftSideBearings: [Int16] = []

        if lsbCount > 0 {
            leftSideBearings.reserveCapacity(lsbCount)
            let lsbOffset = numberOfHMetrics * 4

            for i in 0..<lsbCount {
                let offset = lsbOffset + i * 2
                guard offset + 2 <= tableData.count else { break }
                leftSideBearings.append(tableData.readInt16BE(at: offset))
            }
        }

        return HmtxTable(hMetrics: hMetrics, leftSideBearings: leftSideBearings)
    }

    // MARK: - Post Table

    func parsePostTable() throws -> PostTable {
        guard let tableData = tableData(for: FontTableTag.post) else {
            throw FontParserError.tableNotFound("post")
        }
        guard tableData.count >= 32 else {
            throw FontParserError.invalidTableFormat("post")
        }

        let version = tableData.readFixed(at: 0)

        let basePost = PostTable(
            version: version,
            italicAngle: tableData.readFixed(at: 4),
            underlinePosition: tableData.readInt16BE(at: 8),
            underlineThickness: tableData.readInt16BE(at: 10),
            isFixedPitch: tableData.readUInt32BE(at: 12),
            minMemType42: tableData.readUInt32BE(at: 16),
            maxMemType42: tableData.readUInt32BE(at: 20),
            minMemType1: tableData.readUInt32BE(at: 24),
            maxMemType1: tableData.readUInt32BE(at: 28),
            glyphNames: nil
        )

        // Version 2.0 has glyph names
        if version >= 2.0 && version < 2.5 && tableData.count >= 34 {
            let numGlyphs = Int(tableData.readUInt16BE(at: 32))
            var glyphNames: [String] = []
            glyphNames.reserveCapacity(numGlyphs)

            // Read glyph name indices
            var glyphNameIndices: [UInt16] = []
            for i in 0..<numGlyphs {
                let offset = 34 + i * 2
                guard offset + 2 <= tableData.count else { break }
                glyphNameIndices.append(tableData.readUInt16BE(at: offset))
            }

            // Read custom glyph names (Pascal strings)
            var customNames: [String] = []
            var offset = 34 + numGlyphs * 2

            while offset < tableData.count {
                let length = Int(tableData.readUInt8(at: offset))
                offset += 1
                guard offset + length <= tableData.count else { break }

                if let nameData = tableData.slice(from: offset, length: length),
                   let name = String(data: nameData, encoding: .ascii) {
                    customNames.append(name)
                }
                offset += length
            }

            // Build glyph names array
            for index in glyphNameIndices {
                if index < 258 {
                    // Standard Macintosh glyph name
                    glyphNames.append(Self.standardMacGlyphName(Int(index)))
                } else {
                    let customIndex = Int(index) - 258
                    if customIndex < customNames.count {
                        glyphNames.append(customNames[customIndex])
                    } else {
                        glyphNames.append("")
                    }
                }
            }

            return PostTable(
                version: version,
                italicAngle: basePost.italicAngle,
                underlinePosition: basePost.underlinePosition,
                underlineThickness: basePost.underlineThickness,
                isFixedPitch: basePost.isFixedPitch,
                minMemType42: basePost.minMemType42,
                maxMemType42: basePost.maxMemType42,
                minMemType1: basePost.minMemType1,
                maxMemType1: basePost.maxMemType1,
                glyphNames: glyphNames
            )
        }

        return basePost
    }

    // MARK: - OS/2 Table

    func parseOS2Table() throws -> OS2Table? {
        guard let tableData = tableData(for: FontTableTag.OS2) else {
            return nil
        }
        guard tableData.count >= 78 else {
            throw FontParserError.invalidTableFormat("OS/2")
        }

        let version = tableData.readUInt16BE(at: 0)

        // Read PANOSE (10 bytes)
        var panose: [UInt8] = []
        for i in 0..<10 {
            panose.append(tableData.readUInt8(at: 32 + i))
        }

        // Read Unicode range (4 UInt32)
        let ulUnicodeRange = [
            tableData.readUInt32BE(at: 42),
            tableData.readUInt32BE(at: 46),
            tableData.readUInt32BE(at: 50),
            tableData.readUInt32BE(at: 54)
        ]

        // Read vendor ID (4 ASCII characters)
        let vendorIDData = tableData.slice(from: 58, length: 4) ?? Data()
        let achVendID = String(data: vendorIDData, encoding: .ascii) ?? ""

        // Base fields (all versions)
        var os2 = OS2Table(
            version: version,
            xAvgCharWidth: tableData.readInt16BE(at: 2),
            usWeightClass: tableData.readUInt16BE(at: 4),
            usWidthClass: tableData.readUInt16BE(at: 6),
            fsType: tableData.readUInt16BE(at: 8),
            ySubscriptXSize: tableData.readInt16BE(at: 10),
            ySubscriptYSize: tableData.readInt16BE(at: 12),
            ySubscriptXOffset: tableData.readInt16BE(at: 14),
            ySubscriptYOffset: tableData.readInt16BE(at: 16),
            ySuperscriptXSize: tableData.readInt16BE(at: 18),
            ySuperscriptYSize: tableData.readInt16BE(at: 20),
            ySuperscriptXOffset: tableData.readInt16BE(at: 22),
            ySuperscriptYOffset: tableData.readInt16BE(at: 24),
            yStrikeoutSize: tableData.readInt16BE(at: 26),
            yStrikeoutPosition: tableData.readInt16BE(at: 28),
            sFamilyClass: tableData.readInt16BE(at: 30),
            panose: panose,
            ulUnicodeRange: ulUnicodeRange,
            achVendID: achVendID,
            fsSelection: tableData.readUInt16BE(at: 62),
            usFirstCharIndex: tableData.readUInt16BE(at: 64),
            usLastCharIndex: tableData.readUInt16BE(at: 66),
            sTypoAscender: tableData.readInt16BE(at: 68),
            sTypoDescender: tableData.readInt16BE(at: 70),
            sTypoLineGap: tableData.readInt16BE(at: 72),
            usWinAscent: tableData.readUInt16BE(at: 74),
            usWinDescent: tableData.readUInt16BE(at: 76),
            ulCodePageRange: nil,
            sxHeight: nil,
            sCapHeight: nil,
            usDefaultChar: nil,
            usBreakChar: nil,
            usMaxContext: nil,
            usLowerOpticalPointSize: nil,
            usUpperOpticalPointSize: nil
        )

        // Version 1+ fields
        if version >= 1 && tableData.count >= 86 {
            let ulCodePageRange = [
                tableData.readUInt32BE(at: 78),
                tableData.readUInt32BE(at: 82)
            ]

            os2 = OS2Table(
                version: os2.version,
                xAvgCharWidth: os2.xAvgCharWidth,
                usWeightClass: os2.usWeightClass,
                usWidthClass: os2.usWidthClass,
                fsType: os2.fsType,
                ySubscriptXSize: os2.ySubscriptXSize,
                ySubscriptYSize: os2.ySubscriptYSize,
                ySubscriptXOffset: os2.ySubscriptXOffset,
                ySubscriptYOffset: os2.ySubscriptYOffset,
                ySuperscriptXSize: os2.ySuperscriptXSize,
                ySuperscriptYSize: os2.ySuperscriptYSize,
                ySuperscriptXOffset: os2.ySuperscriptXOffset,
                ySuperscriptYOffset: os2.ySuperscriptYOffset,
                yStrikeoutSize: os2.yStrikeoutSize,
                yStrikeoutPosition: os2.yStrikeoutPosition,
                sFamilyClass: os2.sFamilyClass,
                panose: os2.panose,
                ulUnicodeRange: os2.ulUnicodeRange,
                achVendID: os2.achVendID,
                fsSelection: os2.fsSelection,
                usFirstCharIndex: os2.usFirstCharIndex,
                usLastCharIndex: os2.usLastCharIndex,
                sTypoAscender: os2.sTypoAscender,
                sTypoDescender: os2.sTypoDescender,
                sTypoLineGap: os2.sTypoLineGap,
                usWinAscent: os2.usWinAscent,
                usWinDescent: os2.usWinDescent,
                ulCodePageRange: ulCodePageRange,
                sxHeight: version >= 2 && tableData.count >= 88 ? tableData.readInt16BE(at: 86) : nil,
                sCapHeight: version >= 2 && tableData.count >= 90 ? tableData.readInt16BE(at: 88) : nil,
                usDefaultChar: version >= 2 && tableData.count >= 92 ? tableData.readUInt16BE(at: 90) : nil,
                usBreakChar: version >= 2 && tableData.count >= 94 ? tableData.readUInt16BE(at: 92) : nil,
                usMaxContext: version >= 2 && tableData.count >= 96 ? tableData.readUInt16BE(at: 94) : nil,
                usLowerOpticalPointSize: version >= 5 && tableData.count >= 98 ? tableData.readUInt16BE(at: 96) : nil,
                usUpperOpticalPointSize: version >= 5 && tableData.count >= 100 ? tableData.readUInt16BE(at: 98) : nil
            )
        }

        return os2
    }

    // MARK: - Name Table

    func parseNameTable() throws -> NameTable? {
        guard let tableData = tableData(for: FontTableTag.name) else {
            return nil
        }
        guard tableData.count >= 6 else {
            throw FontParserError.invalidTableFormat("name")
        }

        let _ = tableData.readUInt16BE(at: 0)  // format (reserved for future use)
        let count = Int(tableData.readUInt16BE(at: 2))
        let storageOffset = Int(tableData.readUInt16BE(at: 4))

        var records: [NameTable.NameRecord] = []

        for i in 0..<count {
            let recordOffset = 6 + i * 12
            guard recordOffset + 12 <= tableData.count else { break }

            let platformID = tableData.readUInt16BE(at: recordOffset)
            let encodingID = tableData.readUInt16BE(at: recordOffset + 2)
            let languageID = tableData.readUInt16BE(at: recordOffset + 4)
            let nameID = tableData.readUInt16BE(at: recordOffset + 6)
            let length = Int(tableData.readUInt16BE(at: recordOffset + 8))
            let offset = Int(tableData.readUInt16BE(at: recordOffset + 10))

            let stringOffset = storageOffset + offset
            guard stringOffset + length <= tableData.count,
                  let stringData = tableData.slice(from: stringOffset, length: length) else {
                continue
            }

            // Decode string based on platform
            let value: String
            if platformID == 0 || platformID == 3 {
                // Unicode or Windows: UTF-16BE
                value = String(data: stringData, encoding: .utf16BigEndian) ?? ""
            } else if platformID == 1 {
                // Macintosh: MacRoman
                value = String(data: stringData, encoding: .macOSRoman) ?? ""
            } else {
                value = String(data: stringData, encoding: .utf8) ?? ""
            }

            records.append(NameTable.NameRecord(
                platformID: platformID,
                encodingID: encodingID,
                languageID: languageID,
                nameID: nameID,
                value: value
            ))
        }

        return NameTable(records: records)
    }

    // MARK: - Loca Table

    func parseLocaTable(numGlyphs: Int, indexToLocFormat: Int16) throws -> LocaTable {
        guard let tableData = tableData(for: FontTableTag.loca) else {
            throw FontParserError.tableNotFound("loca")
        }

        var offsets: [UInt32] = []
        let numEntries = numGlyphs + 1

        if indexToLocFormat == 0 {
            // Short format (2 bytes, actual offset = value * 2)
            offsets.reserveCapacity(numEntries)
            for i in 0..<numEntries {
                let offset = i * 2
                guard offset + 2 <= tableData.count else { break }
                offsets.append(UInt32(tableData.readUInt16BE(at: offset)) * 2)
            }
        } else {
            // Long format (4 bytes)
            offsets.reserveCapacity(numEntries)
            for i in 0..<numEntries {
                let offset = i * 4
                guard offset + 4 <= tableData.count else { break }
                offsets.append(tableData.readUInt32BE(at: offset))
            }
        }

        return LocaTable(offsets: offsets)
    }

    // MARK: - Glyf Table (BBox only)

    func parseGlyphBBox(glyphOffset: Int, glyphLength: Int) -> GlyphBBox? {
        guard glyphLength >= 10,
              let tableData = tableData(for: FontTableTag.glyf) else {
            return nil
        }

        guard glyphOffset + 10 <= tableData.count else { return nil }

        return GlyphBBox(
            xMin: tableData.readInt16BE(at: glyphOffset + 2),
            yMin: tableData.readInt16BE(at: glyphOffset + 4),
            xMax: tableData.readInt16BE(at: glyphOffset + 6),
            yMax: tableData.readInt16BE(at: glyphOffset + 8)
        )
    }

    // MARK: - Fvar Table

    func parseFvarTable() throws -> FvarTable? {
        guard let tableData = tableData(for: FontTableTag.fvar) else {
            return nil
        }
        guard tableData.count >= 16 else {
            throw FontParserError.invalidTableFormat("fvar")
        }

        let _ = tableData.readUInt16BE(at: 0)  // majorVersion
        let _ = tableData.readUInt16BE(at: 2)  // minorVersion
        let axesArrayOffset = Int(tableData.readUInt16BE(at: 4))
        // reserved: 2 bytes at offset 6
        let axisCount = Int(tableData.readUInt16BE(at: 8))
        let axisSize = Int(tableData.readUInt16BE(at: 10))
        let instanceCount = Int(tableData.readUInt16BE(at: 12))
        let instanceSize = Int(tableData.readUInt16BE(at: 14))

        // Parse axes
        var axes: [FvarTable.VariationAxis] = []
        for i in 0..<axisCount {
            let offset = axesArrayOffset + i * axisSize
            guard offset + 20 <= tableData.count else { break }

            axes.append(FvarTable.VariationAxis(
                tag: tableData.readUInt32BE(at: offset),
                minValue: tableData.readFixed(at: offset + 4),
                defaultValue: tableData.readFixed(at: offset + 8),
                maxValue: tableData.readFixed(at: offset + 12),
                flags: tableData.readUInt16BE(at: offset + 16),
                nameID: tableData.readUInt16BE(at: offset + 18)
            ))
        }

        // Parse instances
        var instances: [FvarTable.NamedInstance] = []
        let instancesOffset = axesArrayOffset + axisCount * axisSize

        for i in 0..<instanceCount {
            let offset = instancesOffset + i * instanceSize
            guard offset + 4 + axisCount * 4 <= tableData.count else { break }

            let subfamilyNameID = tableData.readUInt16BE(at: offset)
            let flags = tableData.readUInt16BE(at: offset + 2)

            var coordinates: [CGFloat] = []
            for j in 0..<axisCount {
                coordinates.append(tableData.readFixed(at: offset + 4 + j * 4))
            }

            let postScriptNameID: UInt16?
            if instanceSize >= 4 + axisCount * 4 + 2 {
                postScriptNameID = tableData.readUInt16BE(at: offset + 4 + axisCount * 4)
            } else {
                postScriptNameID = nil
            }

            instances.append(FvarTable.NamedInstance(
                subfamilyNameID: subfamilyNameID,
                flags: flags,
                coordinates: coordinates,
                postScriptNameID: postScriptNameID
            ))
        }

        return FvarTable(axes: axes, instances: instances)
    }

    // MARK: - COLR Table

    func parseColrTable() throws -> ColrTable? {
        guard let tableData = tableData(for: FontTableTag.COLR) else {
            return nil
        }
        guard tableData.count >= 14 else {
            throw FontParserError.invalidTableFormat("COLR")
        }

        let version = tableData.readUInt16BE(at: 0)
        let numBaseGlyphRecords = Int(tableData.readUInt16BE(at: 2))
        let baseGlyphRecordsOffset = Int(tableData.readUInt32BE(at: 4))
        let layerRecordsOffset = Int(tableData.readUInt32BE(at: 8))
        let numLayerRecords = Int(tableData.readUInt16BE(at: 12))

        // Parse base glyph records
        var baseGlyphRecords: [ColrTable.BaseGlyphRecord] = []
        for i in 0..<numBaseGlyphRecords {
            let offset = baseGlyphRecordsOffset + i * 6
            guard offset + 6 <= tableData.count else { break }

            baseGlyphRecords.append(ColrTable.BaseGlyphRecord(
                glyphID: tableData.readUInt16BE(at: offset),
                firstLayerIndex: tableData.readUInt16BE(at: offset + 2),
                numLayers: tableData.readUInt16BE(at: offset + 4)
            ))
        }

        // Parse layer records
        var layerRecords: [ColrTable.LayerRecord] = []
        for i in 0..<numLayerRecords {
            let offset = layerRecordsOffset + i * 4
            guard offset + 4 <= tableData.count else { break }

            layerRecords.append(ColrTable.LayerRecord(
                glyphID: tableData.readUInt16BE(at: offset),
                paletteIndex: tableData.readUInt16BE(at: offset + 2)
            ))
        }

        return ColrTable(
            version: version,
            baseGlyphRecords: baseGlyphRecords,
            layerRecords: layerRecords
        )
    }

    // MARK: - CPAL Table

    func parseCpalTable() throws -> CpalTable? {
        guard let tableData = tableData(for: FontTableTag.CPAL) else {
            return nil
        }
        guard tableData.count >= 12 else {
            throw FontParserError.invalidTableFormat("CPAL")
        }

        let version = tableData.readUInt16BE(at: 0)
        let numPaletteEntries = tableData.readUInt16BE(at: 2)
        let numPalettes = Int(tableData.readUInt16BE(at: 4))
        let numColorRecords = Int(tableData.readUInt16BE(at: 6))
        let colorRecordsArrayOffset = Int(tableData.readUInt32BE(at: 8))

        // Read palette offsets (index into color records)
        var paletteOffsets: [UInt16] = []
        for i in 0..<numPalettes {
            let offset = 12 + i * 2
            guard offset + 2 <= tableData.count else { break }
            paletteOffsets.append(tableData.readUInt16BE(at: offset))
        }

        // Read color records
        var colorRecords: [CpalTable.ColorRecord] = []
        for i in 0..<numColorRecords {
            let offset = colorRecordsArrayOffset + i * 4
            guard offset + 4 <= tableData.count else { break }

            colorRecords.append(CpalTable.ColorRecord(
                blue: tableData.readUInt8(at: offset),
                green: tableData.readUInt8(at: offset + 1),
                red: tableData.readUInt8(at: offset + 2),
                alpha: tableData.readUInt8(at: offset + 3)
            ))
        }

        // Build palettes
        var palettes: [[CpalTable.ColorRecord]] = []
        for paletteOffset in paletteOffsets {
            let startIndex = Int(paletteOffset)
            let endIndex = startIndex + Int(numPaletteEntries)
            guard endIndex <= colorRecords.count else { continue }
            palettes.append(Array(colorRecords[startIndex..<endIndex]))
        }

        return CpalTable(
            version: version,
            numPaletteEntries: numPaletteEntries,
            palettes: palettes
        )
    }

    // MARK: - Standard Mac Glyph Names

    private static func standardMacGlyphName(_ index: Int) -> String {
        // Standard Macintosh glyph names (first 258 from Adobe)
        let standardNames = [
            ".notdef", ".null", "nonmarkingreturn", "space", "exclam", "quotedbl", "numbersign",
            "dollar", "percent", "ampersand", "quotesingle", "parenleft", "parenright", "asterisk",
            "plus", "comma", "hyphen", "period", "slash", "zero", "one", "two", "three", "four",
            "five", "six", "seven", "eight", "nine", "colon", "semicolon", "less", "equal",
            "greater", "question", "at", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K",
            "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
            "bracketleft", "backslash", "bracketright", "asciicircum", "underscore", "grave",
            "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q",
            "r", "s", "t", "u", "v", "w", "x", "y", "z", "braceleft", "bar", "braceright",
            "asciitilde", "Adieresis", "Aring", "Ccedilla", "Eacute", "Ntilde", "Odieresis",
            "Udieresis", "aacute", "agrave", "acircumflex", "adieresis", "atilde", "aring",
            "ccedilla", "eacute", "egrave", "ecircumflex", "edieresis", "iacute", "igrave",
            "icircumflex", "idieresis", "ntilde", "oacute", "ograve", "ocircumflex", "odieresis",
            "otilde", "uacute", "ugrave", "ucircumflex", "udieresis", "dagger", "degree", "cent",
            "sterling", "section", "bullet", "paragraph", "germandbls", "registered", "copyright",
            "trademark", "acute", "dieresis", "notequal", "AE", "Oslash", "infinity", "plusminus",
            "lessequal", "greaterequal", "yen", "mu", "partialdiff", "summation", "product", "pi",
            "integral", "ordfeminine", "ordmasculine", "Omega", "ae", "oslash", "questiondown",
            "exclamdown", "logicalnot", "radical", "florin", "approxequal", "Delta", "guillemotleft",
            "guillemotright", "ellipsis", "nonbreakingspace", "Agrave", "Atilde", "Otilde", "OE",
            "oe", "endash", "emdash", "quotedblleft", "quotedblright", "quoteleft", "quoteright",
            "divide", "lozenge", "ydieresis", "Ydieresis", "fraction", "currency", "guilsinglleft",
            "guilsinglright", "fi", "fl", "daggerdbl", "periodcentered", "quotesinglbase",
            "quotedblbase", "perthousand", "Acircumflex", "Ecircumflex", "Aacute", "Edieresis",
            "Egrave", "Iacute", "Icircumflex", "Idieresis", "Igrave", "Oacute", "Ocircumflex",
            "apple", "Ograve", "Uacute", "Ucircumflex", "Ugrave", "dotlessi", "circumflex", "tilde",
            "macron", "breve", "dotaccent", "ring", "cedilla", "hungarumlaut", "ogonek", "caron",
            "Lslash", "lslash", "Scaron", "scaron", "Zcaron", "zcaron", "brokenbar", "Eth", "eth",
            "Yacute", "yacute", "Thorn", "thorn", "minus", "multiply", "onesuperior", "twosuperior",
            "threesuperior", "onehalf", "onequarter", "threequarters", "franc", "Gbreve", "gbreve",
            "Idotaccent", "Scedilla", "scedilla", "Cacute", "cacute", "Ccaron", "ccaron", "dcroat"
        ]

        if index >= 0 && index < standardNames.count {
            return standardNames[index]
        }
        return ""
    }
}


#endif
