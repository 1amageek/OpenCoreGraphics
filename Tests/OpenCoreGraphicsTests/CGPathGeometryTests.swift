//
//  CGPathGeometryTests.swift
//  OpenCoreGraphicsTests
//

import Foundation
import Testing
@testable import OpenCoreGraphics

@Suite("CGPath exact geometry")
struct CGPathGeometryTests {
    @Test("Control-point and tight curve bounds have distinct semantics")
    func curveBounds() {
        let quadratic = OpenCoreGraphics.CGMutablePath()
        quadratic.move(to: .init(x: 0, y: 0))
        quadratic.addQuadCurve(to: .init(x: 100, y: 0), control: .init(x: 50, y: 100))
        #expect(quadratic.boundingBox == CGRect(x: 0, y: 0, width: 100, height: 100))
        #expect(quadratic.boundingBoxOfPath == CGRect(x: 0, y: 0, width: 100, height: 50))

        let cubic = OpenCoreGraphics.CGMutablePath()
        cubic.move(to: .init(x: 0, y: 0))
        cubic.addCurve(
            to: .init(x: 100, y: 0),
            control1: .init(x: 0, y: 100),
            control2: .init(x: 100, y: 100)
        )
        #expect(cubic.boundingBox == CGRect(x: 0, y: 0, width: 100, height: 100))
        #expect(cubic.boundingBoxOfPath == CGRect(x: 0, y: 0, width: 100, height: 75))
    }

    @Test("Elements requiring a current point do not synthesize an origin")
    func elementsWithoutCurrentPoint() {
        let line = OpenCoreGraphics.CGMutablePath()
        line.addLine(to: .init(x: 10, y: 20))
        #expect(line.isEmpty)

        let quadratic = OpenCoreGraphics.CGMutablePath()
        quadratic.addQuadCurve(to: .init(x: 10, y: 20), control: .init(x: 5, y: 30))
        #expect(quadratic.isEmpty)

        let cubic = OpenCoreGraphics.CGMutablePath()
        cubic.addCurve(
            to: .init(x: 10, y: 20),
            control1: .init(x: 2, y: 3),
            control2: .init(x: 7, y: 8)
        )
        #expect(cubic.isEmpty)

        let closed = OpenCoreGraphics.CGMutablePath()
        closed.closeSubpath()
        #expect(closed.isEmpty)
    }

    @Test("Miter limit changes only corners that exceed the ratio")
    func miterLimit() {
        let path = OpenCoreGraphics.CGMutablePath()
        path.addLines(between: [
            .init(x: 0, y: 0),
            .init(x: 30, y: 0),
            .init(x: 13, y: 8),
        ])
        let bevelled = path.copy(
            strokingWithWidth: 10,
            lineCap: .butt,
            lineJoin: .miter,
            miterLimit: 1
        )
        let mitered = path.copy(
            strokingWithWidth: 10,
            lineCap: .butt,
            lineJoin: .miter,
            miterLimit: 10
        )
        #expect(mitered.boundingBoxOfPath.maxX > bevelled.boundingBoxOfPath.maxX + 10)
        #expect(mitered.contains(.init(x: 40, y: -3)))
        #expect(!bevelled.contains(.init(x: 40, y: -3)))
    }

    @Test("Stroke transform applies to the completed outline")
    func strokeTransform() {
        let path = OpenCoreGraphics.CGMutablePath()
        path.move(to: .zero)
        path.addLine(to: .init(x: 10, y: 0))
        let stroke = path.copy(
            strokingWithWidth: 2,
            lineCap: .butt,
            lineJoin: .miter,
            miterLimit: 10,
            transform: .init(scaleX: 1, y: 2)
        )
        #expect(stroke.boundingBoxOfPath == CGRect(x: 0, y: -2, width: 10, height: 4))
    }

    @Test("Degenerate strokes preserve cap geometry")
    func degenerateStrokes() {
        let path = OpenCoreGraphics.CGMutablePath()
        path.move(to: .init(x: 2, y: 3))
        path.closeSubpath()

        let butt = path.copy(
            strokingWithWidth: 10,
            lineCap: .butt,
            lineJoin: .miter,
            miterLimit: 10
        )
        #expect(butt.boundingBoxOfPath.isNull)

        let round = path.copy(
            strokingWithWidth: 10,
            lineCap: .round,
            lineJoin: .miter,
            miterLimit: 10
        )
        let roundBounds = round.boundingBoxOfPath
        #expect(abs(roundBounds.minX + 3) <= 1e-12)
        #expect(abs(roundBounds.minY + 2) <= 1e-12)
        #expect(abs(roundBounds.width - 10) <= 1e-12)
        #expect(abs(roundBounds.height - 10) <= 1e-12)

        let square = path.copy(
            strokingWithWidth: 10,
            lineCap: .square,
            lineJoin: .miter,
            miterLimit: 10
        )
        let radius = CGFloat(5) * sqrt(2)
        #expect(square.boundingBoxOfPath == CGRect(
            x: 2 - radius,
            y: 3 - radius,
            width: radius * 2,
            height: radius * 2
        ))
    }

    @Test("Stroke outlines have equivalent winding and even-odd coverage")
    func strokeOutlineFillRules() {
        let path = OpenCoreGraphics.CGMutablePath()
        path.move(to: .zero)
        path.addLine(to: .init(x: 10, y: 0))
        path.addLine(to: .init(x: 10, y: 10))

        for join in [OpenCoreGraphics.CGLineJoin.miter, .round, .bevel] {
            let stroke = path.copy(
                strokingWithWidth: 4,
                lineCap: .round,
                lineJoin: join,
                miterLimit: 10
            )
            for point in [
                CGPoint(x: 9, y: 1),
                CGPoint(x: 10.75, y: -0.75),
                CGPoint(x: 0, y: 0),
                CGPoint(x: 10, y: 8),
            ] {
                #expect(stroke.contains(point, using: .winding))
                #expect(stroke.contains(point, using: .evenOdd))
            }
        }
    }
}
