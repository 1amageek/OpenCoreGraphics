//
//  FontTables.swift
//  OpenCoreGraphics
//
//  Internal structures representing parsed font tables.
//

import Foundation

// MARK: - Head Table

/// The 'head' table contains global information about the font.
internal struct HeadTable: Sendable {
    /// Major version (usually 1).
    let majorVersion: UInt16
    /// Minor version (usually 0).
    let minorVersion: UInt16
    /// Font revision.
    let fontRevision: CGFloat
    /// Checksum adjustment.
    let checksumAdjustment: UInt32
    /// Magic number (0x5F0F3CF5).
    let magicNumber: UInt32
    /// Font flags.
    let flags: UInt16
    /// Units per em (typically 1000 or 2048).
    let unitsPerEm: UInt16
    /// Date created.
    let created: Date
    /// Date modified.
    let modified: Date
    /// Minimum x coordinate across all glyph bounding boxes.
    let xMin: Int16
    /// Minimum y coordinate across all glyph bounding boxes.
    let yMin: Int16
    /// Maximum x coordinate across all glyph bounding boxes.
    let xMax: Int16
    /// Maximum y coordinate across all glyph bounding boxes.
    let yMax: Int16
    /// Mac style flags.
    let macStyle: UInt16
    /// Smallest readable size in pixels.
    let lowestRecPPEM: UInt16
    /// Font direction hint (deprecated).
    let fontDirectionHint: Int16
    /// Index to loc format: 0 = short offsets, 1 = long offsets.
    let indexToLocFormat: Int16
    /// Glyph data format.
    let glyphDataFormat: Int16

    /// Font bounding box.
    var fontBBox: CGRect {
        CGRect(
            x: CGFloat(xMin),
            y: CGFloat(yMin),
            width: CGFloat(Int32(xMax) - Int32(xMin)),
            height: CGFloat(Int32(yMax) - Int32(yMin))
        )
    }
}

// MARK: - Hhea Table

/// The 'hhea' table contains information needed for horizontal layout.
internal struct HheaTable: Sendable {
    /// Major version (usually 1).
    let majorVersion: UInt16
    /// Minor version (usually 0).
    let minorVersion: UInt16
    /// Typographic ascent.
    let ascent: Int16
    /// Typographic descent (typically negative).
    let descent: Int16
    /// Line gap.
    let lineGap: Int16
    /// Maximum advance width.
    let advanceWidthMax: UInt16
    /// Minimum left side bearing.
    let minLeftSideBearing: Int16
    /// Minimum right side bearing.
    let minRightSideBearing: Int16
    /// Maximum x extent.
    let xMaxExtent: Int16
    /// Caret slope rise.
    let caretSlopeRise: Int16
    /// Caret slope run.
    let caretSlopeRun: Int16
    /// Caret offset.
    let caretOffset: Int16
    /// Number of hMetric entries in hmtx table.
    let numberOfHMetrics: UInt16
}

// MARK: - Maxp Table

/// The 'maxp' table contains the maximum profile of the font.
internal struct MaxpTable: Sendable {
    /// Version (0.5 or 1.0).
    let version: CGFloat
    /// Number of glyphs in the font.
    let numGlyphs: UInt16

    // Version 1.0 fields (TrueType outlines only)
    let maxPoints: UInt16?
    let maxContours: UInt16?
    let maxCompositePoints: UInt16?
    let maxCompositeContours: UInt16?
    let maxZones: UInt16?
    let maxTwilightPoints: UInt16?
    let maxStorage: UInt16?
    let maxFunctionDefs: UInt16?
    let maxInstructionDefs: UInt16?
    let maxStackElements: UInt16?
    let maxSizeOfInstructions: UInt16?
    let maxComponentElements: UInt16?
    let maxComponentDepth: UInt16?
}

// MARK: - Hmtx Table

/// The 'hmtx' table contains horizontal metrics for glyphs.
internal struct HmtxTable: Sendable {
    /// Long horizontal metric entry.
    struct LongHorMetric: Sendable {
        /// Advance width in font design units.
        let advanceWidth: UInt16
        /// Left side bearing in font design units.
        let leftSideBearing: Int16
    }

