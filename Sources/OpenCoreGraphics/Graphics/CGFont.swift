//
//  CGFont.swift
//  OpenCoreGraphics
//
//  A set of character glyphs and layout information for drawing text.
//


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
public class CGFont {

    // MARK: - Internal Storage

    /// The raw font data.
    private let fontData: Data?

    /// The internal parser.
    private let parser: SFNTParser?

    /// A parsed Adobe Type 1 font program for PFA/PFB input.
    private let type1Program: Type1FontProgram?

    private struct ParsedTables {
        var head: HeadTable?
        var hhea: HheaTable?
        var maxp: MaxpTable?
        var hmtx: HmtxTable?
        var vhea: VheaTable?
        var vmtx: VmtxTable?
        var vorg: VorgTable?
        var post: PostTable?
        var os2: OS2Table?
        var name: NameTable?
        var loca: LocaTable?
        var fvar: FvarTable?
        var avar: AvarTable?
        var hvar: HvarTable?
        var vvar: VvarTable?
        var gvar: GvarTable?
        var colr: ColrTable?
        var cpal: CpalTable?
        var cff: CFFFontProgram?
        var cff2: CFF2FontProgram?
    }

    /// All font tables are parsed before publication so a font has immutable state.
    private let tables: ParsedTables

    /// Current variation coordinates (for variable fonts).
    private let variationCoordinates: [String: CGFloat]?

    // MARK: - Initializers

