//
//  CGTypeIdentifier.swift
//  OpenCoreGraphics
//

/// Stable, nonzero identifiers for Core Graphics reference types.
internal enum CGTypeIdentifier {
    static let colorSpace: UInt = 1
    static let dataProvider: UInt = 2
    static let dataConsumer: UInt = 3
    static let image: UInt = 4
    static let gradient: UInt = 5
    static let function: UInt = 6
    static let shading: UInt = 7
    static let pattern: UInt = 8
    static let font: UInt = 9
    static let colorConversionInfo: UInt = 10
    static let pdfDocument: UInt = 11
    static let pdfPage: UInt = 12
}