    /// Array of long horizontal metrics (numberOfHMetrics entries).
    let hMetrics: [LongHorMetric]
    /// Array of left side bearings for remaining glyphs.
    let leftSideBearings: [Int16]

    /// Gets the advance width for a glyph.
    func advanceWidth(for glyphIndex: Int) -> UInt16 {
        if glyphIndex < hMetrics.count {
            return hMetrics[glyphIndex].advanceWidth
        } else if !hMetrics.isEmpty {
            // Glyphs beyond numberOfHMetrics use the last advance width
            return hMetrics[hMetrics.count - 1].advanceWidth
        }
        return 0
    }

    /// Gets the left side bearing for a glyph.
    func leftSideBearing(for glyphIndex: Int) -> Int16 {
        if glyphIndex < hMetrics.count {
            return hMetrics[glyphIndex].leftSideBearing
        } else {
            let lsbIndex = glyphIndex - hMetrics.count
            if lsbIndex < leftSideBearings.count {
                return leftSideBearings[lsbIndex]
            }
        }
        return 0
    }
}

// MARK: - Post Table

/// The 'post' table contains information for PostScript printers.
internal struct PostTable: Sendable {
    /// Format version (1.0, 2.0, 2.5, 3.0, 4.0).
    let version: CGFloat
    /// Italic angle in degrees (counter-clockwise from vertical).
    let italicAngle: CGFloat
    /// Suggested underline position.
    let underlinePosition: Int16
    /// Suggested underline thickness.
    let underlineThickness: Int16
    /// Is the font monospaced (0 = proportional, non-zero = monospaced).
    let isFixedPitch: UInt32
    /// Minimum memory usage when downloading.
    let minMemType42: UInt32
    /// Maximum memory usage when downloading.
    let maxMemType42: UInt32
    /// Minimum memory usage when downloading as Type 1.
    let minMemType1: UInt32
    /// Maximum memory usage when downloading as Type 1.
    let maxMemType1: UInt32

    /// Glyph names (for format 2.0 only).
    let glyphNames: [String]?

    /// Gets the name for a glyph index.
    func name(for glyphIndex: Int) -> String? {
        guard let names = glyphNames, glyphIndex < names.count else {
            return nil
        }
        return names[glyphIndex]
    }
}

// MARK: - OS/2 Table

/// The 'OS/2' table contains metrics required for Windows.
internal struct OS2Table: Sendable {
    /// Table version.
    let version: UInt16
    /// Average character width.
    let xAvgCharWidth: Int16
    /// Weight class (100-900).
    let usWeightClass: UInt16
    /// Width class (1-9).
    let usWidthClass: UInt16
    /// Font embedding licensing rights.
    let fsType: UInt16
    /// Subscript horizontal size.
    let ySubscriptXSize: Int16
    /// Subscript vertical size.
    let ySubscriptYSize: Int16
    /// Subscript x offset.
    let ySubscriptXOffset: Int16
    /// Subscript y offset.
    let ySubscriptYOffset: Int16
    /// Superscript horizontal size.
    let ySuperscriptXSize: Int16
    /// Superscript vertical size.
    let ySuperscriptYSize: Int16
    /// Superscript x offset.
    let ySuperscriptXOffset: Int16
    /// Superscript y offset.
    let ySuperscriptYOffset: Int16
    /// Strikeout stroke thickness.
    let yStrikeoutSize: Int16
    /// Strikeout stroke position.
    let yStrikeoutPosition: Int16
    /// Font family class and subclass.
    let sFamilyClass: Int16
    /// PANOSE classification (10 bytes).
    let panose: [UInt8]
    /// Unicode character range (4 UInt32).
    let ulUnicodeRange: [UInt32]
    /// Font vendor identification.
    let achVendID: String
    /// Font selection flags.
    let fsSelection: UInt16
    /// Minimum Unicode index.
    let usFirstCharIndex: UInt16
    /// Maximum Unicode index.
    let usLastCharIndex: UInt16
    /// Typographic ascender.
    let sTypoAscender: Int16
    /// Typographic descender.
    let sTypoDescender: Int16
    /// Typographic line gap.
    let sTypoLineGap: Int16
    /// Windows ascender.
    let usWinAscent: UInt16
    /// Windows descender.
    let usWinDescent: UInt16

