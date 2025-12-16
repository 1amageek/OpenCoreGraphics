//
//  CGEnumsTests.swift
//  OpenCoreGraphics
//
//  Tests for all enum types and option sets
//

import Foundation
import Testing
@testable import OpenCoreGraphics

// Type aliases to avoid ambiguity with CoreFoundation types on macOS
private typealias CGFloat = OpenCoreGraphics.CGFloat
private typealias CGPoint = OpenCoreGraphics.CGPoint
private typealias CGBlendMode = OpenCoreGraphics.CGBlendMode
private typealias CGLineCap = OpenCoreGraphics.CGLineCap
private typealias CGLineJoin = OpenCoreGraphics.CGLineJoin
private typealias CGPathFillRule = OpenCoreGraphics.CGPathFillRule
private typealias CGPathElementType = OpenCoreGraphics.CGPathElementType
private typealias CGPathDrawingMode = OpenCoreGraphics.CGPathDrawingMode
private typealias CGBitmapInfo = OpenCoreGraphics.CGBitmapInfo
private typealias CGPathElement = OpenCoreGraphics.CGPathElement

// MARK: - CGBlendMode Tests

@Suite("CGBlendMode Tests")
struct CGBlendModeTests {

    @Test("Raw values for basic blend modes")
    func basicBlendModeRawValues() {
        #expect(CGBlendMode.normal.rawValue == 0)
        #expect(CGBlendMode.multiply.rawValue == 1)
        #expect(CGBlendMode.screen.rawValue == 2)
        #expect(CGBlendMode.overlay.rawValue == 3)
        #expect(CGBlendMode.darken.rawValue == 4)
        #expect(CGBlendMode.lighten.rawValue == 5)
    }

    @Test("Raw values for lighting blend modes")
    func lightingBlendModeRawValues() {
        #expect(CGBlendMode.colorDodge.rawValue == 6)
        #expect(CGBlendMode.colorBurn.rawValue == 7)
        #expect(CGBlendMode.softLight.rawValue == 8)
        #expect(CGBlendMode.hardLight.rawValue == 9)
        #expect(CGBlendMode.difference.rawValue == 10)
        #expect(CGBlendMode.exclusion.rawValue == 11)
    }

    @Test("Raw values for component blend modes")
    func componentBlendModeRawValues() {
        #expect(CGBlendMode.hue.rawValue == 12)
        #expect(CGBlendMode.saturation.rawValue == 13)
        #expect(CGBlendMode.color.rawValue == 14)
        #expect(CGBlendMode.luminosity.rawValue == 15)
    }

    @Test("Raw values for Porter-Duff blend modes")
    func porterDuffBlendModeRawValues() {
        #expect(CGBlendMode.clear.rawValue == 16)
        #expect(CGBlendMode.copy.rawValue == 17)
        #expect(CGBlendMode.sourceIn.rawValue == 18)
        #expect(CGBlendMode.sourceOut.rawValue == 19)
        #expect(CGBlendMode.sourceAtop.rawValue == 20)
        #expect(CGBlendMode.destinationOver.rawValue == 21)
        #expect(CGBlendMode.destinationIn.rawValue == 22)
        #expect(CGBlendMode.destinationOut.rawValue == 23)
        #expect(CGBlendMode.destinationAtop.rawValue == 24)
        #expect(CGBlendMode.xor.rawValue == 25)
        #expect(CGBlendMode.plusDarker.rawValue == 26)
        #expect(CGBlendMode.plusLighter.rawValue == 27)
    }

    @Test("Init from raw value")
    func initFromRawValue() {
        #expect(CGBlendMode(rawValue: 0) == .normal)
        #expect(CGBlendMode(rawValue: 1) == .multiply)
        #expect(CGBlendMode(rawValue: 16) == .clear)
        #expect(CGBlendMode(rawValue: 27) == .plusLighter)
        #expect(CGBlendMode(rawValue: 100) == nil)
    }
}

// MARK: - CGLineCap Tests

@Suite("CGLineCap Tests")
struct CGLineCapTests {

    @Test("Raw values")
    func rawValues() {
        #expect(CGLineCap.butt.rawValue == 0)
        #expect(CGLineCap.round.rawValue == 1)
        #expect(CGLineCap.square.rawValue == 2)
    }

    @Test("Init from raw value")
    func initFromRawValue() {
        #expect(CGLineCap(rawValue: 0) == .butt)
        #expect(CGLineCap(rawValue: 1) == .round)
        #expect(CGLineCap(rawValue: 2) == .square)
        #expect(CGLineCap(rawValue: 3) == nil)
    }
}

// MARK: - CGLineJoin Tests

@Suite("CGLineJoin Tests")
struct CGLineJoinTests {

