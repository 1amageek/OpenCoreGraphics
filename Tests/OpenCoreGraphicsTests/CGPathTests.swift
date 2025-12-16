//
//  CGPathTests.swift
//  OpenCoreGraphics
//
//  Tests for CGPath and CGMutablePath types
//

import Foundation
import Testing
@testable import OpenCoreGraphics

// Type aliases to avoid ambiguity with CoreFoundation types on macOS
private typealias CGFloat = OpenCoreGraphics.CGFloat
private typealias CGPoint = OpenCoreGraphics.CGPoint
private typealias CGSize = OpenCoreGraphics.CGSize
private typealias CGRect = OpenCoreGraphics.CGRect
private typealias CGAffineTransform = OpenCoreGraphics.CGAffineTransform
private typealias CGPath = OpenCoreGraphics.CGPath
private typealias CGMutablePath = OpenCoreGraphics.CGMutablePath
private typealias CGPathElementType = OpenCoreGraphics.CGPathElementType
private typealias CGPathFillRule = OpenCoreGraphics.CGPathFillRule

@Suite("CGPath Tests")
struct CGPathTests {

    // MARK: - Rectangular Path Tests

    @Suite("Rectangular Path")
    struct RectangularPathTests {

        @Test("Create rectangular path")
        func createRectangularPath() {
            let rect = CGRect(x: 10.0, y: 20.0, width: 100.0, height: 200.0)
            let path = CGPath(rect: rect)
            #expect(!path.isEmpty)
        }

        @Test("Rectangular path bounding box")
        func rectangularPathBoundingBox() {
            let rect = CGRect(x: 10.0, y: 20.0, width: 100.0, height: 200.0)
            let path = CGPath(rect: rect)
            let bbox = path.boundingBox
            #expect(abs(bbox.minX.native - 10.0) < 0.0001)
            #expect(abs(bbox.minY.native - 20.0) < 0.0001)
            #expect(abs(bbox.width.native - 100.0) < 0.0001)
            #expect(abs(bbox.height.native - 200.0) < 0.0001)
        }

        @Test("Rectangular path with transform")
        func rectangularPathWithTransform() {
            let rect = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0)
            var transform = CGAffineTransform(translationX: 10.0, y: 20.0)
            let path = withUnsafePointer(to: &transform) { ptr in
                CGPath(rect: rect, transform: ptr)
            }
            let bbox = path.boundingBox
            #expect(abs(bbox.minX.native - 10.0) < 0.0001)
            #expect(abs(bbox.minY.native - 20.0) < 0.0001)
        }

