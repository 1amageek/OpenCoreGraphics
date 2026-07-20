//
//  CGPathGeometryExternalConformanceTests.swift
//  OpenCoreGraphicsTests
//

#if canImport(CoreGraphics)
import CoreGraphics
import Foundation
import Testing
@testable import OpenCoreGraphics

@Suite("CGPath geometry external conformance tests")
struct CGPathGeometryExternalConformanceTests {
    @Test("Curve bounding boxes agree with Core Graphics")
    func curveBoundingBoxes() {
        let openPath = OpenCoreGraphics.CGMutablePath()
        let applePath = CoreGraphics.CGMutablePath()
        openPath.move(to: .init(x: 0, y: 0))
        applePath.move(to: .init(x: 0, y: 0))
        openPath.addQuadCurve(to: .init(x: 100, y: 0), control: .init(x: 50, y: 100))
        applePath.addQuadCurve(to: .init(x: 100, y: 0), control: .init(x: 50, y: 100))
        openPath.addCurve(
            to: .init(x: 200, y: 0),
            control1: .init(x: 100, y: -120),
            control2: .init(x: 200, y: 120)
        )
        applePath.addCurve(
            to: .init(x: 200, y: 0),
            control1: .init(x: 100, y: -120),
            control2: .init(x: 200, y: 120)
        )

        Self.expectBounds(openPath.boundingBox, applePath.boundingBox, tolerance: 1e-10)
        Self.expectBounds(openPath.boundingBoxOfPath, applePath.boundingBoxOfPath, tolerance: 1e-8)
        #expect(openPath.boundingBox != openPath.boundingBoxOfPath)
    }

    @Test("Line caps agree with Core Graphics coverage")
    func lineCaps() {
        for cap in [OpenCoreGraphics.CGLineCap.butt, .round, .square] {
            let openPath = OpenCoreGraphics.CGMutablePath()
            let applePath = CoreGraphics.CGMutablePath()
            openPath.move(to: .init(x: 0, y: 0))
            applePath.move(to: .init(x: 0, y: 0))
            openPath.addLine(to: .init(x: 30, y: 10))
            applePath.addLine(to: .init(x: 30, y: 10))

            let openStroke = openPath.copy(
                strokingWithWidth: 10,
                lineCap: cap,
                lineJoin: .miter,
                miterLimit: 10
            )
            let appleStroke = applePath.copy(
                strokingWithWidth: 10,
                lineCap: Self.appleCap(cap),
                lineJoin: .miter,
                miterLimit: 10
            )
            Self.expectEquivalentCoverage(openStroke, appleStroke, label: "cap \(cap.rawValue)")
        }
    }

    @Test("Line joins and miter limits agree with Core Graphics coverage")
    func lineJoins() {
        for join in [OpenCoreGraphics.CGLineJoin.miter, .round, .bevel] {
            for miterLimit: Foundation.CGFloat in [1, 10] {
                let openPath = OpenCoreGraphics.CGMutablePath()
                let applePath = CoreGraphics.CGMutablePath()
                let points = [
                    Foundation.CGPoint(x: 0, y: 0),
                    Foundation.CGPoint(x: 30, y: 0),
                    Foundation.CGPoint(x: 13, y: 8),
                ]
                openPath.addLines(between: points)
                applePath.addLines(between: points)

                let openStroke = openPath.copy(
                    strokingWithWidth: 10,
                    lineCap: .butt,
                    lineJoin: join,
                    miterLimit: miterLimit
                )
                let appleStroke = applePath.copy(
                    strokingWithWidth: 10,
                    lineCap: .butt,
                    lineJoin: Self.appleJoin(join),
                    miterLimit: miterLimit
                )
                Self.expectEquivalentCoverage(
                    openStroke,
                    appleStroke,
                    label: "join \(join.rawValue), miter \(miterLimit)"
                )
            }
        }
    }

