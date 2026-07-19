//
//  CGTypeIdentifierTests.swift
//  OpenCoreGraphics
//

import Testing
@testable import OpenCoreGraphics

@Suite("CG Type Identifier Tests")
struct CGTypeIdentifierTests {
    @Test("Reference type identifiers are stable, nonzero, and unique")
    func identifiers() {
        let identifiers: [UInt] = [
            OpenCoreGraphics.CGColorSpace.typeID,
            OpenCoreGraphics.CGDataProvider.typeID,
            OpenCoreGraphics.CGDataConsumer.typeID,
            OpenCoreGraphics.CGImage.typeID,
            OpenCoreGraphics.CGGradient.typeID,
            OpenCoreGraphics.CGFunction.typeID,
            OpenCoreGraphics.CGShading.typeID,
            OpenCoreGraphics.CGPattern.typeID,
            OpenCoreGraphics.CGFont.typeID,
            OpenCoreGraphics.CGColorConversionInfo.typeID,
            OpenCoreGraphics.CGPDFDocument.typeID,
            OpenCoreGraphics.CGPDFPage.typeID
        ]

        #expect(identifiers.allSatisfy { $0 != 0 })
        #expect(Set(identifiers).count == identifiers.count)
    }
}