    /// Creates a font object from data supplied by a data provider.
    public init?(_ provider: CGDataProvider) {
        guard let data = provider.data else { return nil }

        guard let parser = SFNTParser(data: data) else {
            guard let type1Program = Type1FontProgram(data: data) else { return nil }
            self.fontData = data
            self.parser = nil
            self.type1Program = type1Program
            self.tables = ParsedTables()
            self.variationCoordinates = nil
            return
        }

        self.fontData = data
        self.parser = parser
        self.type1Program = nil
        self.variationCoordinates = nil
        var tables = ParsedTables()

        // Pre-parse essential tables
        do {
            tables.head = try parser.parseHeadTable()
            tables.maxp = try parser.parseMaxpTable()
        } catch {
            return nil
        }
        let glyphCount = Int(tables.maxp?.numGlyphs ?? 0)
        let hasVerticalHeader = parser.hasTable(FontTableTag.vhea)
        let hasVerticalMetrics = parser.hasTable(FontTableTag.vmtx)
        guard hasVerticalHeader == hasVerticalMetrics else { return nil }
        if hasVerticalHeader {
            do {
                let vhea = try parser.parseVheaTable()
                tables.vhea = vhea
                tables.vmtx = try parser.parseVmtxTable(
                    numberOfGlyphs: glyphCount,
                    numberOfVMetrics: Int(vhea.numberOfVMetrics)
                )
            } catch {
                return nil
            }
        }
        if parser.hasTable(FontTableTag.VORG)
            && (parser.hasTable(FontTableTag.CFF) || parser.hasTable(FontTableTag.CFF2)) {
            guard tables.vmtx != nil else { return nil }
            do {
                guard let vorg = try parser.parseVorgTable(glyphCount: glyphCount) else { return nil }
                tables.vorg = vorg
            } catch {
                return nil
            }
        }
        if parser.hasTable(FontTableTag.fvar) {
            do {
                guard let fvar = try parser.parseFvarTable() else { return nil }
                tables.fvar = fvar
                tables.avar = try parser.parseAvarTable(axisCount: fvar.axes.count)
                if parser.hasTable(FontTableTag.HVAR) || parser.hasTable(FontTableTag.gvar) {
                    let hhea = try parser.parseHheaTable()
                    tables.hhea = hhea
                    tables.hmtx = try parser.parseHmtxTable(
                        numberOfGlyphs: glyphCount,
                        numberOfHMetrics: Int(hhea.numberOfHMetrics)
                    )
                }
                if parser.hasTable(FontTableTag.HVAR) {
                    guard let hvar = try parser.parseHvarTable(
                        axisCount: fvar.axes.count,
                        glyphCount: glyphCount
                    ) else {
                        return nil
                    }
                    tables.hvar = hvar
                }
                if parser.hasTable(FontTableTag.VVAR) {
                    guard tables.vmtx != nil else { return nil }
                    guard let vvar = try parser.parseVvarTable(
                        axisCount: fvar.axes.count,
                        glyphCount: glyphCount
                    ) else {
                        return nil
                    }
                    tables.vvar = vvar
                }
                if parser.hasTable(FontTableTag.gvar) {
                    guard parser.hasTable(FontTableTag.glyf),
                          let gvar = try parser.parseGvarTable(
                            axisCount: fvar.axes.count,
                            glyphCount: glyphCount
                          ) else {
                        return nil
                    }
                    tables.gvar = gvar
                }
            } catch {
                return nil
            }
        } else if parser.hasTable(FontTableTag.avar)
                    || parser.hasTable(FontTableTag.HVAR)
                    || parser.hasTable(FontTableTag.VVAR)
                    || parser.hasTable(FontTableTag.gvar) {
            return nil
        }
        if parser.hasTable(FontTableTag.CFF) {
            guard !parser.hasTable(FontTableTag.CFF2),
                  let cff = parser.parseCFFFontProgram(),
                  cff.charStrings.ranges.count == Int(tables.maxp?.numGlyphs ?? 0) else {
                return nil
            }
            tables.cff = cff
        } else if parser.hasTable(FontTableTag.CFF2) {
            let axisCount = tables.fvar?.axes.count ?? 0
            guard let cff2 = parser.parseCFF2FontProgram(
                axisCount: axisCount,
                unitsPerEm: Int(tables.head?.unitsPerEm ?? 0)
            ), cff2.charStrings.ranges.count == Int(tables.maxp?.numGlyphs ?? 0) else {
                return nil
            }
            tables.cff2 = cff2
        }

        do {
            if tables.hhea == nil, parser.hasTable(FontTableTag.hhea) {
                tables.hhea = try parser.parseHheaTable()
            }
            if tables.hmtx == nil,
               let hhea = tables.hhea,
               parser.hasTable(FontTableTag.hmtx) {
                tables.hmtx = try parser.parseHmtxTable(
                    numberOfGlyphs: glyphCount,
                    numberOfHMetrics: Int(hhea.numberOfHMetrics)
                )
            }
            if parser.hasTable(FontTableTag.post) {
                tables.post = try parser.parsePostTable()
            }
            if parser.hasTable(FontTableTag.OS2) {
                tables.os2 = try parser.parseOS2Table()
            }
            if parser.hasTable(FontTableTag.name) {
                tables.name = try parser.parseNameTable()
            }
            if let head = tables.head,
               parser.hasTable(FontTableTag.loca) {
                tables.loca = try parser.parseLocaTable(
                    numGlyphs: glyphCount,
                    indexToLocFormat: head.indexToLocFormat
                )
            }
            if parser.hasTable(FontTableTag.COLR) {
                tables.colr = try parser.parseColrTable()
            }
            if parser.hasTable(FontTableTag.CPAL) {
                tables.cpal = try parser.parseCpalTable()
            }
        } catch {
            return nil
        }
        self.tables = tables
    }

    /// Creates a font object corresponding to the font specified by a PostScript or full name.
    /// Note: In WASM environment, system fonts are not available. This initializer
    /// is provided for API compatibility but will return nil.
    public init?(_ name: String) {
        // System font lookup is not available in WASM
        // This is provided for API compatibility only
        return nil
    }

    /// Internal initializer for creating variations.
    private init(
        fontData: Data?,
        parser: SFNTParser?,
        tables: ParsedTables,
        type1Program: Type1FontProgram?,
        variationCoordinates: [String: CGFloat]?
    ) {
        self.fontData = fontData
        self.parser = parser
        self.tables = tables
        self.type1Program = type1Program
        self.variationCoordinates = variationCoordinates
    }

