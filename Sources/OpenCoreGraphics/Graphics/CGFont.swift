//
//  CGFont.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//

import Foundation


/// A set of character glyphs and layout information for drawing text.
public class CGFont: @unchecked Sendable {

    /// The PostScript name of the font.
    public let postScriptName: String?

    /// The full name of the font.
    public let fullName: String?

    /// The number of glyphs in the font.
    public let numberOfGlyphs: Int

    /// The number of font units per em.
    public let unitsPerEm: Int

    /// The ascent of the font measured in font units.
    public let ascent: Int

    /// The descent of the font measured in font units.
    public let descent: Int

    /// The leading of the font measured in font units.
    public let leading: Int

    /// The cap height of the font measured in font units.
    public let capHeight: Int

    /// The x-height of the font measured in font units.
    public let xHeight: Int

    /// The bounding box for the font.
    public let fontBBox: CGRect

    /// The italic angle of the font.
    public let italicAngle: CGFloat

    /// The thickness of the dominant stem of the font.
    public let stemV: CGFloat

    /// The font data.
    internal let data: Data?

    // MARK: - Glyph Index Type

    /// A type representing a glyph index.
    public typealias CGGlyph = UInt16

    // MARK: - Initializers

    /// Creates a font from a data provider.
    public init?(dataProvider: CGDataProvider) {
        // In a real implementation, this would parse font data
        self.postScriptName = nil
        self.fullName = nil
        self.numberOfGlyphs = 0
        self.unitsPerEm = 1000
        self.ascent = 800
        self.descent = -200
        self.leading = 0
        self.capHeight = 700
        self.xHeight = 500
        self.fontBBox = CGRect(x: 0, y: -200, width: 1000, height: 1000)
        self.italicAngle = 0
        self.stemV = 80
        self.data = dataProvider.data
    }

    /// Creates a font with the specified name.
    public init?(name: String) {
        self.postScriptName = name
        self.fullName = name
        self.numberOfGlyphs = 256  // Simplified
        self.unitsPerEm = 1000
        self.ascent = 800
        self.descent = -200
        self.leading = 0
        self.capHeight = 700
        self.xHeight = 500
        self.fontBBox = CGRect(x: 0, y: -200, width: 1000, height: 1000)
        self.italicAngle = 0
        self.stemV = 80
        self.data = nil
    }

    /// Internal initializer for complete font creation.
    internal init(postScriptName: String?, fullName: String?, numberOfGlyphs: Int,
                  unitsPerEm: Int, ascent: Int, descent: Int, leading: Int,
                  capHeight: Int, xHeight: Int, fontBBox: CGRect,
                  italicAngle: CGFloat, stemV: CGFloat, data: Data?) {
        self.postScriptName = postScriptName
        self.fullName = fullName
        self.numberOfGlyphs = numberOfGlyphs
        self.unitsPerEm = unitsPerEm
        self.ascent = ascent
        self.descent = descent
        self.leading = leading
        self.capHeight = capHeight
        self.xHeight = xHeight
        self.fontBBox = fontBBox
        self.italicAngle = italicAngle
        self.stemV = stemV
        self.data = data
    }

    // MARK: - Creating a Copy

    /// Creates a copy of the font.
    public func copy() -> CGFont? {
        return CGFont(
            postScriptName: postScriptName,
            fullName: fullName,
            numberOfGlyphs: numberOfGlyphs,
            unitsPerEm: unitsPerEm,
            ascent: ascent,
            descent: descent,
            leading: leading,
            capHeight: capHeight,
            xHeight: xHeight,
            fontBBox: fontBBox,
            italicAngle: italicAngle,
            stemV: stemV,
            data: data
        )
    }

    /// Creates a copy of the font with the specified glyph variations.
    public func copy(withVariations variations: [String: Double]?) -> CGFont? {
        // In a real implementation, this would create a variation font
        return copy()
    }

    // MARK: - Working with Glyphs

    /// Returns the glyph for the specified name.
    public func glyph(named name: String) -> CGGlyph {
        // In a real implementation, this would look up the glyph
        return 0
    }

    /// Returns the name of the specified glyph.
    public func name(for glyph: CGGlyph) -> String? {
        // In a real implementation, this would look up the glyph name
        return nil
    }

    /// Returns the advance width for the specified glyph.
    public func advance(for glyph: CGGlyph) -> Int {
        // In a real implementation, this would return the actual advance
        return unitsPerEm / 2
    }

    /// Returns the advances for the specified glyphs.
    public func advances(for glyphs: [CGGlyph]) -> [Int] {
        return glyphs.map { advance(for: $0) }
    }

    /// Returns the bounding box for the specified glyph.
    public func boundingBox(for glyph: CGGlyph) -> CGRect {
        // In a real implementation, this would return the actual bounding box
        let width = CGFloat(unitsPerEm / 2)
        let height = CGFloat(ascent - descent)
        return CGRect(x: 0, y: CGFloat(descent), width: width, height: height)
    }

    /// Returns the bounding boxes for the specified glyphs.
    public func boundingBoxes(for glyphs: [CGGlyph]) -> [CGRect] {
        return glyphs.map { boundingBox(for: $0) }
    }

    // MARK: - Getting Font Tables

    /// Returns the font table that corresponds to the provided tag.
    public func table(for tag: UInt32) -> Data? {
        // In a real implementation, this would extract the font table
        return nil
    }

    /// Returns an array of tags for the font tables.
    public var tableTags: [UInt32] {
        // In a real implementation, this would return actual table tags
        return []
    }

    // MARK: - Working with Variations

    /// Returns the variations dictionary for the font.
    public var variations: [String: Double]? {
        return nil
    }

    /// Returns the axes for a variation font.
    public var variationAxes: [[String: Any]]? {
        return nil
    }
}

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
    return CGFont(dataProvider: provider)
}

/// Creates a font with the specified name.
public func CGFontCreateWithFontName(_ name: String) -> CGFont? {
    return CGFont(name: name)
}

/// Creates a copy of a font.
public func CGFontCreateCopyWithVariations(_ font: CGFont, _ variations: [String: Double]?) -> CGFont? {
    return font.copy(withVariations: variations)
}

// MARK: - CGContext Font Extension

extension CGContext {
    /// Sets the font for the context.
    private var _font: CGFont? {
        get { return nil }
        set { }
    }

    /// Sets the font for a graphics context.
    public func setFont(_ font: CGFont) {
        // In a real implementation, this would store the font
    }

    /// Sets the current font size.
    public func setFontSize(_ size: CGFloat) {
        // In a real implementation, this would store the font size
    }

    /// Draws glyphs at the specified positions.
    public func showGlyphs(_ glyphs: [CGFont.CGGlyph], at positions: [CGPoint]) {
        // In a real implementation, this would render the glyphs
    }
}