    @Test("Raw values")
    func rawValues() {
        #expect(CGLineJoin.miter.rawValue == 0)
        #expect(CGLineJoin.round.rawValue == 1)
        #expect(CGLineJoin.bevel.rawValue == 2)
    }

    @Test("Init from raw value")
    func initFromRawValue() {
        #expect(CGLineJoin(rawValue: 0) == .miter)
        #expect(CGLineJoin(rawValue: 1) == .round)
        #expect(CGLineJoin(rawValue: 2) == .bevel)
        #expect(CGLineJoin(rawValue: 3) == nil)
    }
}

// MARK: - CGPathFillRule Tests

@Suite("CGPathFillRule Tests")
struct CGPathFillRuleTests {

    @Test("Raw values")
    func rawValues() {
        #expect(CGPathFillRule.winding.rawValue == 0)
        #expect(CGPathFillRule.evenOdd.rawValue == 1)
    }

    @Test("Init from raw value")
    func initFromRawValue() {
        #expect(CGPathFillRule(rawValue: 0) == .winding)
        #expect(CGPathFillRule(rawValue: 1) == .evenOdd)
        #expect(CGPathFillRule(rawValue: 2) == nil)
    }
}

// MARK: - CGPathElementType Tests

@Suite("CGPathElementType Tests")
struct CGPathElementTypeTests {

    @Test("Raw values")
    func rawValues() {
        #expect(CGPathElementType.moveToPoint.rawValue == 0)
        #expect(CGPathElementType.addLineToPoint.rawValue == 1)
        #expect(CGPathElementType.addQuadCurveToPoint.rawValue == 2)
        #expect(CGPathElementType.addCurveToPoint.rawValue == 3)
        #expect(CGPathElementType.closeSubpath.rawValue == 4)
    }

    @Test("Init from raw value")
    func initFromRawValue() {
        #expect(CGPathElementType(rawValue: 0) == .moveToPoint)
        #expect(CGPathElementType(rawValue: 1) == .addLineToPoint)
        #expect(CGPathElementType(rawValue: 2) == .addQuadCurveToPoint)
        #expect(CGPathElementType(rawValue: 3) == .addCurveToPoint)
        #expect(CGPathElementType(rawValue: 4) == .closeSubpath)
        #expect(CGPathElementType(rawValue: 5) == nil)
    }
}

// MARK: - CGPathDrawingMode Tests

@Suite("CGPathDrawingMode Tests")
struct CGPathDrawingModeTests {

    @Test("Raw values")
    func rawValues() {
        #expect(CGPathDrawingMode.fill.rawValue == 0)
        #expect(CGPathDrawingMode.eoFill.rawValue == 1)
        #expect(CGPathDrawingMode.stroke.rawValue == 2)
        #expect(CGPathDrawingMode.fillStroke.rawValue == 3)
        #expect(CGPathDrawingMode.eoFillStroke.rawValue == 4)
    }

    @Test("Init from raw value")
    func initFromRawValue() {
        #expect(CGPathDrawingMode(rawValue: 0) == .fill)
        #expect(CGPathDrawingMode(rawValue: 1) == .eoFill)
        #expect(CGPathDrawingMode(rawValue: 2) == .stroke)
        #expect(CGPathDrawingMode(rawValue: 3) == .fillStroke)
        #expect(CGPathDrawingMode(rawValue: 4) == .eoFillStroke)
        #expect(CGPathDrawingMode(rawValue: 5) == nil)
    }
}

// MARK: - CGBitmapInfo Tests

@Suite("CGBitmapInfo Tests")
struct CGBitmapInfoTests {

    @Suite("Raw Values and Masks")
    struct RawValuesTests {

        @Test("Alpha info mask")
        func alphaInfoMask() {
            #expect(CGBitmapInfo.alphaInfoMask.rawValue == 0x1F)
        }

        @Test("Byte order mask")
        func byteOrderMask() {
            #expect(CGBitmapInfo.byteOrderMask.rawValue == 0x7000)
        }

        @Test("Float info mask")
        func floatInfoMask() {
            #expect(CGBitmapInfo.floatInfoMask.rawValue == 0xF00)
        }

        @Test("Byte order constants")
        func byteOrderConstants() {
            #expect(CGBitmapInfo.byteOrder16Big.rawValue == (3 << 12))
            #expect(CGBitmapInfo.byteOrder32Big.rawValue == (4 << 12))
            #expect(CGBitmapInfo.byteOrder16Little.rawValue == (1 << 12))
            #expect(CGBitmapInfo.byteOrder32Little.rawValue == (2 << 12))
            #expect(CGBitmapInfo.byteOrderDefault.rawValue == 0)
        }

        @Test("Float components")
        func floatComponents() {
            #expect(CGBitmapInfo.floatComponents.rawValue == (1 << 8))
        }
    }