    @Test("Closed and curved strokes agree with Core Graphics coverage")
    func closedAndCurvedStrokes() {
        let openPath = OpenCoreGraphics.CGMutablePath()
        let applePath = CoreGraphics.CGMutablePath()
        openPath.move(to: .init(x: 0, y: 0))
        applePath.move(to: .init(x: 0, y: 0))
        openPath.addCurve(
            to: .init(x: 40, y: 0),
            control1: .init(x: 5, y: 35),
            control2: .init(x: 35, y: -25)
        )
        applePath.addCurve(
            to: .init(x: 40, y: 0),
            control1: .init(x: 5, y: 35),
            control2: .init(x: 35, y: -25)
        )
        openPath.addLine(to: .init(x: 20, y: 30))
        applePath.addLine(to: .init(x: 20, y: 30))
        openPath.closeSubpath()
        applePath.closeSubpath()

        let openStroke = openPath.copy(
            strokingWithWidth: 6,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 10
        )
        let appleStroke = applePath.copy(
            strokingWithWidth: 6,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 10
        )
        Self.expectEquivalentCoverage(openStroke, appleStroke, spacing: 1.5, label: "closed curve")
    }

    @Test("Dashing and transforms agree with Core Graphics coverage")
    func dashingAndTransforms() {
        let openPath = OpenCoreGraphics.CGMutablePath()
        let applePath = CoreGraphics.CGMutablePath()
        openPath.move(to: .init(x: 0, y: 0))
        applePath.move(to: .init(x: 0, y: 0))
        openPath.addQuadCurve(to: .init(x: 40, y: 0), control: .init(x: 20, y: 30))
        applePath.addQuadCurve(to: .init(x: 40, y: 0), control: .init(x: 20, y: 30))

        let openTransform = OpenCoreGraphics.CGAffineTransform(
            a: 1.25,
            b: 0.2,
            c: -0.15,
            d: 0.8,
            tx: 5,
            ty: -3
        )
        let appleTransform = CoreGraphics.CGAffineTransform(
            a: 1.25,
            b: 0.2,
            c: -0.15,
            d: 0.8,
            tx: 5,
            ty: -3
        )
        let openDashed = openPath.copy(
            dashingWithPhase: 1.75,
            lengths: [5, 2, 1],
            transform: openTransform
        )
        let appleDashed = applePath.copy(
            dashingWithPhase: 1.75,
            lengths: [5, 2, 1],
            transform: appleTransform
        )
        let openStroke = openDashed.copy(
            strokingWithWidth: 3,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 10
        )
        let appleStroke = appleDashed.copy(
            strokingWithWidth: 3,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 10
        )
        Self.expectEquivalentCoverage(openStroke, appleStroke, spacing: 1, label: "dashed transform")
    }

    @Test("Degenerate cap geometry agrees with Core Graphics")
    func degenerateCaps() {
        for cap in [OpenCoreGraphics.CGLineCap.butt, .round, .square] {
            let openPath = OpenCoreGraphics.CGMutablePath()
            let applePath = CoreGraphics.CGMutablePath()
            openPath.move(to: .init(x: 2, y: 3))
            applePath.move(to: .init(x: 2, y: 3))
            openPath.closeSubpath()
            applePath.closeSubpath()

            let openStroke = openPath.copy(
                strokingWithWidth: 10,
                lineCap: cap,
                lineJoin: .miter,
                miterLimit: 10
            )
            let appleStroke = applePath.copy(
                strokingWithWidth: 10,
                lineCap: Self.appleCap(cap),
                lineJoin: .miter,
                miterLimit: 10
            )
            let openBounds = openStroke.boundingBoxOfPath
            let appleBounds = appleStroke.boundingBoxOfPath
            #expect(Self.isNullBounds(openBounds) == Self.isNullBounds(appleBounds))
            if !Self.isNullBounds(appleBounds) {
                Self.expectEquivalentCoverage(
                    openStroke,
                    appleStroke,
                    spacing: 0.5,
                    label: "degenerate cap \(cap.rawValue)"
                )
            }
        }
    }

