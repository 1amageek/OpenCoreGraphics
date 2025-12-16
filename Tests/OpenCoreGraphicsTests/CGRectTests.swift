//
//  CGRectTests.swift
//  OpenCoreGraphics
//
//  Tests for CGRect type and CGRectEdge enum
//

import Foundation
import Testing
@testable import OpenCoreGraphics

// Type aliases to avoid ambiguity with CoreFoundation types on macOS
private typealias CGFloat = OpenCoreGraphics.CGFloat
private typealias CGPoint = OpenCoreGraphics.CGPoint
private typealias CGSize = OpenCoreGraphics.CGSize
private typealias CGRect = OpenCoreGraphics.CGRect
private typealias CGRectEdge = OpenCoreGraphics.CGRectEdge
private typealias CGAffineTransform = OpenCoreGraphics.CGAffineTransform

@Suite("CGRect Tests")
struct CGRectTests {

    // MARK: - Initialization Tests

    @Suite("Initialization")
    struct InitializationTests {

        @Test("Default initializer creates zero rect")
        func defaultInit() {
            let rect = CGRect()
            #expect(rect.origin == CGPoint.zero)
            #expect(rect.size == CGSize.zero)
        }

        @Test("Init with origin and size")
        func initWithOriginAndSize() {
            let origin = CGPoint(x: 10.0, y: 20.0)
            let size = CGSize(width: 100.0, height: 200.0)
            let rect = CGRect(origin: origin, size: size)
            #expect(rect.origin == origin)
            #expect(rect.size == size)
        }

        @Test("Init with CGFloat parameters")
        func initWithCGFloat() {
            let rect = CGRect(x: CGFloat(10.0), y: CGFloat(20.0), width: CGFloat(100.0), height: CGFloat(200.0))
            #expect(rect.origin.x.native == 10.0)
            #expect(rect.origin.y.native == 20.0)
            #expect(rect.size.width.native == 100.0)
            #expect(rect.size.height.native == 200.0)
        }

        @Test("Init with Double parameters")
        func initWithDouble() {
            let rect = CGRect(x: 10.5, y: 20.5, width: 100.5, height: 200.5)
            #expect(rect.origin.x.native == 10.5)
            #expect(rect.origin.y.native == 20.5)
            #expect(rect.size.width.native == 100.5)
            #expect(rect.size.height.native == 200.5)
        }

        @Test("Init with Int parameters")
        func initWithInt() {
            let rect = CGRect(x: 10, y: 20, width: 100, height: 200)
            #expect(rect.origin.x.native == 10.0)
            #expect(rect.origin.y.native == 20.0)
            #expect(rect.size.width.native == 100.0)
            #expect(rect.size.height.native == 200.0)
        }
    }

    // MARK: - Static Properties Tests

    @Suite("Static Properties")
    struct StaticPropertiesTests {

        @Test("Zero rect")
        func zeroRect() {
            let zero = CGRect.zero
            #expect(zero.origin == CGPoint.zero)
            #expect(zero.size == CGSize.zero)
            #expect(zero.isEmpty)
        }

        @Test("Infinite rect")
        func infiniteRect() {
            let infinite = CGRect.infinite
            #expect(infinite.isInfinite)
            #expect(!infinite.isEmpty)
            #expect(!infinite.isNull)
        }

        @Test("Null rect")
        func nullRect() {
            let null = CGRect.null
            #expect(null.isNull)
            #expect(null.isEmpty)
        }
    }

    // MARK: - Geometric Properties Tests

    @Suite("Geometric Properties")
    struct GeometricPropertiesTests {

        @Test("Width and height properties")
        func widthAndHeight() {
            let rect = CGRect(x: 10.0, y: 20.0, width: 100.0, height: 200.0)
            #expect(rect.width.native == 100.0)
            #expect(rect.height.native == 200.0)
        }

        @Test("minX, midX, maxX for positive width")
        func xPropertiesPositive() {
            let rect = CGRect(x: 10.0, y: 20.0, width: 100.0, height: 200.0)
            #expect(rect.minX.native == 10.0)
            #expect(rect.midX.native == 60.0)
            #expect(rect.maxX.native == 110.0)
        }