    // Version 1+ fields
    /// Code page ranges.
    let ulCodePageRange: [UInt32]?

    // Version 2+ fields
    /// x-height.
    let sxHeight: Int16?
    /// Cap height.
    let sCapHeight: Int16?
    /// Default character.
    let usDefaultChar: UInt16?
    /// Break character.
    let usBreakChar: UInt16?
    /// Maximum context.
    let usMaxContext: UInt16?

    // Version 5+ fields
    /// Lower optical point size.
    let usLowerOpticalPointSize: UInt16?
    /// Upper optical point size.
    let usUpperOpticalPointSize: UInt16?
}

// MARK: - Name Table

/// The 'name' table contains human-readable names for the font.
internal struct NameTable: Sendable {
    /// Name record.
    struct NameRecord: Sendable {
        let platformID: UInt16
        let encodingID: UInt16
        let languageID: UInt16
        let nameID: UInt16
        let value: String
    }

    /// Name IDs.
    enum NameID: UInt16 {
        case copyright = 0
        case fontFamily = 1
        case fontSubfamily = 2
        case uniqueID = 3
        case fullName = 4
        case version = 5
        case postScriptName = 6
        case trademark = 7
        case manufacturer = 8
        case designer = 9
        case description = 10
        case vendorURL = 11
        case designerURL = 12
        case license = 13
        case licenseURL = 14
        case typographicFamily = 16
        case typographicSubfamily = 17
        case compatibleFull = 18
        case sampleText = 19
        case postScriptCID = 20
        case wwsFamily = 21
        case wwsSubfamily = 22
        case lightBackgroundPalette = 23
        case darkBackgroundPalette = 24
        case variationsPostScriptPrefix = 25
    }

    /// All name records.
    let records: [NameRecord]

    /// Gets the first matching name for the given name ID.
    func name(for nameID: NameID, preferredPlatformID: UInt16? = nil) -> String? {
        // Prefer specified platform, then Unicode (0), then Windows (3), then Mac (1)
        let priorityPlatforms: [UInt16]
        if let preferred = preferredPlatformID {
            priorityPlatforms = [preferred, 0, 3, 1]
        } else {
            priorityPlatforms = [0, 3, 1]
        }

        for platformID in priorityPlatforms {
            if let record = records.first(where: { $0.nameID == nameID.rawValue && $0.platformID == platformID }) {
                return record.value
            }
        }

        // Fallback to any matching record
        return records.first(where: { $0.nameID == nameID.rawValue })?.value
    }

    var fullName: String? { name(for: .fullName) }
    var postScriptName: String? { name(for: .postScriptName) }
    var fontFamily: String? { name(for: .fontFamily) }
}

// MARK: - Loca Table

/// The 'loca' table stores offsets to glyph data in the 'glyf' table.
internal struct LocaTable: Sendable {
    /// Glyph offsets (numGlyphs + 1 entries).
    let offsets: [UInt32]

    /// Gets the offset and length for a glyph.
    func glyphLocation(for glyphIndex: Int) -> (offset: Int, length: Int)? {
        guard glyphIndex >= 0 && glyphIndex + 1 < offsets.count else {
            return nil
        }
        let offset = Int(offsets[glyphIndex])
        let nextOffset = Int(offsets[glyphIndex + 1])
        return (offset, nextOffset - offset)
    }
}

// MARK: - Glyf Table (Partial - for BBox only)

/// Glyph bounding box from the 'glyf' table.
internal struct GlyphBBox: Sendable {
    let xMin: Int16
    let yMin: Int16
    let xMax: Int16
    let yMax: Int16

    var cgRect: CGRect {
        CGRect(
            x: CGFloat(xMin),
            y: CGFloat(yMin),
            width: CGFloat(Int32(xMax) - Int32(xMin)),
            height: CGFloat(Int32(yMax) - Int32(yMin))
        )
    }
}

// MARK: - Fvar Table (Variable Fonts)

