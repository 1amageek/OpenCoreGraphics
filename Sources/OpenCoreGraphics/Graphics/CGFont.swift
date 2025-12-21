//
//  CGFont.swift
//  OpenCoreGraphics
//
//  A set of character glyphs and layout information for drawing text.
//


#if arch(wasm32)
import Foundation

// MARK: - CGGlyph Type

/// An index into the internal glyph table of a font.
public typealias CGGlyph = UInt16

/// An index into a font table.
public typealias CGFontIndex = UInt16

/// The maximum allowed value of a CGGlyph.
public let kCGGlyphMax: CGFontIndex = 0xFFFE

/// The maximum allowed value of a CGFontIndex.
public let kCGFontIndexMax: CGFontIndex = 0xFFFE

/// An invalid font index.
public let kCGFontIndexInvalid: CGFontIndex = 0xFFFF

// MARK: - CGFont

/// A set of character glyphs and layout information for drawing text.
public class CGFont: @unchecked Sendable {

    // MARK: - Internal Storage

    /// The raw font data.
    private let fontData: Data?

    /// The internal parser.
    private let parser: SFNTParser?

    /// Cached parsed tables.
    private var cachedHead: HeadTable?
    private var cachedHhea: HheaTable?
    private var cachedMaxp: MaxpTable?
    private var cachedHmtx: HmtxTable?
    private var cachedPost: PostTable?
    private var cachedOS2: OS2Table?
    private var cachedName: NameTable?
    private var cachedLoca: LocaTable?
    private var cachedFvar: FvarTable?
    private var cachedColr: ColrTable?
    private var cachedCpal: CpalTable?

    /// Lock for thread-safe lazy initialization (recursive to allow nested table loading).
    private let cacheLock = NSRecursiveLock()

    /// Current variation coordinates (for variable fonts).
    private var variationCoordinates: [String: CGFloat]?

    // MARK: - Initializers

    /// Creates a font object from data supplied by a data provider.
    public init?(_ provider: CGDataProvider) {
        guard let data = provider.data else { return nil }
        guard let parser = SFNTParser(data: data) else { return nil }

        self.fontData = data
        self.parser = parser
        self.variationCoordinates = nil

        // Pre-parse essential tables
        do {
            self.cachedHead = try parser.parseHeadTable()
            self.cachedMaxp = try parser.parseMaxpTable()
        } catch {
            return nil
        }
    }

    /// Creates a font object corresponding to the font specified by a PostScript or full name.
    /// Note: In WASM environment, system fonts are not available. This initializer
    /// is provided for API compatibility but will return nil.
    public init?(_ name: CFString) {
        // System font lookup is not available in WASM
        // This is provided for API compatibility only
        return nil
    }

    /// Internal initializer for creating variations.
    private init(
        fontData: Data?,
        parser: SFNTParser?,
        cachedHead: HeadTable?,
        cachedHhea: HheaTable?,
        cachedMaxp: MaxpTable?,
        cachedHmtx: HmtxTable?,
        cachedPost: PostTable?,
        cachedOS2: OS2Table?,
        cachedName: NameTable?,
        cachedLoca: LocaTable?,
        cachedFvar: FvarTable?,
        cachedColr: ColrTable?,
        cachedCpal: CpalTable?,
        variationCoordinates: [String: CGFloat]?
    ) {
        self.fontData = fontData
        self.parser = parser
        self.cachedHead = cachedHead
        self.cachedHhea = cachedHhea
        self.cachedMaxp = cachedMaxp
        self.cachedHmtx = cachedHmtx
        self.cachedPost = cachedPost
        self.cachedOS2 = cachedOS2
        self.cachedName = cachedName
        self.cachedLoca = cachedLoca
        self.cachedFvar = cachedFvar
        self.cachedColr = cachedColr
        self.cachedCpal = cachedCpal
        self.variationCoordinates = variationCoordinates
    }

    // MARK: - Lazy Table Loading

    private func getHheaTable() -> HheaTable? {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        if cachedHhea == nil {
            cachedHhea = try? parser?.parseHheaTable()
        }
        return cachedHhea
    }