        @Test("minX, midX, maxX for negative width")
        func xPropertiesNegative() {
            let rect = CGRect(x: 10.0, y: 20.0, width: -100.0, height: 200.0)
            #expect(rect.minX.native == -90.0)
            #expect(rect.midX.native == -40.0)
            #expect(rect.maxX.native == 10.0)
        }

        @Test("minY, midY, maxY for positive height")
        func yPropertiesPositive() {
            let rect = CGRect(x: 10.0, y: 20.0, width: 100.0, height: 200.0)
            #expect(rect.minY.native == 20.0)
            #expect(rect.midY.native == 120.0)
            #expect(rect.maxY.native == 220.0)
        }

        @Test("minY, midY, maxY for negative height")
        func yPropertiesNegative() {
            let rect = CGRect(x: 10.0, y: 20.0, width: 100.0, height: -200.0)
            #expect(rect.minY.native == -180.0)
            #expect(rect.midY.native == -80.0)
            #expect(rect.maxY.native == 20.0)
        }
    }

    // MARK: - State Properties Tests

    @Suite("State Properties")
    struct StatePropertiesTests {

        @Test("isEmpty for zero size")
        func isEmptyZeroSize() {
            #expect(CGRect.zero.isEmpty)
        }

        @Test("isEmpty for zero width")
        func isEmptyZeroWidth() {
            let rect = CGRect(x: 10.0, y: 20.0, width: 0.0, height: 200.0)
            #expect(rect.isEmpty)
        }

        @Test("isEmpty for zero height")
        func isEmptyZeroHeight() {
            let rect = CGRect(x: 10.0, y: 20.0, width: 100.0, height: 0.0)
            #expect(rect.isEmpty)
        }

        @Test("isEmpty for null rect")
        func isEmptyNull() {
            #expect(CGRect.null.isEmpty)
        }

        @Test("isEmpty for valid rect")
        func isEmptyValid() {
            let rect = CGRect(x: 10.0, y: 20.0, width: 100.0, height: 200.0)
            #expect(!rect.isEmpty)
        }

        @Test("isInfinite")
        func isInfiniteProperty() {
            #expect(CGRect.infinite.isInfinite)
            #expect(!CGRect.zero.isInfinite)
            #expect(!CGRect.null.isInfinite)
        }

        @Test("isNull")
        func isNullProperty() {
            #expect(CGRect.null.isNull)
            #expect(!CGRect.zero.isNull)
            #expect(!CGRect.infinite.isNull)
        }
    }

    // MARK: - Derived Rectangles Tests

    @Suite("Derived Rectangles")
    struct DerivedRectanglesTests {

        @Test("Standardized rect with positive dimensions")
        func standardizedPositive() {
            let rect = CGRect(x: 10.0, y: 20.0, width: 100.0, height: 200.0)
            let standardized = rect.standardized
            #expect(standardized.origin.x.native == 10.0)
            #expect(standardized.origin.y.native == 20.0)
            #expect(standardized.size.width.native == 100.0)
            #expect(standardized.size.height.native == 200.0)
        }

        @Test("Standardized rect with negative width")
        func standardizedNegativeWidth() {
            let rect = CGRect(x: 10.0, y: 20.0, width: -100.0, height: 200.0)
            let standardized = rect.standardized
            #expect(standardized.origin.x.native == -90.0)
            #expect(standardized.size.width.native == 100.0)
        }

        @Test("Standardized rect with negative height")
        func standardizedNegativeHeight() {
            let rect = CGRect(x: 10.0, y: 20.0, width: 100.0, height: -200.0)
            let standardized = rect.standardized
            #expect(standardized.origin.y.native == -180.0)
            #expect(standardized.size.height.native == 200.0)
        }

        @Test("Standardized null rect")
        func standardizedNull() {
            let standardized = CGRect.null.standardized
            #expect(standardized.isNull)
        }

        @Test("Integral rect")
        func integralRect() {
            let rect = CGRect(x: 0.5, y: 0.5, width: 10.5, height: 10.5)
            let integral = rect.integral
            #expect(integral.origin.x.native == 0.0)
            #expect(integral.origin.y.native == 0.0)
            #expect(integral.size.width.native == 11.0)
            #expect(integral.size.height.native == 11.0)
        }