    // MARK: - Lazy Table Loading

    private func getHheaTable() -> HheaTable? {
        tables.hhea
    }

    private func getHmtxTable() -> HmtxTable? {
        tables.hmtx
    }

    private func getPostTable() -> PostTable? {
        tables.post
    }

    private func getOS2Table() -> OS2Table? {
        tables.os2
    }

    private func getNameTable() -> NameTable? {
        tables.name
    }

    private func getLocaTable() -> LocaTable? {
        tables.loca
    }

    private func getFvarTable() -> FvarTable? {
        tables.fvar
    }

    private func getAvarTable() -> AvarTable? {
        tables.avar
    }

    private func getColrTable() -> ColrTable? {
        tables.colr
    }

    private func getCpalTable() -> CpalTable? {
        tables.cpal
    }

    private func getCFFProgram() -> CFFFontProgram? {
        tables.cff
    }

    private func getCFF2Program() -> CFF2FontProgram? {
        tables.cff2
    }

    // MARK: - Font Metadata

    /// Returns the full name associated with a font object.
    public var fullName: String? {
        if let type1Program { return type1Program.fullName }
        return getNameTable()?.fullName
    }

    /// Obtains the PostScript name of a font.
    public var postScriptName: String? {
        if let type1Program { return type1Program.postScriptName }
        return getNameTable()?.postScriptName
    }

    /// Returns the number of glyphs in a font.
    public var numberOfGlyphs: Int {
        if let type1Program { return type1Program.glyphs.count }
        return Int(tables.maxp?.numGlyphs ?? 0)
    }

    /// Returns the number of glyph space units per em for the provided font.
    public var unitsPerEm: Int32 {
        if let type1Program { return Int32(type1Program.unitsPerEm) }
        return Int32(tables.head?.unitsPerEm ?? 1000)
    }

    /// Returns the ascent of a font.
    public var ascent: Int32 {
        if let type1Program { return Self.integerMetric(type1Program.metricsBBox.maxY) ?? 0 }
        return Int32(getHheaTable()?.ascent ?? 0)
    }

    /// Returns the descent of a font.
    public var descent: Int32 {
        if let type1Program { return Self.integerMetric(type1Program.metricsBBox.minY) ?? 0 }
        return Int32(getHheaTable()?.descent ?? 0)
    }

    /// Returns the leading of a font.
    public var leading: Int32 {
        if type1Program != nil { return 0 }
        return Int32(getHheaTable()?.lineGap ?? 0)
    }

    /// Returns the cap height of a font.
    public var capHeight: Int32 {
        if let type1Program {
            return type1Program.capHeight.flatMap(Self.integerMetric) ?? ascent * 8 / 9
        }
        if let os2 = getOS2Table(), let capHeight = os2.sCapHeight {
            return Int32(capHeight)
        }
        // Fallback: estimate as 70% of ascent
        return ascent * 70 / 100
    }

    /// Returns the x-height of a font.
    public var xHeight: Int32 {
        if let type1Program {
            return type1Program.xHeight.flatMap(Self.integerMetric) ?? ascent * 2 / 3
        }
        if let os2 = getOS2Table(), let xHeight = os2.sxHeight {
            return Int32(xHeight)
        }
        // Fallback: estimate as 50% of ascent
        return ascent * 50 / 100
    }

    /// Returns the bounding box of a font.
    public var fontBBox: CGRect {
        if let type1Program { return type1Program.fontBBox }
        return tables.head?.fontBBox ?? .zero
    }

    /// Returns the italic angle of a font.
    public var italicAngle: CGFloat {
        if let type1Program { return type1Program.italicAngle }
        return getPostTable()?.italicAngle ?? 0
    }

