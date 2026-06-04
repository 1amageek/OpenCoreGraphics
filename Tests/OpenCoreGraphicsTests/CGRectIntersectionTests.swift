//
//  CGRectIntersectionTests.swift
//  OpenCoreGraphics
//
//  Tests for CGRect.intersection strict-inequality behavior.
//  Touching edges must return a zero-area rect (matching Apple's
//  CoreGraphics), not `.null`. Only truly disjoint rectangles return `.null`.
//

import Foundation
import Testing
@testable import OpenCoreGraphics

// Use Foundation's CGRect explicitly so the OpenCoreGraphics extension
// (`intersection`, `.null`, `.isNull`) is exercised against the same struct
// shape CoreGraphics exposes.
private typealias CGRect = Foundation.CGRect

@Suite("CGRect.intersection Tests")
struct CGRectIntersectionTests {

    @Test("intersection of overlapping rects returns positive-area rect")
    func intersection_overlapping_returnsPositiveAreaRect() {
        let a = CGRect(x: 0, y: 0, width: 10, height: 10)
        let b = CGRect(x: 5, y: 5, width: 10, height: 10)
        let result = a.intersection(b)

        #expect(!result.isNull)
        #expect(result.origin.x == 5)
        #expect(result.origin.y == 5)
        #expect(result.size.width == 5)
        #expect(result.size.height == 5)
    }

    @Test("intersection touching at right edge returns zero-width rect, not null")
    func intersection_touchingRightEdge_returnsZeroWidthRect() {
        let a = CGRect(x: 0, y: 0, width: 10, height: 10)
        let b = CGRect(x: 10, y: 0, width: 10, height: 10)
        let result = a.intersection(b)

        #expect(!result.isNull, "Touching edges must yield a zero-area rect, not .null")
        #expect(result.origin.x == 10)
        #expect(result.origin.y == 0)
        #expect(result.size.width == 0)
        #expect(result.size.height == 10)
    }

    @Test("intersection touching at left edge returns zero-width rect, not null")
    func intersection_touchingLeftEdge_returnsZeroWidthRect() {
        // b shares its right edge with a's left edge.
        let a = CGRect(x: 10, y: 0, width: 10, height: 10)
        let b = CGRect(x: 0, y: 0, width: 10, height: 10)
        let result = a.intersection(b)

        #expect(!result.isNull)
        #expect(result.origin.x == 10)
        #expect(result.size.width == 0)
        #expect(result.size.height == 10)
    }

    @Test("intersection touching at bottom edge returns zero-height rect, not null")
    func intersection_touchingBottomEdge_returnsZeroHeightRect() {
        let a = CGRect(x: 0, y: 0, width: 10, height: 10)
        let b = CGRect(x: 0, y: 10, width: 10, height: 10)
        let result = a.intersection(b)

        #expect(!result.isNull, "Touching edges must yield a zero-area rect, not .null")
        #expect(result.origin.x == 0)
        #expect(result.origin.y == 10)
        #expect(result.size.width == 10)
        #expect(result.size.height == 0)
    }

    @Test("intersection touching at a single corner returns zero-area rect, not null")
    func intersection_touchingCorner_returnsZeroAreaRect() {
        // a's bottom-right corner equals b's top-left corner.
        let a = CGRect(x: 0, y: 0, width: 10, height: 10)
        let b = CGRect(x: 10, y: 10, width: 10, height: 10)
        let result = a.intersection(b)

        #expect(!result.isNull)
        #expect(result.size.width == 0)
        #expect(result.size.height == 0)
    }

    @Test("intersection of truly disjoint rects returns null")
    func intersection_disjointWithGap_returnsNull() {
        // There is a 1-unit gap between a.maxX (10) and b.minX (11).
        let a = CGRect(x: 0, y: 0, width: 10, height: 10)
        let b = CGRect(x: 11, y: 0, width: 10, height: 10)
        let result = a.intersection(b)

        #expect(result.isNull)
    }

    @Test("intersection of vertically disjoint rects returns null")
    func intersection_verticallyDisjoint_returnsNull() {
        let a = CGRect(x: 0, y: 0, width: 10, height: 10)
        let b = CGRect(x: 0, y: 20, width: 10, height: 10)
        let result = a.intersection(b)

        #expect(result.isNull)
    }

    @Test("intersects returns false for touching edges (matches Apple's CGRectIntersectsRect)")
    func intersects_touchingEdges_returnsFalse() {
        // Apple's docs: "Two rectangles that share only a boundary are
        // considered to be nonintersecting." `intersection(_:)` returns a
        // zero-area rect for touching edges, but `intersects(_:)` must reject
        // the empty intersection.
        let a = CGRect(x: 0, y: 0, width: 10, height: 10)
        let b = CGRect(x: 10, y: 0, width: 10, height: 10)
        #expect(!a.intersects(b))
    }

    @Test("intersects returns false for rects with a gap")
    func intersects_disjoint_returnsFalse() {
        let a = CGRect(x: 0, y: 0, width: 10, height: 10)
        let b = CGRect(x: 11, y: 0, width: 10, height: 10)
        #expect(!a.intersects(b))
    }
}