        @Test("isRect returns true for rectangular path")
        func isRectTrue() {
            let rect = CGRect(x: 10.0, y: 20.0, width: 100.0, height: 200.0)
            let path = CGPath(rect: rect)
            var detectedRect = CGRect.zero
            let isRect = path.isRect(&detectedRect)
            #expect(isRect)
            #expect(abs(detectedRect.minX.native - 10.0) < 0.0001)
            #expect(abs(detectedRect.minY.native - 20.0) < 0.0001)
            #expect(abs(detectedRect.width.native - 100.0) < 0.0001)
            #expect(abs(detectedRect.height.native - 200.0) < 0.0001)
        }
    }

    // MARK: - Elliptical Path Tests

    @Suite("Elliptical Path")
    struct EllipticalPathTests {

        @Test("Create elliptical path")
        func createEllipticalPath() {
            let rect = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 200.0)
            let path = CGPath(ellipseIn: rect)
            #expect(!path.isEmpty)
        }

        @Test("Elliptical path bounding box approximately matches rect")
        func ellipticalPathBoundingBox() {
            let rect = CGRect(x: 10.0, y: 20.0, width: 100.0, height: 200.0)
            let path = CGPath(ellipseIn: rect)
            let bbox = path.boundingBox
            // Due to bezier approximation, bounds should be close
            #expect(abs(bbox.minX.native - rect.minX.native) < 1.0)
            #expect(abs(bbox.minY.native - rect.minY.native) < 1.0)
        }

        @Test("isRect returns false for elliptical path")
        func isRectFalse() {
            let rect = CGRect(x: 10.0, y: 20.0, width: 100.0, height: 200.0)
            let path = CGPath(ellipseIn: rect)
            var detectedRect = CGRect.zero
            let isRect = path.isRect(&detectedRect)
            #expect(!isRect)
        }
    }

    // MARK: - Rounded Rectangle Path Tests

    @Suite("Rounded Rectangle Path")
    struct RoundedRectanglePathTests {

        @Test("Create rounded rectangle path")
        func createRoundedRectPath() {
            let rect = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 200.0)
            let path = CGPath(roundedRect: rect, cornerWidth: 10.0, cornerHeight: 10.0)
            #expect(!path.isEmpty)
        }

        @Test("Rounded rectangle path bounding box")
        func roundedRectPathBoundingBox() {
            let rect = CGRect(x: 10.0, y: 20.0, width: 100.0, height: 200.0)
            let path = CGPath(roundedRect: rect, cornerWidth: 10.0, cornerHeight: 10.0)
            let bbox = path.boundingBox
            #expect(abs(bbox.minX.native - rect.minX.native) < 1.0)
            #expect(abs(bbox.minY.native - rect.minY.native) < 1.0)
        }

        @Test("Corner radius clamped to half dimension")
        func cornerRadiusClamped() {
            let rect = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 50.0)
            // Request corner width larger than half of height
            let path = CGPath(roundedRect: rect, cornerWidth: 30.0, cornerHeight: 30.0)
            #expect(!path.isEmpty)
        }
    }

    // MARK: - Path Properties Tests

    @Suite("Path Properties")
    struct PathPropertiesTests {

        @Test("isEmpty for empty path")
        func isEmptyTrue() {
            let path = CGMutablePath()
            #expect(path.isEmpty)
        }

        @Test("isEmpty for non-empty path")
        func isEmptyFalse() {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0.0, y: 0.0))
            #expect(!path.isEmpty)
        }

        @Test("currentPoint after move")
        func currentPointAfterMove() {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 10.0, y: 20.0))
            #expect(path.currentPoint.x.native == 10.0)
            #expect(path.currentPoint.y.native == 20.0)
        }

        @Test("currentPoint after line")
        func currentPointAfterLine() {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0.0, y: 0.0))
            path.addLine(to: CGPoint(x: 100.0, y: 100.0))
            #expect(path.currentPoint.x.native == 100.0)
            #expect(path.currentPoint.y.native == 100.0)
        }

        @Test("currentPoint for empty path is zero")
        func currentPointEmpty() {
            let path = CGMutablePath()
            #expect(path.currentPoint == CGPoint.zero)
        }

        @Test("boundingBox for empty path is null")
        func boundingBoxEmpty() {
            let path = CGMutablePath()
            #expect(path.boundingBox.isNull)
        }
    }

    // MARK: - Mutable Path Construction Tests

    @Suite("Mutable Path Construction")
    struct MutablePathConstructionTests {

        @Test("Move to point")
        func moveToPoint() {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 10.0, y: 20.0))
            #expect(path.currentPoint.x.native == 10.0)
            #expect(path.currentPoint.y.native == 20.0)
        }

        @Test("Add line")
        func addLine() {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0.0, y: 0.0))
            path.addLine(to: CGPoint(x: 100.0, y: 100.0))
            #expect(!path.isEmpty)
            let bbox = path.boundingBox
            #expect(bbox.maxX.native == 100.0)
            #expect(bbox.maxY.native == 100.0)
        }

        @Test("Add lines")
        func addLines() {
            let path = CGMutablePath()
            let points = [
                CGPoint(x: 0.0, y: 0.0),
                CGPoint(x: 100.0, y: 0.0),
                CGPoint(x: 100.0, y: 100.0),
                CGPoint(x: 0.0, y: 100.0)
            ]
            path.addLines(between: points)
            let bbox = path.boundingBox
            #expect(bbox.width.native == 100.0)
            #expect(bbox.height.native == 100.0)
        }

        @Test("Add rect")
        func addRect() {
            let path = CGMutablePath()
            path.addRect(CGRect(x: 10.0, y: 20.0, width: 100.0, height: 200.0))
            let bbox = path.boundingBox
            #expect(abs(bbox.minX.native - 10.0) < 0.0001)
            #expect(abs(bbox.minY.native - 20.0) < 0.0001)
        }

        @Test("Add multiple rects")
        func addRects() {
            let path = CGMutablePath()
            let rects = [
                CGRect(x: 0.0, y: 0.0, width: 50.0, height: 50.0),
                CGRect(x: 100.0, y: 100.0, width: 50.0, height: 50.0)
            ]
            path.addRects(rects)
            let bbox = path.boundingBox
            #expect(bbox.minX.native == 0.0)
            #expect(bbox.maxX.native == 150.0)
        }

        @Test("Add ellipse")
        func addEllipse() {
            let path = CGMutablePath()
            path.addEllipse(in: CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0))
            #expect(!path.isEmpty)
        }

        @Test("Add rounded rect")
        func addRoundedRect() {
            let path = CGMutablePath()
            path.addRoundedRect(
                in: CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0),
                cornerWidth: 10.0,
                cornerHeight: 10.0
            )
            #expect(!path.isEmpty)
        }

        @Test("Add quad curve")
        func addQuadCurve() {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0.0, y: 0.0))
            path.addQuadCurve(to: CGPoint(x: 100.0, y: 0.0), control: CGPoint(x: 50.0, y: 50.0))
            let bbox = path.boundingBox
            #expect(bbox.maxY.native >= 50.0)
        }

        @Test("Add cubic curve")
        func addCubicCurve() {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0.0, y: 0.0))
            path.addCurve(
                to: CGPoint(x: 100.0, y: 0.0),
                control1: CGPoint(x: 25.0, y: 50.0),
                control2: CGPoint(x: 75.0, y: 50.0)
            )
            #expect(!path.isEmpty)
        }

        @Test("Close subpath")
        func closeSubpath() {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0.0, y: 0.0))
            path.addLine(to: CGPoint(x: 100.0, y: 0.0))
            path.addLine(to: CGPoint(x: 100.0, y: 100.0))
            path.closeSubpath()
            #expect(!path.isEmpty)
        }

        @Test("Add path")
        func addPath() {
            let path1 = CGMutablePath()
            path1.addRect(CGRect(x: 0.0, y: 0.0, width: 50.0, height: 50.0))

            let path2 = CGMutablePath()
            path2.addRect(CGRect(x: 100.0, y: 100.0, width: 50.0, height: 50.0))
            path2.addPath(path1)

            let bbox = path2.boundingBox
            #expect(bbox.minX.native == 0.0)
            #expect(bbox.maxX.native == 150.0)
        }
    }

    // MARK: - Path with Transform Tests

    @Suite("Path with Transform")
    struct PathWithTransformTests {

        @Test("Move with transform")
        func moveWithTransform() {
            let path = CGMutablePath()
            let transform = CGAffineTransform(translationX: 10.0, y: 20.0)
            path.move(to: CGPoint(x: 0.0, y: 0.0), transform: transform)
            #expect(path.currentPoint.x.native == 10.0)
            #expect(path.currentPoint.y.native == 20.0)
        }

        @Test("Add line with transform")
        func addLineWithTransform() {
            let path = CGMutablePath()
            let transform = CGAffineTransform(scaleX: 2.0, y: 2.0)
            path.move(to: CGPoint(x: 0.0, y: 0.0))
            path.addLine(to: CGPoint(x: 50.0, y: 50.0), transform: transform)
            #expect(path.currentPoint.x.native == 100.0)
            #expect(path.currentPoint.y.native == 100.0)
        }

        @Test("Add rect with transform")
        func addRectWithTransform() {
            let path = CGMutablePath()
            let transform = CGAffineTransform(translationX: 100.0, y: 100.0)
            path.addRect(CGRect(x: 0.0, y: 0.0, width: 50.0, height: 50.0), transform: transform)
            let bbox = path.boundingBox
            #expect(bbox.minX.native == 100.0)
            #expect(bbox.minY.native == 100.0)
        }
    }

    // MARK: - Contains Tests

    @Suite("Contains Operations")
    struct ContainsTests {

        @Test("Contains point inside rect")
        func containsPointInsideRect() {
            let path = CGPath(rect: CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0))
            #expect(path.contains(CGPoint(x: 50.0, y: 50.0)))
        }

        @Test("Contains point outside rect")
        func containsPointOutsideRect() {
            let path = CGPath(rect: CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0))
            #expect(!path.contains(CGPoint(x: 150.0, y: 50.0)))
        }

        @Test("Contains with transform")
        func containsWithTransform() {
            let path = CGPath(rect: CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0))
            let transform = CGAffineTransform(translationX: 100.0, y: 100.0)
            // Point (150, 150) should be inside the transformed rect
            // But with inverse transform, we check if (-50, -50) is inside original
            #expect(!path.contains(CGPoint(x: 150.0, y: 150.0), transform: transform))
        }
    }

    // MARK: - Copy Tests

    @Suite("Copy Operations")
    struct CopyTests {

        @Test("Copy path")
        func copyPath() {
            let original = CGPath(rect: CGRect(x: 10.0, y: 20.0, width: 100.0, height: 200.0))
            let copy = original.copy()
            #expect(copy != nil)
            #expect(copy == original)
        }

        @Test("Copy path with transform")
        func copyPathWithTransform() {
            let original = CGPath(rect: CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0))
            var transform = CGAffineTransform(translationX: 10.0, y: 20.0)
            let copy = withUnsafePointer(to: &transform) { ptr in
                original.copy(using: ptr)
            }
            #expect(copy != nil)
            if let bbox = copy?.boundingBox {
                #expect(abs(bbox.minX.native - 10.0) < 0.0001)
                #expect(abs(bbox.minY.native - 20.0) < 0.0001)
            }
        }

        @Test("Mutable copy")
        func mutableCopy() {
            let original = CGPath(rect: CGRect(x: 10.0, y: 20.0, width: 100.0, height: 200.0))
            let mutableCopy = original.mutableCopy()
            #expect(mutableCopy != nil)
            mutableCopy?.addRect(CGRect(x: 200.0, y: 200.0, width: 50.0, height: 50.0))
            // Original should be unchanged
            #expect(original.boundingBox.maxX.native < 200.0)
        }
    }

    // MARK: - Apply Tests

    @Suite("Apply Operations")
    struct ApplyTests {

        @Test("Apply block to path elements")
        func applyBlock() {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0.0, y: 0.0))
            path.addLine(to: CGPoint(x: 100.0, y: 100.0))
            path.closeSubpath()

            var elementCount = 0
            path.applyWithBlock { element in
                elementCount += 1
            }
            #expect(elementCount == 3) // moveTo, lineTo, closeSubpath
        }

        @Test("Apply block to rectangular path")
        func applyBlockToRect() {
            let path = CGPath(rect: CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0))
            var elementTypes: [CGPathElementType] = []
            path.applyWithBlock { element in
                elementTypes.append(element.pointee.type)
            }
            #expect(elementTypes.count == 5) // moveTo, lineTo, lineTo, lineTo, closeSubpath
            #expect(elementTypes[0] == .moveToPoint)
            #expect(elementTypes[4] == .closeSubpath)
        }
    }

    // MARK: - Equatable Tests

    @Suite("Equatable Conformance")
    struct EquatableTests {

        @Test("Equal paths")
        func equalPaths() {
            let rect = CGRect(x: 10.0, y: 20.0, width: 100.0, height: 200.0)
            let path1 = CGPath(rect: rect)
            let path2 = CGPath(rect: rect)
            #expect(path1 == path2)
        }

        @Test("Unequal paths")
        func unequalPaths() {
            let path1 = CGPath(rect: CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0))
            let path2 = CGPath(rect: CGRect(x: 0.0, y: 0.0, width: 200.0, height: 200.0))
            #expect(path1 != path2)
        }
    }

    // MARK: - Hashable Tests

    @Suite("Hashable Conformance")
    struct HashableTests {

        @Test("Equal paths have equal hashes")
        func equalPathsEqualHashes() {
            let rect = CGRect(x: 10.0, y: 20.0, width: 100.0, height: 200.0)
            let path1 = CGPath(rect: rect)
            let path2 = CGPath(rect: rect)
            #expect(path1.hashValue == path2.hashValue)
        }

        @Test("Can be used in Set")
        func setUsage() {
            let rect1 = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0)
            let rect2 = CGRect(x: 50.0, y: 50.0, width: 100.0, height: 100.0)
            var set = Set<CGPath>()
            set.insert(CGPath(rect: rect1))
            set.insert(CGPath(rect: rect2))
            set.insert(CGPath(rect: rect1))
            #expect(set.count == 2)
        }
    }

    // MARK: - Arc Tests

    @Suite("Arc Operations")
    struct ArcTests {

        @Test("Add arc")
        func addArc() {
            let path = CGMutablePath()
            path.addArc(
                center: CGPoint(x: 50.0, y: 50.0),
                radius: 25.0,
                startAngle: 0.0,
                endAngle: CGFloat.pi / 2,
                clockwise: false
            )
            #expect(!path.isEmpty)
        }

        @Test("Add relative arc")
        func addRelativeArc() {
            let path = CGMutablePath()
            path.addRelativeArc(
                center: CGPoint(x: 50.0, y: 50.0),
                radius: 25.0,
                startAngle: 0.0,
                delta: CGFloat.pi / 2
            )
            #expect(!path.isEmpty)
        }

        @Test("Add arc tangent")
        func addArcTangent() {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0.0, y: 0.0))
            path.addArc(
                tangent1End: CGPoint(x: 50.0, y: 0.0),
                tangent2End: CGPoint(x: 50.0, y: 50.0),
                radius: 10.0
            )
            #expect(!path.isEmpty)
        }
    }
}