    /// Returns the thickness of the dominant vertical stems of glyphs in a font.
    public var stemV: CGFloat {
        if type1Program != nil { return 0 }
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
    public var tableTags: [UInt32]? {
        if type1Program != nil { return nil }
        return parser?.tableTags
    }

    /// Returns the font table that corresponds to the provided tag.
    public func table(for tag: UInt32) -> Data? {
        if type1Program != nil { return nil }
        return parser?.tableData(for: tag)
    }

    // MARK: - Glyph Metrics

    /// Gets the advance width of each glyph in the provided array.
    public func getGlyphAdvances(
        glyphs: UnsafePointer<CGGlyph>,
        count: Int,
        advances: UnsafeMutablePointer<Int32>
    ) -> Bool {
        guard count >= 0 else { return false }
        if let type1Program {
            for index in 0..<count {
                guard let glyph = type1Program.glyph(at: Int(glyphs[index])),
                      let value = Self.integerMetric(glyph.advance.width) else { return false }
                advances[index] = value
            }
            return true
        }
        guard let hmtx = getHmtxTable() else { return false }
        let regionScalars: [CGFloat]?
        if let hvar = tables.hvar {
            guard let coordinates = normalizedVariationCoordinates(),
                  let scalars = hvar.regionScalars(for: coordinates) else {
                return false
            }
            regionScalars = scalars
        } else {
            regionScalars = nil
        }

        for i in 0..<count {
            let glyphIndex = Int(glyphs[i])
            guard let baseAdvance = hmtx.advanceWidth(for: glyphIndex) else { return false }
            let delta: CGFloat
            if let hvar = tables.hvar, let regionScalars {
                guard let resolvedDelta = hvar.advanceWidthDelta(
                    for: glyphIndex,
                    regionScalars: regionScalars
                ) else {
                    return false
                }
                delta = resolvedDelta
            } else if tables.gvar != nil {
                guard let metrics = trueTypeVariationMetrics(for: glyphs[i]) else { return false }
                delta = metrics.advanceWidth - CGFloat(baseAdvance)
            } else {
                delta = 0
            }
            guard let adjustedAdvance = Self.adjustedMetric(base: baseAdvance, delta: delta) else {
                return false
            }
            advances[i] = adjustedAdvance
        }
        return true
    }

    private func trueTypeVariationMetrics(
        for glyph: CGGlyph
    ) -> (advanceWidth: CGFloat, leftSideBearing: CGFloat, advanceHeight: CGFloat?, topSideBearing: CGFloat?)? {
        guard let parser,
              let gvar = tables.gvar,
              let loca = getLocaTable(),
              let hmtx = getHmtxTable(),
              let coordinates = normalizedVariationCoordinates() else {
            return nil
        }
        return parser.parseGlyphVariationMetrics(
            glyphIndex: Int(glyph),
            loca: loca,
            gvar: gvar,
            normalizedCoordinates: coordinates,
            hmtx: hmtx,
            vmtx: tables.vmtx
        )
    }

    /// Returns the variable vertical advance height in font design units.
    internal func verticalAdvance(for glyph: CGGlyph) -> Int32? {
        guard let vmtx = tables.vmtx,
              let baseAdvance = vmtx.advanceHeight(for: Int(glyph)) else {
            return nil
        }
        if tables.vvar == nil, tables.gvar != nil {
            guard let varied = trueTypeVariationMetrics(for: glyph)?.advanceHeight else { return nil }
            return Self.adjustedMetric(base: varied, delta: 0)
        }
        guard let vvar = tables.vvar else { return Int32(baseAdvance) }
        guard let coordinates = normalizedVariationCoordinates(),
              let delta = vvar.advanceHeightDelta(
                for: Int(glyph),
                coordinates: coordinates
              ) else {
            return nil
        }
        return Self.adjustedMetric(base: baseAdvance, delta: delta)
    }

    /// Returns the variable horizontal left side bearing in font design units.
    internal func horizontalLeftSideBearing(for glyph: CGGlyph) -> Int32? {
        if let type1Program {
            guard let value = type1Program.glyph(at: Int(glyph))?.sideBearing.x else { return nil }
            return Self.integerMetric(value)
        }
        guard let hmtx = getHmtxTable(),
              let baseBearing = hmtx.leftSideBearing(for: Int(glyph)) else {
            return nil
        }
        if tables.hvar == nil, tables.gvar != nil {
            guard let varied = trueTypeVariationMetrics(for: glyph) else { return nil }
            return Self.adjustedMetric(base: varied.leftSideBearing, delta: 0)
        }
        guard let hvar = tables.hvar else { return Int32(baseBearing) }
        guard let coordinates = normalizedVariationCoordinates(),
              let delta = hvar.leftSideBearingDelta(
                for: Int(glyph),
                coordinates: coordinates
              ) else {
            return nil
        }
        return Self.adjustedMetric(base: CGFloat(baseBearing), delta: delta)
    }

    /// Returns the variable vertical top side bearing in font design units.
    internal func verticalTopSideBearing(for glyph: CGGlyph) -> Int32? {
        guard let vmtx = tables.vmtx,
              let baseBearing = vmtx.topSideBearing(for: Int(glyph)) else {
            return nil
        }
        if tables.vvar == nil, tables.gvar != nil {
            guard let varied = trueTypeVariationMetrics(for: glyph)?.topSideBearing else { return nil }
            return Self.adjustedMetric(base: varied, delta: 0)
        }
        guard let vvar = tables.vvar else { return Int32(baseBearing) }
        guard let coordinates = normalizedVariationCoordinates(),
              let delta = vvar.topSideBearingDelta(
                for: Int(glyph),
                coordinates: coordinates
              ) else {
            return nil
        }
        return Self.adjustedMetric(base: CGFloat(baseBearing), delta: delta)
    }

    /// Returns the variable vertical origin Y coordinate in font design units.
    internal func verticalOriginY(for glyph: CGGlyph) -> Int32? {
        let glyphIndex = Int(glyph)
        if let vorg = tables.vorg {
            guard let baseOrigin = vorg.originY(for: glyphIndex) else { return nil }
            let delta: CGFloat
            if let vvar = tables.vvar {
                guard let coordinates = normalizedVariationCoordinates(),
                      let resolved = vvar.verticalOriginDelta(
                        for: glyphIndex,
                        coordinates: coordinates
                      ) else {
                    return nil
                }
                delta = resolved
            } else {
                delta = 0
            }
            return Self.adjustedMetric(base: CGFloat(baseOrigin), delta: delta)
        }
        guard let topBearing = verticalTopSideBearing(for: glyph),
              let glyphPath = path(for: glyph) else {
            return nil
        }
        return Self.adjustedMetric(
            base: CGFloat(topBearing) + glyphPath.boundingBox.maxY,
            delta: 0
        )
    }

    /// Gets the bounding box of each glyph in an array.
    public func getGlyphBBoxes(
        glyphs: UnsafePointer<CGGlyph>,
        count: Int,
        bboxes: UnsafeMutablePointer<CGRect>
    ) -> Bool {
        guard count >= 0 else { return false }
        if let type1Program {
            for index in 0..<count {
                guard let bounds = type1Program.glyphBounds(at: Int(glyphs[index])) else { return false }
                bboxes[index] = bounds
            }
            return true
        }
        guard let parser else { return false }

        if parser.hasTable(FontTableTag.CFF) {
            guard let cff = getCFFProgram() else { return false }
            for index in 0..<count {
                let glyphIndex = Int(glyphs[index])
                guard glyphIndex < numberOfGlyphs,
                      let path = cff.path(glyphIndex: glyphIndex) else {
                    return false
                }
                bboxes[index] = path.boundingBox
            }
            return true
        }

        if parser.hasTable(FontTableTag.CFF2) {
            guard let cff2 = getCFF2Program(),
                  let coordinates = normalizedVariationCoordinates() else {
                return false
            }
            for index in 0..<count {
                let glyphIndex = Int(glyphs[index])
                guard glyphIndex < numberOfGlyphs,
                      let path = cff2.path(
                          glyphIndex: glyphIndex,
                          normalizedCoordinates: coordinates
                      ) else {
                    return false
                }
                bboxes[index] = path.boundingBox
            }
            return true
        }

        guard let loca = getLocaTable() else { return false }
        let hmtx = parser.hasTable(FontTableTag.hhea) && parser.hasTable(FontTableTag.hmtx)
            ? getHmtxTable()
            : nil

        if tables.gvar != nil {
            for index in 0..<count {
                guard let variedPath = path(for: glyphs[index]) else { return false }
                bboxes[index] = variedPath.isEmpty ? .zero : variedPath.boundingBox
            }
            return true
        }

        for i in 0..<count {
            let glyphIndex = Int(glyphs[i])

            if let location = loca.glyphLocation(for: glyphIndex),
               location.length > 0,
               let bbox = parser.parseGlyphBBox(glyphOffset: location.offset, glyphLength: location.length) {
                if let leftSideBearing = hmtx?.leftSideBearing(for: glyphIndex) {
                    bboxes[i] = CGRect(
                        x: CGFloat(leftSideBearing),
                        y: CGFloat(bbox.yMin),
                        width: CGFloat(Int32(bbox.xMax) - Int32(bbox.xMin)),
                        height: CGFloat(Int32(bbox.yMax) - Int32(bbox.yMin))
                    )
                } else {
                    bboxes[i] = bbox.cgRect
                }
            } else {
                // Empty glyph (space, etc.)
                bboxes[i] = .zero
            }
        }
        return true
    }

    /// Returns a glyph outline in font design units.
    internal func path(for glyph: CGGlyph) -> CGPath? {
        guard Int(glyph) < numberOfGlyphs else { return nil }
        if let type1Program { return type1Program.glyph(at: Int(glyph))?.path }
        guard let parser else { return nil }
        if parser.hasTable(FontTableTag.CFF) {
            return getCFFProgram()?.path(glyphIndex: Int(glyph))
        }
        if parser.hasTable(FontTableTag.CFF2) {
            guard let coordinates = normalizedVariationCoordinates() else { return nil }
            return getCFF2Program()?.path(
                glyphIndex: Int(glyph),
                normalizedCoordinates: coordinates
            )
        }
        guard let loca = getLocaTable() else { return nil }
        if let gvar = tables.gvar {
            guard let coordinates = normalizedVariationCoordinates(),
                  let hmtx = getHmtxTable() else { return nil }
            return parser.parseGlyphPath(
                glyphIndex: Int(glyph),
                loca: loca,
                gvar: gvar,
                normalizedCoordinates: coordinates,
                hmtx: hmtx,
                vmtx: tables.vmtx
            )
        }
        let hmtx = parser.hasTable(FontTableTag.hhea) && parser.hasTable(FontTableTag.hmtx)
            ? getHmtxTable()
            : nil
        return parser.parseGlyphPath(
            glyphIndex: Int(glyph),
            loca: loca,
            hmtx: hmtx,
            vmtx: tables.vmtx
        )
    }

    // MARK: - Glyph Names

    /// Returns the glyph name of the specified glyph in the specified font.
    public func name(for glyph: CGGlyph) -> String? {
        if let type1Program { return type1Program.glyphName(at: Int(glyph)) }
        guard let post = getPostTable() else { return nil }
        return post.name(for: Int(glyph))
    }

    /// Returns the glyph for the glyph name associated with the specified font object.
    public func getGlyphWithGlyphName(name: String) -> CGGlyph {
        if let type1Program, let index = type1Program.glyphIndex(named: name) {
            return CGGlyph(index)
        }
        guard let post = getPostTable(),
              let glyphNames = post.glyphNames else {
            return kCGFontIndexInvalid
        }

        for (index, glyphName) in glyphNames.enumerated() {
            if glyphName == name {
                return CGGlyph(index)
            }
        }
        return kCGFontIndexInvalid
    }

    // MARK: - Variations

    /// Returns the variation specification dictionary for a font.
    public var variations: [String: CGFloat]? {
        guard let fvar = getFvarTable() else { return nil }
        var values: [String: CGFloat] = [:]
        values.reserveCapacity(fvar.axes.count)
        for axis in fvar.axes {
            let name = variationAxisName(axis)
            guard values[name] == nil else { return nil }
            values[name] = variationCoordinates?[axis.tagString] ?? axis.defaultValue
        }
        return values
    }

    /// Returns an array of the variation axis dictionaries for a font.
    public var variationAxes: [[String: Any]]? {
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

            if let nameTable,
               let record = nameTable.records.first(where: { $0.nameID == axis.nameID }) {
                axisDict[kCGFontVariationAxisName] = record.value
            }

            axes.append(axisDict)
        }

        return axes
    }