/// The 'fvar' table contains information about variation axes.
internal struct FvarTable: Sendable {
    /// Variation axis record.
    struct VariationAxis: Sendable {
        /// Axis tag (e.g., 'wght', 'wdth', 'ital').
        let tag: UInt32
        /// Minimum value for the axis.
        let minValue: CGFloat
        /// Default value for the axis.
        let defaultValue: CGFloat
        /// Maximum value for the axis.
        let maxValue: CGFloat
        /// Axis flags.
        let flags: UInt16
        /// Name ID for the axis name.
        let nameID: UInt16

        /// Tag as a string.
        var tagString: String {
            FontTableTag.toString(tag)
        }
    }

    /// Named instance record.
    struct NamedInstance: Sendable {
        /// Subfamily name ID.
        let subfamilyNameID: UInt16
        /// Instance flags.
        let flags: UInt16
        /// Coordinates for each axis.
        let coordinates: [CGFloat]
        /// PostScript name ID (optional).
        let postScriptNameID: UInt16?
    }

    /// Variation axes.
    let axes: [VariationAxis]
    /// Named instances.
    let instances: [NamedInstance]
}

// MARK: - Gvar Table (Glyph Variations)

/// The 'gvar' table contains glyph variation data.
internal struct GvarTable: Sendable {
    /// Glyph variation data offsets.
    let glyphVariationDataOffsets: [UInt32]
    /// Shared tuple coordinates (each tuple is an array of normalized coordinates).
    let sharedTuples: [[CGFloat]]
    /// Raw data for lazy parsing of individual glyph variations.
    let data: Data
}

// MARK: - COLR Table (Color Layers)

/// The 'COLR' table defines color layers for glyphs.
internal struct ColrTable: Sendable {
    /// Layer record.
    struct LayerRecord: Sendable {
        /// Glyph ID of the layer.
        let glyphID: UInt16
        /// Index into CPAL palette.
        let paletteIndex: UInt16
    }

    /// Base glyph record.
    struct BaseGlyphRecord: Sendable {
        /// Glyph ID of the base glyph.
        let glyphID: UInt16
        /// Index of the first layer.
        let firstLayerIndex: UInt16
        /// Number of layers.
        let numLayers: UInt16
    }

    /// Table version.
    let version: UInt16
    /// Base glyph records (sorted by glyph ID).
    let baseGlyphRecords: [BaseGlyphRecord]
    /// Layer records.
    let layerRecords: [LayerRecord]

    /// Gets the layers for a glyph.
    func layers(for glyphID: UInt16) -> [LayerRecord]? {
        guard let baseGlyph = baseGlyphRecords.first(where: { $0.glyphID == glyphID }) else {
            return nil
        }
        let startIndex = Int(baseGlyph.firstLayerIndex)
        let endIndex = startIndex + Int(baseGlyph.numLayers)
        guard startIndex >= 0 && endIndex <= layerRecords.count else {
            return nil
        }
        return Array(layerRecords[startIndex..<endIndex])
    }
}

// MARK: - CPAL Table (Color Palettes)

/// The 'CPAL' table defines color palettes.
internal struct CpalTable: Sendable {
    /// Color record (BGRA format).
    struct ColorRecord: Sendable {
        let blue: UInt8
        let green: UInt8
        let red: UInt8
        let alpha: UInt8

        /// Converts to CGColor.
        var cgColor: CGColor {
            CGColor(
                red: CGFloat(red) / 255.0,
                green: CGFloat(green) / 255.0,
                blue: CGFloat(blue) / 255.0,
                alpha: CGFloat(alpha) / 255.0
            )
        }
    }

    /// Table version.
    let version: UInt16
    /// Number of palette entries (colors per palette).
    let numPaletteEntries: UInt16
    /// All palettes.
    let palettes: [[ColorRecord]]

    /// Gets a color from a palette.
    func color(paletteIndex: Int, colorIndex: Int) -> ColorRecord? {
        guard paletteIndex < palettes.count else { return nil }
        let palette = palettes[paletteIndex]
        guard colorIndex < palette.count else { return nil }
        return palette[colorIndex]
    }
}