    @Suite("OptionSet Operations")
    struct OptionSetTests {

        @Test("Union of options")
        func unionOptions() {
            let info = CGBitmapInfo([.byteOrder32Little, .floatComponents])
            #expect(info.contains(.byteOrder32Little))
            #expect(info.contains(.floatComponents))
        }

        @Test("isFloatComponents property")
        func isFloatComponentsProperty() {
            let withFloat = CGBitmapInfo.floatComponents
            let withoutFloat = CGBitmapInfo.byteOrder32Little
            #expect(withFloat.isFloatComponents)
            #expect(!withoutFloat.isFloatComponents)
        }
    }
}

// MARK: - CGPathElement Tests

@Suite("CGPathElement Tests")
struct CGPathElementTests {

    @Test("Create path element")
    func createPathElement() {
        var point = CGPoint(x: 10.0, y: 20.0)
        let element = CGPathElement(type: .moveToPoint, points: &point)
        #expect(element.type == .moveToPoint)
        #expect(element.points != nil)
    }

    @Test("Create closeSubpath element")
    func createCloseSubpathElement() {
        let element = CGPathElement(type: .closeSubpath, points: nil)
        #expect(element.type == .closeSubpath)
        #expect(element.points == nil)
    }
}

// MARK: - Sendable Conformance Tests

@Suite("Sendable Conformance")
struct SendableConformanceTests {

    @Test("CGBlendMode is Sendable")
    func blendModeSendable() async {
        let mode = CGBlendMode.normal
        let task = Task {
            return mode
        }
        let result = await task.value
        #expect(result == .normal)
    }

    @Test("CGLineCap is Sendable")
    func lineCapSendable() async {
        let cap = CGLineCap.round
        let task = Task {
            return cap
        }
        let result = await task.value
        #expect(result == .round)
    }

    @Test("CGLineJoin is Sendable")
    func lineJoinSendable() async {
        let join = CGLineJoin.miter
        let task = Task {
            return join
        }
        let result = await task.value
        #expect(result == .miter)
    }

    @Test("CGPathFillRule is Sendable")
    func fillRuleSendable() async {
        let rule = CGPathFillRule.evenOdd
        let task = Task {
            return rule
        }
        let result = await task.value
        #expect(result == .evenOdd)
    }

    @Test("CGPathElementType is Sendable")
    func pathElementTypeSendable() async {
        let type = CGPathElementType.addCurveToPoint
        let task = Task {
            return type
        }
        let result = await task.value
        #expect(result == .addCurveToPoint)
    }

    @Test("CGPathDrawingMode is Sendable")
    func drawingModeSendable() async {
        let mode = CGPathDrawingMode.fillStroke
        let task = Task {
            return mode
        }
        let result = await task.value
        #expect(result == .fillStroke)
    }

    @Test("CGBitmapInfo is Sendable")
    func bitmapInfoSendable() async {
        let info = CGBitmapInfo.byteOrder32Little
        let task = Task {
            return info
        }
        let result = await task.value
        #expect(result == .byteOrder32Little)
    }
}

// MARK: - Edge Case Tests

@Suite("Enum Edge Cases")
struct EnumEdgeCaseTests {

    @Test("All CGBlendMode cases are unique")
    func blendModeCasesUnique() {
        let allCases: [CGBlendMode] = [
            .normal, .multiply, .screen, .overlay, .darken, .lighten,
            .colorDodge, .colorBurn, .softLight, .hardLight, .difference, .exclusion,
            .hue, .saturation, .color, .luminosity,
            .clear, .copy, .sourceIn, .sourceOut, .sourceAtop,
            .destinationOver, .destinationIn, .destinationOut, .destinationAtop,
            .xor, .plusDarker, .plusLighter
        ]
        let uniqueRawValues = Set(allCases.map { $0.rawValue })
        #expect(uniqueRawValues.count == allCases.count)
    }

    @Test("Negative raw values return nil")
    func negativeRawValues() {
        #expect(CGBlendMode(rawValue: -1) == nil)
        #expect(CGLineCap(rawValue: -1) == nil)
        #expect(CGLineJoin(rawValue: -1) == nil)
        #expect(CGPathDrawingMode(rawValue: -1) == nil)
        #expect(CGPathElementType(rawValue: -1) == nil)
    }

    @Test("Large raw values return nil")
    func largeRawValues() {
        #expect(CGBlendMode(rawValue: 1000) == nil)
        #expect(CGLineCap(rawValue: 1000) == nil)
        #expect(CGLineJoin(rawValue: 1000) == nil)
        #expect(CGPathDrawingMode(rawValue: 1000) == nil)
        #expect(CGPathElementType(rawValue: 1000) == nil)
    }
}