        @Test("Integral null rect")
        func integralNull() {
            let integral = CGRect.null.integral
            #expect(integral.isNull)
        }
    }

    // MARK: - Contains Tests

    @Suite("Contains Operations")
    struct ContainsTests {

        @Test("Contains point inside")
        func containsPointInside() {
            let rect = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0)
            #expect(rect.contains(CGPoint(x: 50.0, y: 50.0)))
        }

        @Test("Contains point on edge")
        func containsPointOnEdge() {
            let rect = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0)
            #expect(rect.contains(CGPoint(x: 0.0, y: 50.0)))
            #expect(rect.contains(CGPoint(x: 50.0, y: 0.0)))
        }

        @Test("Contains point outside")
        func containsPointOutside() {
            let rect = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0)
            #expect(!rect.contains(CGPoint(x: 150.0, y: 50.0)))
            #expect(!rect.contains(CGPoint(x: -10.0, y: 50.0)))
        }

        @Test("Contains point at maxX/maxY boundary")
        func containsPointAtMaxBoundary() {
            let rect = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0)
            #expect(!rect.contains(CGPoint(x: 100.0, y: 50.0)))
            #expect(!rect.contains(CGPoint(x: 50.0, y: 100.0)))
        }

        @Test("Empty rect contains no points")
        func emptyRectContainsNoPoints() {
            let empty = CGRect.zero
            #expect(!empty.contains(CGPoint(x: 0.0, y: 0.0)))
        }

        @Test("Null rect contains no points")
        func nullRectContainsNoPoints() {
            #expect(!CGRect.null.contains(CGPoint(x: 0.0, y: 0.0)))
        }

        @Test("Contains rect inside")
        func containsRectInside() {
            let outer = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0)
            let inner = CGRect(x: 25.0, y: 25.0, width: 50.0, height: 50.0)
            #expect(outer.contains(inner))
        }

        @Test("Contains rect overlapping")
        func containsRectOverlapping() {
            let rect1 = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0)
            let rect2 = CGRect(x: 50.0, y: 50.0, width: 100.0, height: 100.0)
            #expect(!rect1.contains(rect2))
        }

        @Test("Contains same rect")
        func containsSameRect() {
            let rect = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0)
            #expect(rect.contains(rect))
        }
    }

    // MARK: - Intersection Tests

    @Suite("Intersection Operations")
    struct IntersectionTests {

        @Test("Intersection of overlapping rects")
        func intersectionOverlapping() {
            let rect1 = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0)
            let rect2 = CGRect(x: 50.0, y: 50.0, width: 100.0, height: 100.0)
            let intersection = rect1.intersection(rect2)
            #expect(intersection.origin.x.native == 50.0)
            #expect(intersection.origin.y.native == 50.0)
            #expect(intersection.size.width.native == 50.0)
            #expect(intersection.size.height.native == 50.0)
        }

        @Test("Intersection of non-overlapping rects")
        func intersectionNonOverlapping() {
            let rect1 = CGRect(x: 0.0, y: 0.0, width: 50.0, height: 50.0)
            let rect2 = CGRect(x: 100.0, y: 100.0, width: 50.0, height: 50.0)
            let intersection = rect1.intersection(rect2)
            #expect(intersection.isNull)
        }

        @Test("Intersection with null rect")
        func intersectionWithNull() {
            let rect = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0)
            #expect(rect.intersection(CGRect.null).isNull)
            #expect(CGRect.null.intersection(rect).isNull)
        }

        @Test("Intersects overlapping")
        func intersectsOverlapping() {
            let rect1 = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0)
            let rect2 = CGRect(x: 50.0, y: 50.0, width: 100.0, height: 100.0)
            #expect(rect1.intersects(rect2))
        }

        @Test("Intersects non-overlapping")
        func intersectsNonOverlapping() {
            let rect1 = CGRect(x: 0.0, y: 0.0, width: 50.0, height: 50.0)
            let rect2 = CGRect(x: 100.0, y: 100.0, width: 50.0, height: 50.0)
            #expect(!rect1.intersects(rect2))
        }

        @Test("Intersects adjacent rects sharing edge")
        func intersectsAdjacent() {
            let rect1 = CGRect(x: 0.0, y: 0.0, width: 50.0, height: 50.0)
            let rect2 = CGRect(x: 50.0, y: 0.0, width: 50.0, height: 50.0)
            // Adjacent rects sharing an edge: the intersection is a line (zero area)
            // The implementation considers this as intersecting if the ranges overlap at the boundary
            let intersection = rect1.intersection(rect2)
            // They touch at x=50, which creates an intersection with zero width
            #expect(intersection.isEmpty || intersection.isNull)
        }
    }

    // MARK: - Union Tests

    @Suite("Union Operations")
    struct UnionTests {

        @Test("Union of overlapping rects")
        func unionOverlapping() {
            let rect1 = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0)
            let rect2 = CGRect(x: 50.0, y: 50.0, width: 100.0, height: 100.0)
            let union = rect1.union(rect2)
            #expect(union.origin.x.native == 0.0)
            #expect(union.origin.y.native == 0.0)
            #expect(union.size.width.native == 150.0)
            #expect(union.size.height.native == 150.0)
        }

        @Test("Union of separate rects")
        func unionSeparate() {
            let rect1 = CGRect(x: 0.0, y: 0.0, width: 50.0, height: 50.0)
            let rect2 = CGRect(x: 100.0, y: 100.0, width: 50.0, height: 50.0)
            let union = rect1.union(rect2)
            #expect(union.origin.x.native == 0.0)
            #expect(union.origin.y.native == 0.0)
            #expect(union.size.width.native == 150.0)
            #expect(union.size.height.native == 150.0)
        }

        @Test("Union with null rect")
        func unionWithNull() {
            let rect = CGRect(x: 10.0, y: 20.0, width: 100.0, height: 200.0)
            #expect(rect.union(CGRect.null) == rect)
            #expect(CGRect.null.union(rect) == rect)
        }

        @Test("Union of same rect")
        func unionSameRect() {
            let rect = CGRect(x: 10.0, y: 20.0, width: 100.0, height: 200.0)
            #expect(rect.union(rect) == rect)
        }
    }

    // MARK: - Inset and Offset Tests

    @Suite("Inset and Offset Operations")
    struct InsetOffsetTests {

        @Test("Inset by positive values")
        func insetByPositive() {
            let rect = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0)
            let inset = rect.insetBy(dx: 10.0, dy: 20.0)
            #expect(inset.origin.x.native == 10.0)
            #expect(inset.origin.y.native == 20.0)
            #expect(inset.size.width.native == 80.0)
            #expect(inset.size.height.native == 60.0)
        }

        @Test("Inset by negative values expands")
        func insetByNegative() {
            let rect = CGRect(x: 10.0, y: 10.0, width: 80.0, height: 80.0)
            let inset = rect.insetBy(dx: -10.0, dy: -10.0)
            #expect(inset.origin.x.native == 0.0)
            #expect(inset.origin.y.native == 0.0)
            #expect(inset.size.width.native == 100.0)
            #expect(inset.size.height.native == 100.0)
        }

        @Test("Inset resulting in zero dimension")
        func insetResultingInZero() {
            let rect = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0)
            let inset = rect.insetBy(dx: 50.0, dy: 50.0)
            #expect(inset.size.width.native == 0.0)
            #expect(inset.size.height.native == 0.0)
        }

        @Test("Inset resulting in null")
        func insetResultingInNull() {
            let rect = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0)
            let inset = rect.insetBy(dx: 60.0, dy: 60.0)
            #expect(inset.isNull)
        }

        @Test("Inset null rect")
        func insetNullRect() {
            let inset = CGRect.null.insetBy(dx: 10.0, dy: 10.0)
            #expect(inset.isNull)
        }

        @Test("Offset by positive values")
        func offsetByPositive() {
            let rect = CGRect(x: 10.0, y: 20.0, width: 100.0, height: 200.0)
            let offset = rect.offsetBy(dx: 5.0, dy: 10.0)
            #expect(offset.origin.x.native == 15.0)
            #expect(offset.origin.y.native == 30.0)
            #expect(offset.size.width.native == 100.0)
            #expect(offset.size.height.native == 200.0)
        }

        @Test("Offset by negative values")
        func offsetByNegative() {
            let rect = CGRect(x: 10.0, y: 20.0, width: 100.0, height: 200.0)
            let offset = rect.offsetBy(dx: -5.0, dy: -10.0)
            #expect(offset.origin.x.native == 5.0)
            #expect(offset.origin.y.native == 10.0)
        }

        @Test("Offset null rect")
        func offsetNullRect() {
            let offset = CGRect.null.offsetBy(dx: 10.0, dy: 10.0)
            #expect(offset.isNull)
        }
    }

    // MARK: - Divided Tests

    @Suite("Divided Operations")
    struct DividedTests {

        @Test("Divide from minXEdge")
        func divideFromMinX() {
            let rect = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0)
            let (slice, remainder) = rect.divided(atDistance: 30.0, from: .minXEdge)
            #expect(slice.origin.x.native == 0.0)
            #expect(slice.size.width.native == 30.0)
            #expect(remainder.origin.x.native == 30.0)
            #expect(remainder.size.width.native == 70.0)
        }

        @Test("Divide from maxXEdge")
        func divideFromMaxX() {
            let rect = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0)
            let (slice, remainder) = rect.divided(atDistance: 30.0, from: .maxXEdge)
            #expect(slice.origin.x.native == 70.0)
            #expect(slice.size.width.native == 30.0)
            #expect(remainder.origin.x.native == 0.0)
            #expect(remainder.size.width.native == 70.0)
        }

        @Test("Divide from minYEdge")
        func divideFromMinY() {
            let rect = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0)
            let (slice, remainder) = rect.divided(atDistance: 30.0, from: .minYEdge)
            #expect(slice.origin.y.native == 0.0)
            #expect(slice.size.height.native == 30.0)
            #expect(remainder.origin.y.native == 30.0)
            #expect(remainder.size.height.native == 70.0)
        }

        @Test("Divide from maxYEdge")
        func divideFromMaxY() {
            let rect = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0)
            let (slice, remainder) = rect.divided(atDistance: 30.0, from: .maxYEdge)
            #expect(slice.origin.y.native == 70.0)
            #expect(slice.size.height.native == 30.0)
            #expect(remainder.origin.y.native == 0.0)
            #expect(remainder.size.height.native == 70.0)
        }

        @Test("Divide with distance larger than dimension")
        func divideLargeDistance() {
            let rect = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0)
            let (slice, remainder) = rect.divided(atDistance: 150.0, from: .minXEdge)
            #expect(slice.size.width.native == 100.0)
            #expect(remainder.size.width.native == 0.0)
        }

        @Test("Divide null rect")
        func divideNullRect() {
            let (slice, remainder) = CGRect.null.divided(atDistance: 30.0, from: .minXEdge)
            #expect(slice.isNull)
            #expect(remainder.isNull)
        }
    }

    // MARK: - Affine Transform Tests

    @Suite("Affine Transform")
    struct AffineTransformTests {

        @Test("Apply identity transform")
        func applyIdentity() {
            let rect = CGRect(x: 10.0, y: 20.0, width: 100.0, height: 200.0)
            let transformed = rect.applying(CGAffineTransform.identity)
            #expect(transformed == rect)
        }

        @Test("Apply translation transform")
        func applyTranslation() {
            let rect = CGRect(x: 10.0, y: 20.0, width: 100.0, height: 200.0)
            let transform = CGAffineTransform(translationX: 5.0, y: 10.0)
            let transformed = rect.applying(transform)
            #expect(transformed.origin.x.native == 15.0)
            #expect(transformed.origin.y.native == 30.0)
            #expect(transformed.size.width.native == 100.0)
            #expect(transformed.size.height.native == 200.0)
        }

        @Test("Apply scale transform")
        func applyScale() {
            let rect = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 50.0)
            let transform = CGAffineTransform(scaleX: 2.0, y: 3.0)
            let transformed = rect.applying(transform)
            #expect(transformed.size.width.native == 200.0)
            #expect(transformed.size.height.native == 150.0)
        }

        @Test("Apply rotation transform")
        func applyRotation() {
            let rect = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 50.0)
            let transform = CGAffineTransform(rotationAngle: CGFloat.pi / 2)
            let transformed = rect.applying(transform)
            #expect(abs(transformed.size.width.native - 50.0) < 0.0001)
            #expect(abs(transformed.size.height.native - 100.0) < 0.0001)
        }

        @Test("Apply transform to null rect")
        func applyToNull() {
            let transformed = CGRect.null.applying(CGAffineTransform(translationX: 10.0, y: 10.0))
            #expect(transformed.isNull)
        }
    }

    // MARK: - Equatable Tests

    @Suite("Equatable Conformance")
    struct EquatableTests {

        @Test("Equal rects")
        func equalRects() {
            let r1 = CGRect(x: 10.0, y: 20.0, width: 100.0, height: 200.0)
            let r2 = CGRect(x: 10.0, y: 20.0, width: 100.0, height: 200.0)
            #expect(r1 == r2)
        }

        @Test("Unequal rects different origin")
        func unequalRectsDifferentOrigin() {
            let r1 = CGRect(x: 10.0, y: 20.0, width: 100.0, height: 200.0)
            let r2 = CGRect(x: 15.0, y: 20.0, width: 100.0, height: 200.0)
            #expect(r1 != r2)
        }

        @Test("Unequal rects different size")
        func unequalRectsDifferentSize() {
            let r1 = CGRect(x: 10.0, y: 20.0, width: 100.0, height: 200.0)
            let r2 = CGRect(x: 10.0, y: 20.0, width: 150.0, height: 200.0)
            #expect(r1 != r2)
        }

        @Test("Null rect equality")
        func nullRectEquality() {
            #expect(CGRect.null == CGRect.null)
        }

        @Test("equalTo method")
        func equalToMethod() {
            let r1 = CGRect(x: 10.0, y: 20.0, width: 100.0, height: 200.0)
            let r2 = CGRect(x: 10.0, y: 20.0, width: 100.0, height: 200.0)
            #expect(r1.equalTo(r2))
        }
    }

    // MARK: - Hashable Tests

    @Suite("Hashable Conformance")
    struct HashableTests {

        @Test("Equal rects have equal hashes")
        func equalRectsEqualHashes() {
            let r1 = CGRect(x: 10.0, y: 20.0, width: 100.0, height: 200.0)
            let r2 = CGRect(x: 10.0, y: 20.0, width: 100.0, height: 200.0)
            #expect(r1.hashValue == r2.hashValue)
        }

        @Test("Can be used in Set")
        func setUsage() {
            var set = Set<CGRect>()
            set.insert(CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0))
            set.insert(CGRect(x: 50.0, y: 50.0, width: 100.0, height: 100.0))
            set.insert(CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0))
            #expect(set.count == 2)
        }
    }

    // MARK: - Codable Tests

    @Suite("Codable Conformance")
    struct CodableTests {

        @Test("Encode and decode")
        func encodeAndDecode() throws {
            let original = CGRect(x: 10.5, y: 20.5, width: 100.5, height: 200.5)
            let encoder = JSONEncoder()
            let data = try encoder.encode(original)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(CGRect.self, from: data)
            #expect(original == decoded)
        }

        @Test("Encode and decode zero rect")
        func encodeAndDecodeZero() throws {
            let original = CGRect.zero
            let encoder = JSONEncoder()
            let data = try encoder.encode(original)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(CGRect.self, from: data)
            #expect(original == decoded)
        }
    }
}

// MARK: - CGRectEdge Tests

@Suite("CGRectEdge Tests")
struct CGRectEdgeTests {

    @Test("Raw values")
    func rawValues() {
        #expect(CGRectEdge.minXEdge.rawValue == 0)
        #expect(CGRectEdge.minYEdge.rawValue == 1)
        #expect(CGRectEdge.maxXEdge.rawValue == 2)
        #expect(CGRectEdge.maxYEdge.rawValue == 3)
    }

    @Test("Init from raw value")
    func initFromRawValue() {
        #expect(CGRectEdge(rawValue: 0) == .minXEdge)
        #expect(CGRectEdge(rawValue: 1) == .minYEdge)
        #expect(CGRectEdge(rawValue: 2) == .maxXEdge)
        #expect(CGRectEdge(rawValue: 3) == .maxYEdge)
        #expect(CGRectEdge(rawValue: 4) == nil)
    }
}