    private func getHmtxTable() -> HmtxTable? {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        if cachedHmtx == nil {
            guard let hhea = getHheaTable(),
                  let maxp = cachedMaxp else { return nil }
            cachedHmtx = try? parser?.parseHmtxTable(
                numberOfGlyphs: Int(maxp.numGlyphs),
                numberOfHMetrics: Int(hhea.numberOfHMetrics)
            )
        }
        return cachedHmtx
    }

    private func getPostTable() -> PostTable? {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        if cachedPost == nil {
            cachedPost = try? parser?.parsePostTable()
        }
        return cachedPost
    }

    private func getOS2Table() -> OS2Table? {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        if cachedOS2 == nil {
            cachedOS2 = try? parser?.parseOS2Table()
        }
        return cachedOS2
    }

    private func getNameTable() -> NameTable? {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        if cachedName == nil {
            cachedName = try? parser?.parseNameTable()
        }
        return cachedName
    }

    private func getLocaTable() -> LocaTable? {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        if cachedLoca == nil {
            guard let head = cachedHead,
                  let maxp = cachedMaxp else { return nil }
            cachedLoca = try? parser?.parseLocaTable(
                numGlyphs: Int(maxp.numGlyphs),
                indexToLocFormat: head.indexToLocFormat
            )
        }
        return cachedLoca
    }

    private func getFvarTable() -> FvarTable? {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        if cachedFvar == nil {
            cachedFvar = try? parser?.parseFvarTable()
        }
        return cachedFvar
    }

    private func getColrTable() -> ColrTable? {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        if cachedColr == nil {
            cachedColr = try? parser?.parseColrTable()
        }
        return cachedColr
    }

    private func getCpalTable() -> CpalTable? {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        if cachedCpal == nil {
            cachedCpal = try? parser?.parseCpalTable()
        }
        return cachedCpal
    }

    // MARK: - Font Metadata

    /// Returns the full name associated with a font object.
    public var fullName: CFString? {
        getNameTable()?.fullName as CFString?
    }

    /// Obtains the PostScript name of a font.
    public var postScriptName: CFString? {
        getNameTable()?.postScriptName as CFString?
    }

    /// Returns the number of glyphs in a font.
    public var numberOfGlyphs: Int {
        Int(cachedMaxp?.numGlyphs ?? 0)
    }

    /// Returns the number of glyph space units per em for the provided font.
    public var unitsPerEm: Int32 {
        Int32(cachedHead?.unitsPerEm ?? 1000)
    }

    /// Returns the ascent of a font.
    public var ascent: Int32 {
        Int32(getHheaTable()?.ascent ?? 0)
    }

    /// Returns the descent of a font.
    public var descent: Int32 {
        Int32(getHheaTable()?.descent ?? 0)
    }

    /// Returns the leading of a font.
    public var leading: Int32 {
        Int32(getHheaTable()?.lineGap ?? 0)
    }

    /// Returns the cap height of a font.
    public var capHeight: Int32 {
        if let os2 = getOS2Table(), let capHeight = os2.sCapHeight {
            return Int32(capHeight)
        }
        // Fallback: estimate as 70% of ascent
        return ascent * 70 / 100
    }

    /// Returns the x-height of a font.
    public var xHeight: Int32 {
        if let os2 = getOS2Table(), let xHeight = os2.sxHeight {
            return Int32(xHeight)
        }
        // Fallback: estimate as 50% of ascent
        return ascent * 50 / 100
    }

    /// Returns the bounding box of a font.
    public var fontBBox: CGRect {
        cachedHead?.fontBBox ?? .zero
    }

    /// Returns the italic angle of a font.
    public var italicAngle: CGFloat {
        getPostTable()?.italicAngle ?? 0
    }

    /// Returns the thickness of the dominant vertical stems of glyphs in a font.
    public var stemV: CGFloat {
        // stemV is not directly available in TrueType fonts
        // Estimate based on weight class if available
        if let os2 = getOS2Table() {
            // Approximate stemV from weight class
            let weight = CGFloat(os2.usWeightClass)
            return weight / 10.0
        }
        return 80.0
    }

    // MARK: - Font Tables

    /// Returns an array of tags that correspond to the font tables for a font.
    public var tableTags: CFArray? {
        guard let parser = parser else { return nil }
        let tags = parser.tableTags
        return tags as CFArray
    }