    /// Creates a copy of a font using a variation specification dictionary.
    public func copy(withVariations variations: [String: Any]?) -> CGFont? {
        guard let fvar = getFvarTable(), !fvar.axes.isEmpty else {
            // Not a variable font
            return nil
        }

        var coords: [String: CGFloat] = variationCoordinates ?? [:]

        if let variations {
            var axesByName: [String: FvarTable.VariationAxis] = [:]
            axesByName.reserveCapacity(fvar.axes.count)
            for axis in fvar.axes {
                let name = variationAxisName(axis)
                guard axesByName[name] == nil else { return nil }
                axesByName[name] = axis
            }
            for (key, value) in variations {
                guard let axis = axesByName[key],
                      let numericValue = Self.variationValue(value), numericValue.isFinite else {
                    return nil
                }
                coords[axis.tagString] = min(max(numericValue, axis.minValue), axis.maxValue)
            }
        }

        return CGFont(
            fontData: fontData,
            parser: parser,
            tables: tables,
            type1Program: type1Program,
            variationCoordinates: coords.isEmpty ? nil : coords
        )
    }

    private func variationAxisName(_ axis: FvarTable.VariationAxis) -> String {
        getNameTable()?.records.first(where: { $0.nameID == axis.nameID })?.value ?? axis.tagString
    }

