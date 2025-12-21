//
//  CGPDFObject.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//


#if arch(wasm32)
import Foundation


// MARK: - Design Note: PDF Object APIs
//
// Apple's CoreGraphics provides C-style functions for PDF object manipulation:
//   - CGPDFObjectGetType, CGPDFObjectGetValue
//   - CGPDFArrayGetCount, CGPDFArrayGetBoolean, etc.
//   - CGPDFDictionaryGetCount, CGPDFDictionaryGetBoolean, etc.
//   - CGPDFStringGetBytePtr, CGPDFStringGetLength, etc.
//   - CGPDFStreamGetDictionary, CGPDFStreamCopyData
//
// These APIs are intentionally NOT implemented in OpenCoreGraphics because:
//
// 1. **Modern Design Philosophy**: Apple separates concerns:
//    - CoreGraphics: PDF representation types (CGPDFDocument, CGPDFPage)
//    - PDFKit: PDF parsing and rendering functionality
//
// 2. **Implementation Complexity**: Full PDF parsing requires:
//    - PDF file structure parsing (header, xref, trailer)
//    - Object stream handling
//    - Compression/decompression (FlateDecode, LZW, etc.)
//    - Encryption handling (RC4, AES)
//    - Font subsetting and encoding
//
// 3. **API Style**: C-style OpaquePointer APIs with manual Retain/Release
//    are incompatible with Swift's ARC memory management.
//
// For WASM environments requiring PDF functionality, implement a dedicated
// OpenPDFKit module that provides Swift-native PDF parsing capabilities.
//
// The following types are provided for API compatibility:

// MARK: - PDF Primitive Types

/// A PDF Boolean value.
public typealias CGPDFBoolean = UInt8

/// A PDF integer value.
public typealias CGPDFInteger = Int

/// A PDF real value.
public typealias CGPDFReal = CGFloat


#endif