    /// Returns the font table that corresponds to the provided tag.
    public func table(for tag: UInt32) -> CFData? {
        guard let data = parser?.tableData(for: tag) else { return nil }
        return data as CFData
    }

    // MARK: - Glyph Metrics

    /// Gets the advance width of each glyph in the provided array.
    public func getGlyphAdvances(
        glyphs: UnsafePointer<CGGlyph>,
        count: Int,
        advances: UnsafeMutablePointer<Int32>
    ) -> Bool {
        guard let hmtx = getHmtxTable() else { return false }

        for i in 0..<count {
            let glyphIndex = Int(glyphs[i])
            advances[i] = Int32(hmtx.advanceWidth(for: glyphIndex))
        }
        return true
    }

    /// Gets the bounding box of each glyph in an array.
    public func getGlyphBBoxes(
        glyphs: UnsafePointer<CGGlyph>,
        count: Int,
        bboxes: UnsafeMutablePointer<CGRect>
    ) -> Bool {
        guard let loca = getLocaTable(),
              let parser = parser else { return false }

        for i in 0..<count {
            let glyphIndex = Int(glyphs[i])

            if let location = loca.glyphLocation(for: glyphIndex),
               location.length > 0,
               let bbox = parser.parseGlyphBBox(glyphOffset: location.offset, glyphLength: location.length) {
                bboxes[i] = bbox.cgRect
            } else {
                // Empty glyph (space, etc.)
                bboxes[i] = .zero
            }
        }
        return true
    }

    // MARK: - Glyph Names

    /// Returns the glyph name of the specified glyph in the specified font.
    public func name(for glyph: CGGlyph) -> CFString? {
        guard let post = getPostTable() else { return nil }
        return post.name(for: Int(glyph)) as CFString?
    }

    /// Returns the glyph for the glyph name associated with the specified font object.
    public func getGlyphWithGlyphName(name: CFString) -> CGGlyph {
        guard let post = getPostTable(),
              let glyphNames = post.glyphNames else {
            return kCGFontIndexInvalid
        }

        let searchName = name as String
        for (index, glyphName) in glyphNames.enumerated() {
            if glyphName == searchName {
                return CGGlyph(index)
            }
        }
        return kCGFontIndexInvalid
    }

    // MARK: - Variations

    /// Returns the variation specification dictionary for a font.
    public var variations: CFDictionary? {
        guard let coords = variationCoordinates else { return nil }
        var result: [CFString: CFNumber] = [:]
        for (key, value) in coords {
            result[key as CFString] = value as CFNumber
        }
        return result as CFDictionary
    }

    /// Returns an array of the variation axis dictionaries for a font.
    public var variationAxes: CFArray? {
        guard let fvar = getFvarTable() else { return nil }

        var axes: [[String: Any]] = []
        let nameTable = getNameTable()

        for axis in fvar.axes {
            var axisDict: [String: Any] = [
                kCGFontVariationAxisMinValue: axis.minValue,
                kCGFontVariationAxisMaxValue: axis.maxValue,
                kCGFontVariationAxisDefaultValue: axis.defaultValue,
                kCGFontVariationAxisName: axis.tagString
            ]

            // Try to get the localized name from the name table
            if let nameTable = nameTable,
               let record = nameTable.records.first(where: { $0.nameID == axis.nameID }) {
                axisDict[kCGFontVariationAxisName] = record.value
            }

            axes.append(axisDict)
        }

        return axes as CFArray
    }

    /// Creates a copy of a font using a variation specification dictionary.
    public func copy(withVariations variations: CFDictionary?) -> CGFont? {
        guard let fvar = getFvarTable(), !fvar.axes.isEmpty else {
            // Not a variable font
            return nil
        }

        var coords: [String: CGFloat] = variationCoordinates ?? [:]

        if let variations = variations as? [String: Any] {
            for (key, value) in variations {
                if let numValue = value as? NSNumber {
                    coords[key] = CGFloat(numValue.doubleValue)
                } else if let cgFloatValue = value as? CGFloat {
                    coords[key] = cgFloatValue
                } else if let doubleValue = value as? Double {
                    coords[key] = CGFloat(doubleValue)
                }
            }
        }

        return CGFont(
            fontData: fontData,
            parser: parser,
            cachedHead: cachedHead,
            cachedHhea: cachedHhea,
            cachedMaxp: cachedMaxp,
            cachedHmtx: cachedHmtx,
            cachedPost: cachedPost,
            cachedOS2: cachedOS2,
            cachedName: cachedName,
            cachedLoca: cachedLoca,
            cachedFvar: cachedFvar,
            cachedColr: cachedColr,
            cachedCpal: cachedCpal,
            variationCoordinates: coords.isEmpty ? nil : coords
        )
    }