    private func normalizedVariationCoordinates() -> [CGFloat]? {
        guard let fvar = getFvarTable() else {
            return parser?.hasTable(FontTableTag.CFF2) == true ? [] : nil
        }
        let avar = getAvarTable()
        var normalized: [CGFloat] = []
        normalized.reserveCapacity(fvar.axes.count)
        for (index, axis) in fvar.axes.enumerated() {
            let requested = variationCoordinates?[axis.tagString] ?? axis.defaultValue
            let clamped = min(max(requested, axis.minValue), axis.maxValue)
            let value: CGFloat
            if clamped == axis.defaultValue {
                value = 0
            } else if clamped < axis.defaultValue {
                let distance = axis.defaultValue - axis.minValue
                value = distance == 0 ? 0 : (clamped - axis.defaultValue) / distance
            } else {
                let distance = axis.maxValue - axis.defaultValue
                value = distance == 0 ? 0 : (clamped - axis.defaultValue) / distance
            }
            if let avar {
                guard let mapped = avar.map(value, axisIndex: index) else { return nil }
                normalized.append(mapped)
            } else {
                normalized.append(value)
            }
        }
        return normalized
    }

    private static func variationValue(_ value: Any) -> CGFloat? {
        if let value = value as? CGFloat { return value }
        if let value = value as? Double { return CGFloat(value) }
        if let value = value as? Float { return CGFloat(value) }
        if let value = value as? Int { return CGFloat(value) }
        if let value = value as? Int32 { return CGFloat(value) }
        if let value = value as? UInt { return CGFloat(value) }
        return nil
    }

