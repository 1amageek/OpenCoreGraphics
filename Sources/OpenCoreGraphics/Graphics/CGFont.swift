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
    private var cachedVhea: VheaTable?
    private var cachedVmtx: VmtxTable?
    private var cachedVorg: VorgTable?
    private var cachedPost: PostTable?
    private var cachedOS2: OS2Table?
    private var cachedName: NameTable?
    private var cachedLoca: LocaTable?
    private var cachedFvar: FvarTable?
    private var cachedAvar: AvarTable?
    private var cachedHvar: HvarTable?
    private var cachedVvar: VvarTable?
    private var cachedColr: ColrTable?
    private var cachedCpal: CpalTable?
    private var cachedCFF: CFFFontProgram?
    private var cachedCFF2: CFF2FontProgram?

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
        let glyphCount = Int(cachedMaxp?.numGlyphs ?? 0)
        let hasVerticalHeader = parser.hasTable(FontTableTag.vhea)
        let hasVerticalMetrics = parser.hasTable(FontTableTag.vmtx)
        guard hasVerticalHeader == hasVerticalMetrics else { return nil }
        if hasVerticalHeader {
            do {
                let vhea = try parser.parseVheaTable()
                self.cachedVhea = vhea
                self.cachedVmtx = try parser.parseVmtxTable(
                    numberOfGlyphs: glyphCount,
                    numberOfVMetrics: Int(vhea.numberOfVMetrics)
                )
            } catch {
                return nil
            }
        }
        if parser.hasTable(FontTableTag.VORG)
            && (parser.hasTable(FontTableTag.CFF) || parser.hasTable(FontTableTag.CFF2)) {
            guard cachedVmtx != nil else { return nil }
            do {
                guard let vorg = try parser.parseVorgTable(glyphCount: glyphCount) else { return nil }
                self.cachedVorg = vorg
            } catch {
                return nil
            }
        }
        if parser.hasTable(FontTableTag.fvar) {
            do {
                guard let fvar = try parser.parseFvarTable() else { return nil }
                self.cachedFvar = fvar
                self.cachedAvar = try parser.parseAvarTable(axisCount: fvar.axes.count)
                if parser.hasTable(FontTableTag.HVAR) {
                    let hhea = try parser.parseHheaTable()
                    self.cachedHhea = hhea
                    self.cachedHmtx = try parser.parseHmtxTable(
                        numberOfGlyphs: glyphCount,
                        numberOfHMetrics: Int(hhea.numberOfHMetrics)
                    )
                    guard let hvar = try parser.parseHvarTable(
                        axisCount: fvar.axes.count,
                        glyphCount: glyphCount
                    ) else {
                        return nil
                    }
                    self.cachedHvar = hvar
                }
                if parser.hasTable(FontTableTag.VVAR) {
                    guard self.cachedVmtx != nil else { return nil }
                    guard let vvar = try parser.parseVvarTable(
                        axisCount: fvar.axes.count,
                        glyphCount: glyphCount
                    ) else {
                        return nil
                    }
                    self.cachedVvar = vvar
                }
            } catch {
                return nil
            }
        } else if parser.hasTable(FontTableTag.avar)
                    || parser.hasTable(FontTableTag.HVAR)
                    || parser.hasTable(FontTableTag.VVAR) {
            return nil
        }
        if parser.hasTable(FontTableTag.CFF) {
            guard !parser.hasTable(FontTableTag.CFF2),
                  let cff = parser.parseCFFFontProgram(),
                  cff.charStrings.ranges.count == Int(cachedMaxp?.numGlyphs ?? 0) else {
                return nil
            }
            self.cachedCFF = cff
        } else if parser.hasTable(FontTableTag.CFF2) {
            let axisCount = cachedFvar?.axes.count ?? 0
            guard let cff2 = parser.parseCFF2FontProgram(
                axisCount: axisCount,
                unitsPerEm: Int(cachedHead?.unitsPerEm ?? 0)
            ), cff2.charStrings.ranges.count == Int(cachedMaxp?.numGlyphs ?? 0) else {
                return nil
            }
            self.cachedCFF2 = cff2
        }
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
        cachedHead: HeadTable?,
        cachedHhea: HheaTable?,
        cachedMaxp: MaxpTable?,
        cachedHmtx: HmtxTable?,
        cachedVhea: VheaTable?,
        cachedVmtx: VmtxTable?,
        cachedVorg: VorgTable?,
        cachedPost: PostTable?,
        cachedOS2: OS2Table?,
        cachedName: NameTable?,
        cachedLoca: LocaTable?,
        cachedFvar: FvarTable?,
        cachedAvar: AvarTable?,
        cachedHvar: HvarTable?,
        cachedVvar: VvarTable?,
        cachedColr: ColrTable?,
        cachedCpal: CpalTable?,
        cachedCFF: CFFFontProgram?,
        cachedCFF2: CFF2FontProgram?,
        variationCoordinates: [String: CGFloat]?
    ) {
        self.fontData = fontData
        self.parser = parser
        self.cachedHead = cachedHead
        self.cachedHhea = cachedHhea
        self.cachedMaxp = cachedMaxp
        self.cachedHmtx = cachedHmtx
        self.cachedVhea = cachedVhea
        self.cachedVmtx = cachedVmtx
        self.cachedVorg = cachedVorg
        self.cachedPost = cachedPost
        self.cachedOS2 = cachedOS2
        self.cachedName = cachedName
        self.cachedLoca = cachedLoca
        self.cachedFvar = cachedFvar
        self.cachedAvar = cachedAvar
        self.cachedHvar = cachedHvar
        self.cachedVvar = cachedVvar
        self.cachedColr = cachedColr
        self.cachedCpal = cachedCpal
        self.cachedCFF = cachedCFF
        self.cachedCFF2 = cachedCFF2
        self.variationCoordinates = variationCoordinates
    }

    // MARK: - Lazy Table Loading

    private func getHheaTable() -> HheaTable? {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        if cachedHhea == nil, let parser = parser {
            do {
                cachedHhea = try parser.parseHheaTable()
            } catch {
                print("CGFont: failed to parse hhea table: \(error)")
                cachedHhea = nil
            }
        }
        return cachedHhea
    }

    private func getHmtxTable() -> HmtxTable? {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        if cachedHmtx == nil {
            guard let hhea = getHheaTable(),
                  let maxp = cachedMaxp,
                  let parser = parser else { return nil }
            do {
                cachedHmtx = try parser.parseHmtxTable(
                    numberOfGlyphs: Int(maxp.numGlyphs),
                    numberOfHMetrics: Int(hhea.numberOfHMetrics)
                )
            } catch {
                print("CGFont: failed to parse hmtx table: \(error)")
                cachedHmtx = nil
            }
        }
        return cachedHmtx
    }

    private func getPostTable() -> PostTable? {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        if cachedPost == nil, let parser = parser {
            do {
                cachedPost = try parser.parsePostTable()
            } catch {
                print("CGFont: failed to parse post table: \(error)")
                cachedPost = nil
            }
        }
        return cachedPost
    }

    private func getOS2Table() -> OS2Table? {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        if cachedOS2 == nil, let parser = parser {
            do {
                cachedOS2 = try parser.parseOS2Table()
            } catch {
                print("CGFont: failed to parse OS/2 table: \(error)")
                cachedOS2 = nil
            }
        }
        return cachedOS2
    }

    private func getNameTable() -> NameTable? {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        if cachedName == nil, let parser = parser {
            do {
                cachedName = try parser.parseNameTable()
            } catch {
                print("CGFont: failed to parse name table: \(error)")
                cachedName = nil
            }
        }
        return cachedName
    }

    private func getLocaTable() -> LocaTable? {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        if cachedLoca == nil {
            guard let head = cachedHead,
                  let maxp = cachedMaxp,
                  let parser = parser else { return nil }
            do {
                cachedLoca = try parser.parseLocaTable(
                    numGlyphs: Int(maxp.numGlyphs),
                    indexToLocFormat: head.indexToLocFormat
                )
            } catch {
                print("CGFont: failed to parse loca table: \(error)")
                cachedLoca = nil
            }
        }
        return cachedLoca
    }

    private func getFvarTable() -> FvarTable? {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        if cachedFvar == nil, let parser = parser {
            do {
                cachedFvar = try parser.parseFvarTable()
            } catch {
                print("CGFont: failed to parse fvar table: \(error)")
                cachedFvar = nil
            }
        }
        return cachedFvar
    }

    private func getAvarTable() -> AvarTable? {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        if cachedAvar == nil, let parser, let fvar = getFvarTable() {
            do {
                cachedAvar = try parser.parseAvarTable(axisCount: fvar.axes.count)
            } catch {
                print("CGFont: failed to parse avar table: \(error)")
                cachedAvar = nil
            }
        }
        return cachedAvar
    }

    private func getColrTable() -> ColrTable? {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        if cachedColr == nil, let parser = parser {
            do {
                cachedColr = try parser.parseColrTable()
            } catch {
                print("CGFont: failed to parse COLR table: \(error)")
                cachedColr = nil
            }
        }
        return cachedColr
    }

    private func getCpalTable() -> CpalTable? {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        if cachedCpal == nil, let parser = parser {
            do {
                cachedCpal = try parser.parseCpalTable()
            } catch {
                print("CGFont: failed to parse CPAL table: \(error)")
                cachedCpal = nil
            }
        }
        return cachedCpal
    }

    private func getCFFProgram() -> CFFFontProgram? {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        if cachedCFF == nil, let parser {
            cachedCFF = parser.parseCFFFontProgram()
        }
        return cachedCFF
    }

    private func getCFF2Program() -> CFF2FontProgram? {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        if cachedCFF2 == nil, let parser {
            cachedCFF2 = parser.parseCFF2FontProgram(
                axisCount: getFvarTable()?.axes.count ?? 0,
                unitsPerEm: Int(cachedHead?.unitsPerEm ?? 0)
            )
        }
        return cachedCFF2
    }

    // MARK: - Font Metadata

    /// Returns the full name associated with a font object.
    public var fullName: String? {
        getNameTable()?.fullName
    }

    /// Obtains the PostScript name of a font.
    public var postScriptName: String? {
        getNameTable()?.postScriptName
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
    public var tableTags: [UInt32]? {
        parser?.tableTags
    }

    /// Returns the font table that corresponds to the provided tag.
    public func table(for tag: UInt32) -> Data? {
        parser?.tableData(for: tag)
    }

    // MARK: - Glyph Metrics

    /// Gets the advance width of each glyph in the provided array.
    public func getGlyphAdvances(
        glyphs: UnsafePointer<CGGlyph>,
        count: Int,
        advances: UnsafeMutablePointer<Int32>
    ) -> Bool {
        guard count >= 0, let hmtx = getHmtxTable() else { return false }
        let regionScalars: [CGFloat]?
        if let hvar = cachedHvar {
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
            if let hvar = cachedHvar, let regionScalars {
                guard let resolvedDelta = hvar.advanceWidthDelta(
                    for: glyphIndex,
                    regionScalars: regionScalars
                ) else {
                    return false
                }
                delta = resolvedDelta
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

    /// Returns the variable vertical advance height in font design units.
    internal func verticalAdvance(for glyph: CGGlyph) -> Int32? {
        guard let vmtx = cachedVmtx,
              let baseAdvance = vmtx.advanceHeight(for: Int(glyph)) else {
            return nil
        }
        guard let vvar = cachedVvar else { return Int32(baseAdvance) }
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
        guard let hmtx = getHmtxTable(),
              let baseBearing = hmtx.leftSideBearing(for: Int(glyph)) else {
            return nil
        }
        guard let hvar = cachedHvar else { return Int32(baseBearing) }
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
        guard let vmtx = cachedVmtx,
              let baseBearing = vmtx.topSideBearing(for: Int(glyph)) else {
            return nil
        }
        guard let vvar = cachedVvar else { return Int32(baseBearing) }
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
        if let vorg = cachedVorg {
            guard let baseOrigin = vorg.originY(for: glyphIndex) else { return nil }
            let delta: CGFloat
            if let vvar = cachedVvar {
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

    /// Returns a glyph outline in font design units.
    internal func path(for glyph: CGGlyph) -> CGPath? {
        guard Int(glyph) < numberOfGlyphs,
              let parser else {
            return nil
        }
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
        return parser.parseGlyphPath(glyphIndex: Int(glyph), loca: loca)
    }

    // MARK: - Glyph Names

    /// Returns the glyph name of the specified glyph in the specified font.
    public func name(for glyph: CGGlyph) -> String? {
        guard let post = getPostTable() else { return nil }
        return post.name(for: Int(glyph))
    }

    /// Returns the glyph for the glyph name associated with the specified font object.
    public func getGlyphWithGlyphName(name: String) -> CGGlyph {
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
            cachedHead: cachedHead,
            cachedHhea: cachedHhea,
            cachedMaxp: cachedMaxp,
            cachedHmtx: cachedHmtx,
            cachedVhea: cachedVhea,
            cachedVmtx: cachedVmtx,
            cachedVorg: cachedVorg,
            cachedPost: cachedPost,
            cachedOS2: cachedOS2,
            cachedName: cachedName,
            cachedLoca: cachedLoca,
            cachedFvar: cachedFvar,
            cachedAvar: cachedAvar,
            cachedHvar: cachedHvar,
            cachedVvar: cachedVvar,
            cachedColr: cachedColr,
            cachedCpal: cachedCpal,
            cachedCFF: cachedCFF,
            cachedCFF2: cachedCFF2,
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
        subsetName: String,
        format: CGFontPostScriptFormat,
        glyphs: UnsafePointer<CGGlyph>?,
        count: Int,
        encoding: UnsafePointer<CGGlyph>?
    ) -> Data? {
        // PostScript subset creation is not implemented
        return nil
    }

    /// Creates a PostScript encoding of a font.
    public func createPostScriptEncoding(encoding: UnsafePointer<CGGlyph>?) -> Data? {
        // PostScript encoding creation is not implemented
        return nil
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
