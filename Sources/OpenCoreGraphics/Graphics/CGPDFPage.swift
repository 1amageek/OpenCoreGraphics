//
//  CGPDFPage.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//

import Foundation


/// A type that represents a page in a PDF document.
public class CGPDFPage: @unchecked Sendable {

    /// The document containing this page.
    public private(set) weak var document: CGPDFDocument?

    /// The page number (1-indexed).
    public let pageNumber: Int

    /// The rotation angle of the page in degrees.
    public let rotationAngle: Int32

    /// The media box of the page.
    internal var mediaBox: CGRect

    /// The crop box of the page.
    internal var cropBox: CGRect?

    /// The bleed box of the page.
    internal var bleedBox: CGRect?

    /// The trim box of the page.
    internal var trimBox: CGRect?

    /// The art box of the page.
    internal var artBox: CGRect?

    // MARK: - Initializers

    /// Creates a PDF page.
    ///
    /// - Parameters:
    ///   - document: The document containing this page.
    ///   - pageNumber: The page number (1-indexed).
    ///   - mediaBox: The media box of the page.
    ///   - rotationAngle: The rotation angle in degrees.
    internal init(document: CGPDFDocument?, pageNumber: Int, mediaBox: CGRect, rotationAngle: Int32 = 0) {
        self.document = document
        self.pageNumber = pageNumber
        self.mediaBox = mediaBox
        self.rotationAngle = rotationAngle
    }

    // MARK: - Getting Page Information

    /// Returns the rectangle that represents a type of box for a content region or page dimensions.
    ///
    /// - Parameter box: The type of box to retrieve.
    /// - Returns: The rectangle for the specified box type.
    public func getBoxRect(_ box: CGPDFBox) -> CGRect {
        switch box {
        case .mediaBox:
            return mediaBox
        case .cropBox:
            return cropBox ?? mediaBox
        case .bleedBox:
            return bleedBox ?? (cropBox ?? mediaBox)
        case .trimBox:
            return trimBox ?? (cropBox ?? mediaBox)
        case .artBox:
            return artBox ?? (cropBox ?? mediaBox)
        }
    }

    /// Returns the dictionary of a PDF page.
    public var dictionary: CGPDFDictionaryRef? {
        return nil // Placeholder
    }

    /// Returns the affine transform that maps a box to a given rectangle on a PDF page.
    ///
    /// - Parameters:
    ///   - box: The type of box to use.
    ///   - rect: The target rectangle.
    ///   - rotate: The rotation angle in degrees (must be a multiple of 90).
    ///   - preserveAspectRatio: Whether to preserve the aspect ratio.
    /// - Returns: The affine transform.
    public func getDrawingTransform(_ box: CGPDFBox, rect: CGRect,
                                    rotate: Int32, preserveAspectRatio: Bool) -> CGAffineTransform {
        let boxRect = getBoxRect(box)

        // Calculate scale factors
        var scaleX = rect.width / boxRect.width
        var scaleY = rect.height / boxRect.height

        if preserveAspectRatio {
            let scale = min(scaleX, scaleY)
            scaleX = scale
            scaleY = scale
        }

        // Calculate total rotation (page rotation + requested rotation)
        let totalRotation = rotationAngle + rotate

        // Build the transform
        var transform = CGAffineTransform.identity

        // Translate to the center of the target rectangle
        transform = transform.translatedBy(x: rect.midX, y: rect.midY)

        // Apply rotation
        let radians = CGFloat(totalRotation) * .pi / 180.0
        transform = transform.rotated(by: radians)

        // Apply scaling
        transform = transform.scaledBy(x: scaleX, y: scaleY)

        // Translate back from the center of the box
        transform = transform.translatedBy(x: -boxRect.midX, y: -boxRect.midY)

        return transform
    }

    // MARK: - Type ID

    /// Returns the CFType ID for PDF page objects.
    public class var typeID: UInt {
        return 0 // Placeholder
    }
}

// MARK: - Equatable

extension CGPDFPage: Equatable {
    public static func == (lhs: CGPDFPage, rhs: CGPDFPage) -> Bool {
        return lhs === rhs
    }
}

// MARK: - Hashable

extension CGPDFPage: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