    private static func adjustedMetric(base: UInt16, delta: CGFloat) -> Int32? {
        adjustedMetric(base: CGFloat(base), delta: delta)
    }

    private static func adjustedMetric(base: CGFloat, delta: CGFloat) -> Int32? {
        let value = base + delta
        guard value.isFinite,
              value >= CGFloat(Int32.min), value <= CGFloat(Int32.max) else {
            return nil
        }
        return Int32(value.rounded(.toNearestOrAwayFromZero))
    }

    private static func integerMetric(_ value: CGFloat) -> Int32? {
        guard value.isFinite, value >= CGFloat(Int32.min), value <= CGFloat(Int32.max) else {
            return nil
        }
        return Int32(value.rounded(.toNearestOrAwayFromZero))
    }

    // MARK: - Color Font Support (SF Symbols)

    /// Returns whether this font has color glyph data.
    public var hasColorGlyphs: Bool {
        if type1Program != nil { return false }
        return getColrTable() != nil && getCpalTable() != nil
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
        guard fontData != nil, numberOfGlyphs > 0 else { return false }
        if type1Program != nil {
            return format == .type1
        }
        guard parser != nil else { return false }
        switch format {
        case .type1:
            let hasOutline = parser?.hasTable(FontTableTag.glyf) == true
                || parser?.hasTable(FontTableTag.CFF) == true
                || parser?.hasTable(FontTableTag.CFF2) == true
            return hasOutline && getHmtxTable() != nil
        case .type3:
            return false
        case .type42:
            return parser?.hasTable(FontTableTag.glyf) == true
                && parser?.hasTable(FontTableTag.loca) == true
                && getHmtxTable() != nil
        }
    }