    // MARK: - Color Font Support (SF Symbols)

    /// Returns whether this font has color glyph data.
    public var hasColorGlyphs: Bool {
        getColrTable() != nil && getCpalTable() != nil
    }

    /// Returns the color layers for a glyph (COLR table).
    internal func colorLayers(for glyph: CGGlyph) -> [ColrTable.LayerRecord]? {
        getColrTable()?.layers(for: glyph)
    }

    /// Returns a color from the specified palette.
    internal func paletteColor(paletteIndex: Int, colorIndex: Int) -> CGColor? {
        getCpalTable()?.color(paletteIndex: paletteIndex, colorIndex: colorIndex)?.cgColor
    }

    /// Returns the number of color palettes.
    public var numberOfColorPalettes: Int {
        getCpalTable()?.palettes.count ?? 0
    }

    // MARK: - PostScript

    /// Determines whether Core Graphics can create a subset of the font in PostScript format.
    public func canCreatePostScriptSubset(_ format: CGFontPostScriptFormat) -> Bool {
        // PostScript subset creation is not implemented
        return false
    }

    /// Creates a subset of the font in the specified PostScript format.
    public func createPostScriptSubset(
        subsetName: CFString,
        format: CGFontPostScriptFormat,
        glyphs: UnsafePointer<CGGlyph>?,
        count: Int,
        encoding: UnsafePointer<CGGlyph>?
    ) -> CFData? {
        // PostScript subset creation is not implemented
        return nil
    }

    /// Creates a PostScript encoding of a font.
    public func createPostScriptEncoding(encoding: UnsafePointer<CGGlyph>?) -> CFData? {
        // PostScript encoding creation is not implemented
        return nil
    }

    // MARK: - Type ID

    /// Returns the Core Foundation type identifier for Core Graphics fonts.
    public class var typeID: CFTypeID {
        // Return a placeholder type ID
        // In a real implementation, this would return the actual CFTypeID
        return 0
    }
}

// MARK: - Variation Axis Keys

/// Key for the variation axis name.
public let kCGFontVariationAxisName: String = "Name"

/// Key for the variation axis minimum value.
public let kCGFontVariationAxisMinValue: String = "MinValue"

/// Key for the variation axis maximum value.
public let kCGFontVariationAxisMaxValue: String = "MaxValue"

/// Key for the variation axis default value.
public let kCGFontVariationAxisDefaultValue: String = "DefaultValue"

// MARK: - CGFontPostScriptFormat

/// Format of a PostScript font subset.
public enum CGFontPostScriptFormat: Int32, Sendable {
    /// Type 1 format.
    case type1 = 1
    /// Type 3 format.
    case type3 = 3
    /// Type 42 format.
    case type42 = 42
}

// MARK: - Factory Functions

/// Creates a font from a data provider.
public func CGFontCreateWithDataProvider(_ provider: CGDataProvider) -> CGFont? {
    return CGFont(provider)
}

/// Creates a font with the specified name.
public func CGFontCreateWithFontName(_ name: CFString) -> CGFont? {
    return CGFont(name)
}

/// Creates a copy of a font with variations.
public func CGFontCreateCopyWithVariations(_ font: CGFont, _ variations: CFDictionary?) -> CGFont? {
    return font.copy(withVariations: variations)
}

// MARK: - CGContext Font Extension

extension CGContext {

    /// Sets the font for a graphics context.
    public func setFont(_ font: CGFont) {
        // Store font in graphics state
        // Implementation depends on how graphics state is managed
    }

    /// Sets the current font size.
    public func setFontSize(_ size: CGFloat) {
        // Store font size in graphics state
    }

    /// Draws glyphs at the specified positions.
    public func showGlyphs(_ glyphs: [CGGlyph], at positions: [CGPoint]) {
        // Glyph rendering requires CoreText-level functionality
        // This is a placeholder for future OpenCoreText integration
    }
}


#endif
