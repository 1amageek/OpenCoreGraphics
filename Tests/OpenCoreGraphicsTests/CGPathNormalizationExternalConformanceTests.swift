//
//  CGPathNormalizationExternalConformanceTests.swift
//  OpenCoreGraphicsTests
//

#if canImport(CoreGraphics)
import CoreGraphics
import Foundation
import Testing
@testable import OpenCoreGraphics

@Suite("CGPath normalization external conformance tests")
struct CGPathNormalizationExternalConformanceTests {
    @Test("Nested contours normalize like Apple Core Graphics for both fill rules")
    func nestedContourNormalization() {
        let openPath = OpenCoreGraphics.CGMutablePath()
        let applePath = CoreGraphics.CGMutablePath()
        Self.addRect(
            Foundation.CGRect(x: 0, y: 0, width: 10, height: 10),
            clockwise: false,
            openPath: openPath,
            applePath: applePath
        )
        Self.addRect(
            Foundation.CGRect(x: 2, y: 2, width: 6, height: 6),
            clockwise: false,
            openPath: openPath,
            applePath: applePath
        )

        Self.expectEquivalentNormalization(openPath, applePath, evenOdd: false)
        Self.expectEquivalentNormalization(openPath, applePath, evenOdd: true)
    }

    @Test("Component separation agrees with Apple for holes and filled islands")
    func componentSeparation() {
        let openPath = OpenCoreGraphics.CGMutablePath()
        let applePath = CoreGraphics.CGMutablePath()
        for fixture in [
            (Foundation.CGRect(x: 0, y: 0, width: 20, height: 20), false),
            (Foundation.CGRect(x: 3, y: 3, width: 14, height: 14), true),
            (Foundation.CGRect(x: 7, y: 7, width: 6, height: 6), false),
            (Foundation.CGRect(x: 30, y: 0, width: 5, height: 5), false),
        ] {
            Self.addRect(
                fixture.0,
                clockwise: fixture.1,
                openPath: openPath,
                applePath: applePath
            )
        }

        let openComponents = openPath.componentsSeparated(using: .winding)
        let appleComponents = applePath.componentsSeparated(using: .winding)
        #expect(openComponents.count == appleComponents.count)

        let samples = [
            Foundation.CGPoint(x: 1, y: 1), Foundation.CGPoint(x: 5, y: 5),
            Foundation.CGPoint(x: 10, y: 10), Foundation.CGPoint(x: 32, y: 2),
        ]
        let openSignatures = openComponents.map { component in
            samples.map { component.contains($0, using: .winding) }
        }.sorted { $0.lexicographicallyPrecedes($1, by: { !$0 && $1 }) }
        let appleSignatures = appleComponents.map { component in
            samples.map { component.contains($0, using: .winding) }
        }.sorted { $0.lexicographicallyPrecedes($1, by: { !$0 && $1 }) }
        #expect(openSignatures == appleSignatures)
    }

    private static func expectEquivalentNormalization(
        _ openPath: OpenCoreGraphics.CGPath,
        _ applePath: CoreGraphics.CGPath,
        evenOdd: Bool
    ) {
        let openRule: OpenCoreGraphics.CGPathFillRule = evenOdd ? .evenOdd : .winding
        let appleRule: CoreGraphics.CGPathFillRule = evenOdd ? .evenOdd : .winding
        let openNormalized = openPath.normalized(using: openRule)
        let appleNormalized = applePath.normalized(using: appleRule)
        let samples: [Foundation.CGPoint] = [
            Foundation.CGPoint(x: 1, y: 1),
            Foundation.CGPoint(x: 5, y: 5),
            Foundation.CGPoint(x: 12, y: 12),
        ]
        for point in samples {
            #expect(
                openNormalized.contains(point, using: .winding)
                    == appleNormalized.contains(point, using: .winding)
            )
        }
        #expect(openNormalized.commands.count == Self.elementCount(appleNormalized))
    }

    private static func addRect(
        _ rect: Foundation.CGRect,
        clockwise: Bool,
        openPath: OpenCoreGraphics.CGMutablePath,
        applePath: CoreGraphics.CGMutablePath
    ) {
        let minimumX = Double(rect.origin.x)
        let minimumY = Double(rect.origin.y)
        let maximumX = minimumX + Double(rect.size.width)
        let maximumY = minimumY + Double(rect.size.height)
        let counterclockwise: [(Double, Double)] = [
            (minimumX, minimumY),
            (maximumX, minimumY),
            (maximumX, maximumY),
            (minimumX, maximumY),
        ]
        let points = clockwise ? Array(counterclockwise.reversed()) : counterclockwise
        guard let first = points.first else { return }
        openPath.move(to: .init(x: first.0, y: first.1))
        applePath.move(to: .init(x: first.0, y: first.1))
        for point in points.dropFirst() {
            openPath.addLine(to: .init(x: point.0, y: point.1))
            applePath.addLine(to: .init(x: point.0, y: point.1))
        }
        openPath.closeSubpath()
        applePath.closeSubpath()
    }

    private static func elementCount(_ path: CoreGraphics.CGPath) -> Int {
        var count = 0
        path.applyWithBlock { _ in count += 1 }
        return count
    }
}
#endif