    private static func expectEquivalentCoverage(
        _ openPath: OpenCoreGraphics.CGPath,
        _ applePath: CoreGraphics.CGPath,
        spacing: Foundation.CGFloat = 1,
        label: String
    ) {
        let openBounds = Self.values(openPath.boundingBoxOfPath)
        let appleBounds = Self.values(applePath.boundingBoxOfPath)
        Self.expectBounds(openPath.boundingBoxOfPath, applePath.boundingBoxOfPath, tolerance: 0.08)
        let minimumX = min(openBounds[0], appleBounds[0]) - 2
        let minimumY = min(openBounds[1], appleBounds[1]) - 2
        let maximumX = max(openBounds[2], appleBounds[2]) + 2
        let maximumY = max(openBounds[3], appleBounds[3]) + 2
        var y = minimumY + 0.371
        while y < maximumY {
            var x = minimumX + 0.613
            while x < maximumX {
                let point = Foundation.CGPoint(x: x, y: y)
                for rule in [OpenCoreGraphics.CGPathFillRule.winding, .evenOdd] {
                    let openContains = openPath.contains(point, using: rule)
                    let appleContains = applePath.contains(point, using: Self.appleRule(rule))
                    if openContains != appleContains {
                        #expect(
                            Self.isNearBoundary(
                                point,
                                openPath: openPath,
                                applePath: applePath,
                                rule: rule
                            ),
                            "\(label) coverage differs away from the approximation tolerance at \(point)"
                        )
                    }
                }
                x += spacing
            }
            y += spacing
        }
    }

    private static func isNearBoundary(
        _ point: Foundation.CGPoint,
        openPath: OpenCoreGraphics.CGPath,
        applePath: CoreGraphics.CGPath,
        rule: OpenCoreGraphics.CGPathFillRule
    ) -> Bool {
        let distance: Foundation.CGFloat = 0.08
        let offsets: [(Foundation.CGFloat, Foundation.CGFloat)] = [
            (-distance, 0), (distance, 0), (0, -distance), (0, distance),
            (-distance, -distance), (-distance, distance),
            (distance, -distance), (distance, distance),
        ]
        let openCenter = openPath.contains(point, using: rule)
        let appleRule = Self.appleRule(rule)
        let appleCenter = applePath.contains(point, using: appleRule)
        for offset in offsets {
            let sample = Foundation.CGPoint(x: point.x + offset.0, y: point.y + offset.1)
            if openPath.contains(sample, using: rule) != openCenter
                || applePath.contains(sample, using: appleRule) != appleCenter {
                return true
            }
        }
        return false
    }

    private static func expectBounds(
        _ openBounds: Foundation.CGRect,
        _ appleBounds: Foundation.CGRect,
        tolerance: Foundation.CGFloat
    ) {
        let openValues = Self.values(openBounds)
        let appleValues = Self.values(appleBounds)
        for (openValue, appleValue) in zip(openValues, appleValues) {
            #expect(
                abs(openValue - appleValue) <= tolerance,
                "Open bound \(openValue) differs from Core Graphics bound \(appleValue)"
            )
        }
    }

    private static func values(_ rect: Foundation.CGRect) -> [Foundation.CGFloat] {
        let minimumX = rect.origin.x
        let minimumY = rect.origin.y
        return [
            minimumX,
            minimumY,
            minimumX + rect.size.width,
            minimumY + rect.size.height,
        ]
    }

    private static func isNullBounds(_ rect: Foundation.CGRect) -> Bool {
        rect.origin.x.isNaN
            || rect.origin.y.isNaN
            || rect.size.width.isNaN
            || rect.size.height.isNaN
            || (rect.origin.x == .infinity && rect.origin.y == .infinity)
    }

    private static func appleCap(_ cap: OpenCoreGraphics.CGLineCap) -> CoreGraphics.CGLineCap {
        switch cap {
        case .butt: .butt
        case .round: .round
        case .square: .square
        }
    }

    private static func appleJoin(_ join: OpenCoreGraphics.CGLineJoin) -> CoreGraphics.CGLineJoin {
        switch join {
        case .miter: .miter
        case .round: .round
        case .bevel: .bevel
        }
    }

    private static func appleRule(
        _ rule: OpenCoreGraphics.CGPathFillRule
    ) -> CoreGraphics.CGPathFillRule {
        switch rule {
        case .winding: .winding
        case .evenOdd: .evenOdd
        }
    }
}
#endif