    /// Creates a subset of the font in the specified PostScript format.
    public func createPostScriptSubset(
        subsetName: String,
        format: CGFontPostScriptFormat,
        glyphs: UnsafePointer<CGGlyph>?,
        count: Int,
        encoding: UnsafePointer<CGGlyph>?
    ) -> Data? {
        guard canCreatePostScriptSubset(format), count >= 0,
              count == 0 || glyphs != nil,
              let fontData else {
            return nil
        }

        let requestedGlyphs: [CGGlyph]
        if count == 0 {
            requestedGlyphs = (0..<numberOfGlyphs).map(CGGlyph.init)
        } else {
            requestedGlyphs = Array(UnsafeBufferPointer(start: glyphs, count: count))
        }

        let requestedEncoding = encoding.map {
            Array(UnsafeBufferPointer(start: $0, count: 256))
        }
        let encoder = PostScriptFontEncoder(
            fontData: fontData,
            glyphCount: numberOfGlyphs,
            unitsPerEm: Int(unitsPerEm),
            fontBoundingBox: fontBBox,
            italicAngle: italicAngle,
            defaultFontName: postScriptName ?? fullName ?? "SubsetFont",
            path: { [self] in path(for: $0) },
            glyphName: { [self] in name(for: $0) },
            advance: { [self] glyph in
                var glyph = glyph
                var value: Int32 = 0
                return getGlyphAdvances(glyphs: &glyph, count: 1, advances: &value) ? value : nil
            },
            leftSideBearing: { [self] in horizontalLeftSideBearing(for: $0) }
        )
        return encoder.subset(
            name: subsetName,
            format: format,
            glyphs: requestedGlyphs,
            encoding: requestedEncoding
        )
    }

    /// Creates a PostScript encoding of a font.
    public func createPostScriptEncoding(encoding: UnsafePointer<CGGlyph>?) -> Data? {
        let requestedEncoding = encoding.map {
            Array(UnsafeBufferPointer(start: $0, count: 256))
        } ?? [CGGlyph](repeating: 0, count: 256)
        return PostScriptFontEncoder.encodingData(
            encoding: requestedEncoding,
            glyphName: { [self] in name(for: $0) }
        )
    }

    // MARK: - Type ID

    /// Returns a type identifier for CGFont.
    public class var typeID: UInt {
        return CGTypeIdentifier.font
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
public func CGFontCreateWithFontName(_ name: String) -> CGFont? {
    return CGFont(name)
}

/// Creates a copy of a font with variations.
public func CGFontCreateCopyWithVariations(_ font: CGFont, _ variations: [String: Any]?) -> CGFont? {
    return font.copy(withVariations: variations)
}
