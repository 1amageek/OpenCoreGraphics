//
//  CGPDFTypes.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//

import Foundation


// MARK: - CGPDFBox

/// Box types for a PDF page.
public enum CGPDFBox: Int32, Sendable {
    /// The page media box.
    ///
    /// A rectangle, expressed in default user space units, that defines the boundaries
    /// of the physical medium on which the page is intended to be displayed or printed.
    case mediaBox = 0

    /// The page crop box.
    ///
    /// A rectangle, expressed in default user space units, that defines the visible region
    /// of default user space. When the page is displayed or printed, its contents are to
    /// be clipped to this rectangle.
    case cropBox = 1

    /// The page bleed box.
    ///
    /// A rectangle, expressed in default user space units, that defines the region to which
    /// the contents of the page should be clipped when output in a production environment.
    case bleedBox = 2

    /// The page trim box.
    ///
    /// A rectangle, expressed in default user space units, that defines the intended
    /// dimensions of the finished page after trimming.
    case trimBox = 3

    /// The page art box.
    ///
    /// A rectangle, expressed in default user space units, defining the extent of the
    /// page's meaningful content (including potential white space) as intended by the
    /// page's creator.
    case artBox = 4
}

// MARK: - CGPDFObjectType

/// Types of PDF object.
public enum CGPDFObjectType: Int32, Sendable {
    /// The type for a PDF null.
    case null = 0

    /// The type for a PDF Boolean.
    case boolean = 1

    /// The type for a PDF integer.
    case integer = 2

    /// The type for a PDF real.
    case real = 3

    /// Type for a PDF name.
    case name = 4

    /// The type for a PDF string.
    case string = 5

    /// Type for a PDF array.
    case array = 6

    /// The type for a PDF dictionary.
    case dictionary = 7

    /// The type for a PDF stream.
    case stream = 8
}

// MARK: - CGPDFDataFormat

/// The encoding format of PDF data.
public enum CGPDFDataFormat: Int32, Sendable {
    /// The data stream is not encoded.
    case raw = 0

    /// The data stream is encoded in JPEG format.
    case jpegEncoded = 1

    /// The data stream is encoded in JPEG-2000 format.
    case JPEG2000 = 2
}

// MARK: - CGPDFAccessPermissions

/// Access permissions for a PDF document.
public struct CGPDFAccessPermissions: OptionSet, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /// Allows low-quality printing of the document.
    public static let allowsLowQualityPrinting = CGPDFAccessPermissions(rawValue: 1 << 0)

    /// Allows high-quality printing of the document.
    public static let allowsHighQualityPrinting = CGPDFAccessPermissions(rawValue: 1 << 1)

    /// Allows changes to the document.
    public static let allowsDocumentChanges = CGPDFAccessPermissions(rawValue: 1 << 2)

    /// Allows document assembly.
    public static let allowsDocumentAssembly = CGPDFAccessPermissions(rawValue: 1 << 3)

    /// Allows content copying.
    public static let allowsContentCopying = CGPDFAccessPermissions(rawValue: 1 << 4)

    /// Allows content accessibility.
    public static let allowsContentAccessibility = CGPDFAccessPermissions(rawValue: 1 << 5)

    /// Allows commenting on the document.
    public static let allowsCommenting = CGPDFAccessPermissions(rawValue: 1 << 6)

    /// Allows form field entry.
    public static let allowsFormFieldEntry = CGPDFAccessPermissions(rawValue: 1 << 7)
}

// MARK: - PDF Object Reference Types
//
// Design Note: These OpaquePointer type aliases are provided for API signature
// compatibility only. In Apple's CoreGraphics, these are used with C-style
// functions (CGPDFArrayGetCount, CGPDFDictionaryGetBoolean, etc.) that operate
// on internal PDF parser state.
//
// OpenCoreGraphics does not implement PDF parsing. For PDF functionality in
// WASM environments, use a dedicated OpenPDFKit module.

/// A reference to a PDF array object.
public typealias CGPDFArrayRef = OpaquePointer

/// A reference to a PDF dictionary object.
public typealias CGPDFDictionaryRef = OpaquePointer

/// A reference to a PDF object.
public typealias CGPDFObjectRef = OpaquePointer

/// A reference to a PDF stream object.
public typealias CGPDFStreamRef = OpaquePointer

/// A reference to a PDF string object.
public typealias CGPDFStringRef = OpaquePointer

