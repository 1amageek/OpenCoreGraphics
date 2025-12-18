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
private typealias CGFloat = Foundation.CGFloat
private typealias CGPoint = Foundation.CGPoint
private typealias CGSize = Foundation.CGSize
private typealias CGRect = Foundation.CGRect
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
            #expect(abs(bbox.minX - 10.0) < 0.0001)
            #expect(abs(bbox.minY - 20.0) < 0.0001)
            #expect(abs(bbox.width - 100.0) < 0.0001)
            #expect(abs(bbox.height - 200.0) < 0.0001)
        }

        @Test("Rectangular path with transform")
        func rectangularPathWithTransform() {
            let rect = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0)
            var transform = CGAffineTransform(translationX: 10.0, y: 20.0)
            let path = withUnsafePointer(to: &transform) { ptr in
                CGPath(rect: rect, transform: ptr)
            }
            let bbox = path.boundingBox
            #expect(abs(bbox.minX - 10.0) < 0.0001)
            #expect(abs(bbox.minY - 20.0) < 0.0001)
        }

        @Test("isRect returns true for rectangular path")
        func isRectTrue() {
            let rect = CGRect(x: 10.0, y: 20.0, width: 100.0, height: 200.0)
            let path = CGPath(rect: rect)
            var detectedRect = CGRect.zero
            let isRect = path.isRect(&detectedRect)
            #expect(isRect)
            #expect(abs(detectedRect.minX - 10.0) < 0.0001)
            #expect(abs(detectedRect.minY - 20.0) < 0.0001)
            #expect(abs(detectedRect.width - 100.0) < 0.0001)
            #expect(abs(detectedRect.height - 200.0) < 0.0001)
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
            #expect(abs(bbox.minX - rect.minX) < 1.0)
            #expect(abs(bbox.minY - rect.minY) < 1.0)
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
            #expect(abs(bbox.minX - rect.minX) < 1.0)
            #expect(abs(bbox.minY - rect.minY) < 1.0)
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
            #expect(path.currentPoint.x == 10.0)
            #expect(path.currentPoint.y == 20.0)
        }

        @Test("currentPoint after line")
        func currentPointAfterLine() {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0.0, y: 0.0))
            path.addLine(to: CGPoint(x: 100.0, y: 100.0))
            #expect(path.currentPoint.x == 100.0)
            #expect(path.currentPoint.y == 100.0)
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
            #expect(path.currentPoint.x == 10.0)
            #expect(path.currentPoint.y == 20.0)
        }

        @Test("Add line")
        func addLine() {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0.0, y: 0.0))
            path.addLine(to: CGPoint(x: 100.0, y: 100.0))
            #expect(!path.isEmpty)
            let bbox = path.boundingBox
            #expect(bbox.maxX == 100.0)
            #expect(bbox.maxY == 100.0)
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
            #expect(bbox.width == 100.0)
            #expect(bbox.height == 100.0)
        }

        @Test("Add rect")
        func addRect() {
            let path = CGMutablePath()
            path.addRect(CGRect(x: 10.0, y: 20.0, width: 100.0, height: 200.0))
            let bbox = path.boundingBox
            #expect(abs(bbox.minX - 10.0) < 0.0001)
            #expect(abs(bbox.minY - 20.0) < 0.0001)
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
            #expect(bbox.minX == 0.0)
            #expect(bbox.maxX == 150.0)
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
            #expect(bbox.maxY >= 50.0)
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
            #expect(bbox.minX == 0.0)
            #expect(bbox.maxX == 150.0)
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
            #expect(path.currentPoint.x == 10.0)
            #expect(path.currentPoint.y == 20.0)
        }

        @Test("Add line with transform")
        func addLineWithTransform() {
            let path = CGMutablePath()
            let transform = CGAffineTransform(scaleX: 2.0, y: 2.0)
            path.move(to: CGPoint(x: 0.0, y: 0.0))
            path.addLine(to: CGPoint(x: 50.0, y: 50.0), transform: transform)
            #expect(path.currentPoint.x == 100.0)
            #expect(path.currentPoint.y == 100.0)
        }

        @Test("Add rect with transform")
        func addRectWithTransform() {
            let path = CGMutablePath()
            let transform = CGAffineTransform(translationX: 100.0, y: 100.0)
            path.addRect(CGRect(x: 0.0, y: 0.0, width: 50.0, height: 50.0), transform: transform)
            let bbox = path.boundingBox
            #expect(bbox.minX == 100.0)
            #expect(bbox.minY == 100.0)
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
            // Transform is applied to the path, so the path becomes rect (100, 100, 100, 100)
            // Point (150, 150) should be inside the transformed rect
            // Implementation: testPoint = (150, 150) + inverse(-100, -100) = (50, 50)
            // (50, 50) is inside original rect (0, 0, 100, 100) → true
            #expect(path.contains(CGPoint(x: 150.0, y: 150.0), transform: transform))

            // Point (50, 50) should NOT be inside the transformed rect (100, 100, 100, 100)
            // testPoint = (50, 50) + inverse(-100, -100) = (-50, -50)
            // (-50, -50) is NOT inside original rect (0, 0, 100, 100) → false
            #expect(!path.contains(CGPoint(x: 50.0, y: 50.0), transform: transform))
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
                #expect(abs(bbox.minX - 10.0) < 0.0001)
                #expect(abs(bbox.minY - 20.0) < 0.0001)
            }
        }

        @Test("Mutable copy")
        func mutableCopy() {
            let original = CGPath(rect: CGRect(x: 10.0, y: 20.0, width: 100.0, height: 200.0))
            let mutableCopy = original.mutableCopy()
            #expect(mutableCopy != nil)
            mutableCopy?.addRect(CGRect(x: 200.0, y: 200.0, width: 50.0, height: 50.0))
            // Original should be unchanged
            #expect(original.boundingBox.maxX < 200.0)
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

    // MARK: - Geometry Logic Tests

    @Suite("Geometry Logic")
    struct GeometryLogicTests {

        // MARK: - Rectangle Contains Tests

        @Test("Rectangle path contains works correctly for interior points")
        func rectangleContainsInterior() {
            let path = CGPath(rect: CGRect(x: 10, y: 10, width: 80, height: 80))

            // Interior points should be inside
            #expect(path.contains(CGPoint(x: 50, y: 50)))
            #expect(path.contains(CGPoint(x: 11, y: 11)))
            #expect(path.contains(CGPoint(x: 89, y: 89)))
            #expect(path.contains(CGPoint(x: 50, y: 11)))
            #expect(path.contains(CGPoint(x: 50, y: 89)))
        }

        @Test("Rectangle path contains works correctly for exterior points")
        func rectangleContainsExterior() {
            let path = CGPath(rect: CGRect(x: 10, y: 10, width: 80, height: 80))

            // Points outside should not be contained
            #expect(!path.contains(CGPoint(x: 5, y: 50)))   // left of rect
            #expect(!path.contains(CGPoint(x: 95, y: 50)))  // right of rect
            #expect(!path.contains(CGPoint(x: 50, y: 5)))   // above rect
            #expect(!path.contains(CGPoint(x: 50, y: 95)))  // below rect
            #expect(!path.contains(CGPoint(x: 0, y: 0)))    // far outside
            #expect(!path.contains(CGPoint(x: 100, y: 100)))
        }

        // MARK: - Ellipse Contains Tests

        @Test("Ellipse path does not contain corner points")
        func ellipseDoesNotContainCorners() {
            let path = CGPath(ellipseIn: CGRect(x: 0, y: 0, width: 100, height: 100))

            // Corners of bounding rect should NOT be inside ellipse
            #expect(!path.contains(CGPoint(x: 1, y: 1)))
            #expect(!path.contains(CGPoint(x: 99, y: 1)))
            #expect(!path.contains(CGPoint(x: 1, y: 99)))
            #expect(!path.contains(CGPoint(x: 99, y: 99)))
        }

        @Test("Ellipse path contains center point")
        func ellipseContainsCenter() {
            let path = CGPath(ellipseIn: CGRect(x: 0, y: 0, width: 100, height: 100))

            // Center should definitely be inside
            #expect(path.contains(CGPoint(x: 50, y: 50)))
        }

        @Test("Ellipse path contains points on major axis")
        func ellipseContainsMajorAxisPoints() {
            let path = CGPath(ellipseIn: CGRect(x: 0, y: 0, width: 100, height: 100))

            // Points near the edge on the horizontal axis
            #expect(path.contains(CGPoint(x: 5, y: 50)))   // near left edge
            #expect(path.contains(CGPoint(x: 95, y: 50)))  // near right edge
            #expect(path.contains(CGPoint(x: 50, y: 5)))   // near top edge
            #expect(path.contains(CGPoint(x: 50, y: 95)))  // near bottom edge
        }

        // MARK: - Compound Path Bounding Box Tests

        @Test("Compound path bounding box encompasses all subpaths")
        func compoundPathBoundingBox() {
            let path = CGMutablePath()
            path.addRect(CGRect(x: 0, y: 0, width: 50, height: 50))
            path.addRect(CGRect(x: 100, y: 100, width: 50, height: 50))

            let bbox = path.boundingBox
            #expect(bbox.minX == 0)
            #expect(bbox.minY == 0)
            #expect(bbox.maxX == 150)
            #expect(bbox.maxY == 150)
        }

        @Test("Disjoint paths bounding box is union of individual bounds")
        func disjointPathsBoundingBox() {
            let path = CGMutablePath()

            // Three disjoint rectangles
            path.addRect(CGRect(x: 0, y: 0, width: 10, height: 10))
            path.addRect(CGRect(x: 50, y: 50, width: 10, height: 10))
            path.addRect(CGRect(x: 200, y: 0, width: 10, height: 10))

            let bbox = path.boundingBox
            #expect(bbox.minX == 0)
            #expect(bbox.minY == 0)
            #expect(bbox.maxX == 210)
            #expect(bbox.maxY == 60)
        }

        // MARK: - Bezier Curve Bounding Box Tests

        @Test("Quadratic bezier bounding box includes control point influence")
        func quadraticBezierBoundingBox() {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 0))
            path.addQuadCurve(to: CGPoint(x: 100, y: 0), control: CGPoint(x: 50, y: 100))

            let bbox = path.boundingBox
            // The curve should extend upward due to control point
            #expect(bbox.maxY >= 50)  // At least halfway to control point
            #expect(bbox.minX == 0)
            #expect(bbox.maxX == 100)
        }

        @Test("Cubic bezier bounding box is calculated correctly")
        func cubicBezierBoundingBox() {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 50))
            path.addCurve(
                to: CGPoint(x: 100, y: 50),
                control1: CGPoint(x: 30, y: 0),
                control2: CGPoint(x: 70, y: 100)
            )

            let bbox = path.boundingBox
            // Curve should extend both up and down from the endpoints
            #expect(bbox.minY < 50)  // Should extend below y=50
            #expect(bbox.maxY > 50)  // Should extend above y=50
        }

        // MARK: - Even-Odd Fill Rule Tests

        @Test("Even-odd fill rule with concentric rectangles")
        func evenOddFillRuleConcentricRects() {
            let path = CGMutablePath()
            // Outer rectangle
            path.addRect(CGRect(x: 0, y: 0, width: 100, height: 100))
            // Inner rectangle
            path.addRect(CGRect(x: 25, y: 25, width: 50, height: 50))

            // Both should be contained with default (winding) rule for simple shapes
            // Note: actual winding behavior may vary based on subpath direction
            #expect(path.contains(CGPoint(x: 10, y: 10)))  // In outer rect only

            // With even-odd rule: inner rectangle creates a "hole"
            #expect(!path.contains(CGPoint(x: 50, y: 50), using: .evenOdd))
            #expect(path.contains(CGPoint(x: 10, y: 10), using: .evenOdd))
        }

        @Test("Even-odd fill rule with overlapping rectangles")
        func evenOddFillRuleOverlappingRects() {
            let path = CGMutablePath()
            path.addRect(CGRect(x: 0, y: 0, width: 60, height: 100))
            path.addRect(CGRect(x: 40, y: 0, width: 60, height: 100))

            // Overlap region (40-60) should be outside with even-odd
            #expect(!path.contains(CGPoint(x: 50, y: 50), using: .evenOdd))

            // Non-overlap regions should be inside
            #expect(path.contains(CGPoint(x: 20, y: 50), using: .evenOdd))
            #expect(path.contains(CGPoint(x: 80, y: 50), using: .evenOdd))
        }

        // MARK: - Path Equality Tests

        @Test("Paths with same geometry are equal")
        func pathsWithSameGeometryEqual() {
            let path1 = CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 100))
            let path2 = CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 100))

            #expect(path1 == path2)
        }

        @Test("Paths with different geometry are not equal")
        func pathsWithDifferentGeometryNotEqual() {
            let path1 = CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 100))
            let path2 = CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 50))

            #expect(path1 != path2)
        }

        @Test("Path equality compares element-by-element")
        func pathEqualityElementByElement() {
            let path1 = CGMutablePath()
            path1.move(to: CGPoint(x: 0, y: 0))
            path1.addLine(to: CGPoint(x: 100, y: 100))

            let path2 = CGMutablePath()
            path2.move(to: CGPoint(x: 0, y: 0))
            path2.addLine(to: CGPoint(x: 100, y: 100))

            #expect(path1 == path2)
        }

        @Test("Path built differently but same shape is equal")
        func pathBuiltDifferentlyButSameShape() {
            // Build same rectangle two different ways
            let path1 = CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 100))

            let path2 = CGMutablePath()
            path2.move(to: CGPoint(x: 0, y: 0))
            path2.addLine(to: CGPoint(x: 100, y: 0))
            path2.addLine(to: CGPoint(x: 100, y: 100))
            path2.addLine(to: CGPoint(x: 0, y: 100))
            path2.closeSubpath()

            // These should be equal if implementation compares geometry
            #expect(path1 == path2)
        }

        // MARK: - Arc Geometry Tests

        @Test("Full circle arc contains its center")
        func fullCircleContainsCenter() {
            let path = CGMutablePath()
            path.addArc(
                center: CGPoint(x: 50, y: 50),
                radius: 25,
                startAngle: 0,
                endAngle: CGFloat.pi * 2,
                clockwise: false
            )
            path.closeSubpath()

            #expect(path.contains(CGPoint(x: 50, y: 50)))
        }

        @Test("Full circle arc does not contain point outside radius")
        func fullCircleDoesNotContainOutsidePoint() {
            let path = CGMutablePath()
            path.addArc(
                center: CGPoint(x: 50, y: 50),
                radius: 25,
                startAngle: 0,
                endAngle: CGFloat.pi * 2,
                clockwise: false
            )
            path.closeSubpath()

            // Point 30 units from center (radius is 25)
            #expect(!path.contains(CGPoint(x: 80, y: 50)))
        }

        @Test("Arc bounding box is correct for quarter circle")
        func arcBoundingBoxQuarterCircle() {
            let path = CGMutablePath()
            // Quarter circle in first quadrant
            path.addArc(
                center: CGPoint(x: 0, y: 0),
                radius: 50,
                startAngle: 0,
                endAngle: CGFloat.pi / 2,
                clockwise: false
            )

            let bbox = path.boundingBox
            // Should span from (50, 0) to (0, 50) approximately
            #expect(bbox.maxX >= 49)
            #expect(bbox.maxY >= 49)
            #expect(bbox.minX <= 1)
            #expect(bbox.minY <= 1)
        }
    }

    // MARK: - Bezier Curve Containment Tests

    @Suite("Bezier Curve Containment")
    struct BezierCurveContainmentTests {

        // MARK: - Quadratic Bezier Tests

        @Test("Quadratic curve path contains interior point")
        func quadraticCurveContainsInterior() {
            // Create a parabolic "arch" shape
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 0))
            path.addQuadCurve(to: CGPoint(x: 100, y: 0), control: CGPoint(x: 50, y: 100))
            path.addLine(to: CGPoint(x: 100, y: -50))
            path.addLine(to: CGPoint(x: 0, y: -50))
            path.closeSubpath()

            // Point inside the curve (below the arch)
            #expect(path.contains(CGPoint(x: 50, y: -25)))
            // Point inside near the curve apex
            #expect(path.contains(CGPoint(x: 50, y: 40)))
        }

        @Test("Quadratic curve path does not contain point above curve")
        func quadraticCurveDoesNotContainAbove() {
            // Create a parabolic "arch" shape
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 0))
            path.addQuadCurve(to: CGPoint(x: 100, y: 0), control: CGPoint(x: 50, y: 100))
            path.addLine(to: CGPoint(x: 100, y: -50))
            path.addLine(to: CGPoint(x: 0, y: -50))
            path.closeSubpath()

            // Point above the curve (outside the arch)
            #expect(!path.contains(CGPoint(x: 50, y: 60)))
            #expect(!path.contains(CGPoint(x: 25, y: 70)))
        }

        @Test("Quadratic curve with concave shape")
        func quadraticCurveConcave() {
            // Create a concave shape (bowl) - curve goes down then comes back up
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 50))
            path.addQuadCurve(to: CGPoint(x: 100, y: 50), control: CGPoint(x: 50, y: -50))
            path.addLine(to: CGPoint(x: 100, y: 100))
            path.addLine(to: CGPoint(x: 0, y: 100))
            path.closeSubpath()

            // Point inside the bowl (above the curve)
            #expect(path.contains(CGPoint(x: 50, y: 70)))
            // Point clearly outside (below the concave area)
            #expect(!path.contains(CGPoint(x: 50, y: -80)))
        }

        // MARK: - Cubic Bezier Tests

        @Test("Cubic curve path contains interior point")
        func cubicCurveContainsInterior() {
            // Create an S-curved boundary
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 0))
            path.addCurve(
                to: CGPoint(x: 100, y: 100),
                control1: CGPoint(x: 30, y: 80),
                control2: CGPoint(x: 70, y: 20)
            )
            path.addLine(to: CGPoint(x: 0, y: 100))
            path.closeSubpath()

            // Point clearly inside the shape
            #expect(path.contains(CGPoint(x: 20, y: 50)))
        }

        @Test("Cubic curve S-shape boundary test")
        func cubicCurveSShapeBoundary() {
            // Create an S-curve that bulges right then left
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 50, y: 0))
            path.addCurve(
                to: CGPoint(x: 50, y: 100),
                control1: CGPoint(x: 100, y: 25),
                control2: CGPoint(x: 0, y: 75)
            )
            path.addLine(to: CGPoint(x: 0, y: 100))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.closeSubpath()

            // Test points along the curve
            #expect(path.contains(CGPoint(x: 25, y: 50))) // Inside
            #expect(!path.contains(CGPoint(x: 80, y: 25))) // Outside (right bulge)
        }

        @Test("Cubic bezier closed loop contains center")
        func cubicBezierLoopContainsCenter() {
            // Create a heart-like shape using cubic curves
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 50, y: 100)) // Bottom point
            path.addCurve(
                to: CGPoint(x: 50, y: 40),
                control1: CGPoint(x: 0, y: 60),
                control2: CGPoint(x: 0, y: 20)
            )
            path.addCurve(
                to: CGPoint(x: 50, y: 100),
                control1: CGPoint(x: 100, y: 20),
                control2: CGPoint(x: 100, y: 60)
            )
            path.closeSubpath()

            // Center of the shape should be inside
            #expect(path.contains(CGPoint(x: 50, y: 60)))
        }

        // MARK: - Complex Curved Path Tests

        @Test("Circle approximated with bezier curves contains center")
        func bezierCircleContainsCenter() {
            // Use the ellipse path which is made of bezier curves
            let path = CGPath(ellipseIn: CGRect(x: 0, y: 0, width: 100, height: 100))

            #expect(path.contains(CGPoint(x: 50, y: 50)))
        }

        @Test("Circle approximated with bezier curves excludes exterior")
        func bezierCircleExcludesExterior() {
            let path = CGPath(ellipseIn: CGRect(x: 0, y: 0, width: 100, height: 100))

            // Points outside the circle
            #expect(!path.contains(CGPoint(x: -10, y: 50)))
            #expect(!path.contains(CGPoint(x: 110, y: 50)))
            #expect(!path.contains(CGPoint(x: 50, y: -10)))
            #expect(!path.contains(CGPoint(x: 50, y: 110)))
        }

        @Test("Rounded rectangle uses bezier curves correctly")
        func roundedRectBezierContainment() {
            let path = CGPath(
                roundedRect: CGRect(x: 0, y: 0, width: 100, height: 100),
                cornerWidth: 20,
                cornerHeight: 20
            )

            // Center should be inside
            #expect(path.contains(CGPoint(x: 50, y: 50)))

            // Point in the corner (inside the rounded corner)
            #expect(path.contains(CGPoint(x: 10, y: 10)))

            // Point outside the corner (would be inside a sharp corner rect)
            #expect(!path.contains(CGPoint(x: 2, y: 2)))
        }

        // MARK: - Fill Rule with Curves Tests

        @Test("Even-odd fill rule with curved nested shapes")
        func evenOddWithCurves() {
            let path = CGMutablePath()

            // Outer circle
            path.addEllipse(in: CGRect(x: 0, y: 0, width: 100, height: 100))

            // Inner circle (creates a ring)
            path.addEllipse(in: CGRect(x: 25, y: 25, width: 50, height: 50))

            // With even-odd rule, center should be "outside" (in the hole)
            #expect(!path.contains(CGPoint(x: 50, y: 50), using: .evenOdd))

            // Point in the ring should be inside
            #expect(path.contains(CGPoint(x: 10, y: 50), using: .evenOdd))
        }

        @Test("Winding rule with curved nested shapes")
        func windingWithCurves() {
            let path = CGMutablePath()

            // Outer ellipse
            path.addEllipse(in: CGRect(x: 0, y: 0, width: 100, height: 100))

            // Inner ellipse
            path.addEllipse(in: CGRect(x: 25, y: 25, width: 50, height: 50))

            // With winding rule, both circles wind the same way
            // so center is inside (winding number = 2)
            #expect(path.contains(CGPoint(x: 50, y: 50), using: .winding))
        }

        // MARK: - Edge Cases

        @Test("Point exactly on quadratic curve boundary")
        func pointOnQuadraticCurveBoundary() {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 0))
            path.addQuadCurve(to: CGPoint(x: 100, y: 0), control: CGPoint(x: 50, y: 100))
            path.closeSubpath()

            // Point at the start of the curve
            // Note: boundary behavior can vary; we just verify no crash
            _ = path.contains(CGPoint(x: 0, y: 0))
        }

        @Test("Very tight curve with small control point deviation")
        func tightCurve() {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 0))
            // Very slight curve
            path.addQuadCurve(to: CGPoint(x: 100, y: 0), control: CGPoint(x: 50, y: 1))
            path.addLine(to: CGPoint(x: 100, y: -10))
            path.addLine(to: CGPoint(x: 0, y: -10))
            path.closeSubpath()

            // Point below the almost-straight line
            #expect(path.contains(CGPoint(x: 50, y: -5)))
        }
    }

    // MARK: - Stroke Path Conversion Tests

    @Suite("Stroke Path Conversion")
    struct StrokePathConversionTests {

        @Test("Copy with stroking creates non-empty path")
        func copyStrokingCreatesPath() {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 50))
            path.addLine(to: CGPoint(x: 100, y: 50))

            let strokedPath = path.copy(
                strokingWithWidth: 10,
                lineCap: .butt,
                lineJoin: .miter,
                miterLimit: 10
            )

            #expect(!strokedPath.isEmpty)
        }

        @Test("Stroked path bounding box is larger than original")
        func strokedPathBoundingBoxLarger() {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 10, y: 50))
            path.addLine(to: CGPoint(x: 90, y: 50))

            let originalBbox = path.boundingBox
            let strokedPath = path.copy(
                strokingWithWidth: 20,
                lineCap: .butt,
                lineJoin: .miter,
                miterLimit: 10
            )
            let strokedBbox = strokedPath.boundingBox

            // Stroked path should extend above and below original
            #expect(strokedBbox.minY < originalBbox.minY)
            #expect(strokedBbox.maxY > originalBbox.maxY)
        }

        @Test("Square line cap extends beyond endpoints")
        func squareLineCapExtends() {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 50, y: 50))
            path.addLine(to: CGPoint(x: 100, y: 50))

            let strokedPath = path.copy(
                strokingWithWidth: 20,
                lineCap: .square,
                lineJoin: .miter,
                miterLimit: 10
            )
            let bbox = strokedPath.boundingBox

            // Square cap should extend beyond the start point
            // Half line width (10) extension
            #expect(bbox.minX < 50)
        }

        @Test("Butt line cap does not extend beyond endpoints")
        func buttLineCapNoExtension() {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 50, y: 50))
            path.addLine(to: CGPoint(x: 100, y: 50))

            let strokedPath = path.copy(
                strokingWithWidth: 20,
                lineCap: .butt,
                lineJoin: .miter,
                miterLimit: 10
            )
            let bbox = strokedPath.boundingBox

            // Butt cap should not extend beyond start point
            // Allow small tolerance for numerical precision
            #expect(bbox.minX >= 49)
        }

        @Test("Round line cap creates semicircle")
        func roundLineCapSemicircle() {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 50, y: 50))
            path.addLine(to: CGPoint(x: 100, y: 50))

            let strokedPath = path.copy(
                strokingWithWidth: 20,
                lineCap: .round,
                lineJoin: .miter,
                miterLimit: 10
            )
            let bbox = strokedPath.boundingBox

            // Round cap should extend by half line width
            #expect(bbox.minX <= 40) // 50 - 10
        }

        @Test("Stroked closed path forms closed outline")
        func strokedClosedPath() {
            let path = CGMutablePath()
            path.addRect(CGRect(x: 20, y: 20, width: 60, height: 60))

            let strokedPath = path.copy(
                strokingWithWidth: 10,
                lineCap: .butt,
                lineJoin: .miter,
                miterLimit: 10
            )
            let bbox = strokedPath.boundingBox

            // Stroked rectangle should be larger by line width on all sides
            #expect(bbox.minX <= 15) // 20 - 5
            #expect(bbox.minY <= 15)
            #expect(bbox.maxX >= 85) // 80 + 5
            #expect(bbox.maxY >= 85)
        }

        @Test("Line join miter creates sharp corners")
        func miterJoinSharpCorners() {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 50))
            path.addLine(to: CGPoint(x: 50, y: 50))
            path.addLine(to: CGPoint(x: 50, y: 0))

            let strokedPath = path.copy(
                strokingWithWidth: 10,
                lineCap: .butt,
                lineJoin: .miter,
                miterLimit: 10
            )

            #expect(!strokedPath.isEmpty)
            // Miter join should extend the corner
            let bbox = strokedPath.boundingBox
            #expect(bbox.maxX > 50 || bbox.minY < 0)
        }

        @Test("Bevel join creates flat corner")
        func bevelJoinFlatCorner() {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 50))
            path.addLine(to: CGPoint(x: 50, y: 50))
            path.addLine(to: CGPoint(x: 50, y: 0))

            let strokedPath = path.copy(
                strokingWithWidth: 10,
                lineCap: .butt,
                lineJoin: .bevel,
                miterLimit: 10
            )

            #expect(!strokedPath.isEmpty)
        }

        @Test("Round join creates curved corner")
        func roundJoinCurvedCorner() {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 50))
            path.addLine(to: CGPoint(x: 50, y: 50))
            path.addLine(to: CGPoint(x: 50, y: 0))

            let strokedPath = path.copy(
                strokingWithWidth: 10,
                lineCap: .butt,
                lineJoin: .round,
                miterLimit: 10
            )

            #expect(!strokedPath.isEmpty)
        }

        @Test("Zero line width returns empty path")
        func zeroLineWidthEmptyPath() {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 100, y: 100))

            let strokedPath = path.copy(
                strokingWithWidth: 0,
                lineCap: .butt,
                lineJoin: .miter,
                miterLimit: 10
            )

            #expect(strokedPath.isEmpty)
        }

        @Test("Stroked curve path is not empty")
        func strokedCurvePath() {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 50))
            path.addQuadCurve(to: CGPoint(x: 100, y: 50), control: CGPoint(x: 50, y: 0))

            let originalBbox = path.boundingBox
            let strokedPath = path.copy(
                strokingWithWidth: 10,
                lineCap: .round,
                lineJoin: .round,
                miterLimit: 10
            )

            #expect(!strokedPath.isEmpty)
            // Stroked curve should have larger bounding box than original
            let bbox = strokedPath.boundingBox
            // The quadratic curve dips to approximately y=25 at the center
            // With stroke width 10 (radius 5), the stroked path should extend further
            #expect(bbox.minY < originalBbox.minY) // Stroke extends beyond original path
        }

        @Test("Transform applied to stroked path")
        func transformAppliedToStrokedPath() {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 50, y: 0))

            let transform = CGAffineTransform(translationX: 100, y: 100)
            let strokedPath = path.copy(
                strokingWithWidth: 10,
                lineCap: .butt,
                lineJoin: .miter,
                miterLimit: 10,
                transform: transform
            )

            let bbox = strokedPath.boundingBox
            #expect(bbox.minX >= 99) // Should be translated by 100
            #expect(bbox.minY >= 94) // 100 - 5 (half line width)
        }
    }
}
