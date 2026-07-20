//
//  CGPathOperationsTests.swift
//  OpenCoreGraphics
//
//  Tests for the iOS 16+ CGPath geometric operations:
//  flattened, union, intersection, subtracting, symmetricDifference,
//  lineIntersection, lineSubtracting, intersects, normalized,
//  componentsSeparated.
//

import Testing
import Foundation
@testable import OpenCoreGraphics


@Suite("CGPath Geometric Operations")
struct CGPathOperationsTests {

    // MARK: - Helpers

    private func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGPath {
        return CGPath(rect: CGRect(x: x, y: y, width: w, height: h))
    }

    /// Approximate equality for bounding boxes (flattening introduces small
    /// numerical error for curved inputs).
    private func boundingBoxIsApproximately(_ path: CGPath,
                                            _ expected: CGRect,
                                            tolerance: CGFloat = 1.0) -> Bool {
        let bb = path.boundingBoxOfPath
        return abs(bb.minX - expected.minX) <= tolerance
            && abs(bb.minY - expected.minY) <= tolerance
            && abs(bb.maxX - expected.maxX) <= tolerance
            && abs(bb.maxY - expected.maxY) <= tolerance
    }


    // MARK: - Flattened

    @Test("flattened converts a rect unchanged (already linear)")
    func flattenedRectIsLinear() {
        let r = rect(0, 0, 10, 10)
        let f = r.flattened(threshold: 0.5)
        #expect(!f.isEmpty)
        let expected = CGRect(x: 0, y: 0, width: 10, height: 10)
        #expect(f.boundingBoxOfPath == expected)
    }

    @Test("flattened ellipse produces many segments with similar bbox")
    func flattenedEllipseBoundingBox() {
        let ellipseRect = CGRect(x: 0, y: 0, width: 100, height: 50)
        let ellipse = CGPath(ellipseIn: ellipseRect)
        let flat = ellipse.flattened(threshold: 0.25)
        #expect(boundingBoxIsApproximately(flat, ellipseRect, tolerance: 0.5))
        // Expect many line segments (no cubic elements) — much more than the
        // 4 cubic commands the original ellipse was built from.
        var segmentCount = 0
        flat.applyWithBlock { element in
            if element.pointee.type == .addLineToPoint { segmentCount += 1 }
        }
        #expect(segmentCount > 30)
    }


    // MARK: - Union

    @Test("union of two non-overlapping rects keeps both")
    func unionDisjoint() {
        let a = rect(0, 0, 10, 10)
        let b = rect(20, 20, 10, 10)
        let u = a.union(b)
        let bb = u.boundingBoxOfPath
        let expected: CGRect = CGRect(x: 0, y: 0, width: 30, height: 30)
        #expect(bb == expected)
    }

    @Test("union of two overlapping rects merges into single area")
    func unionOverlapping() {
        let a = rect(0, 0, 20, 20)
        let b = rect(10, 10, 20, 20)
        let u = a.union(b)
        let expected = CGRect(x: 0, y: 0, width: 30, height: 30)
        #expect(boundingBoxIsApproximately(u, expected, tolerance: 0.01))
    }

    @Test("union with fully-contained rect returns the larger rect")
    func unionContaining() {
        let outer = rect(0, 0, 100, 100)
        let inner = rect(40, 40, 20, 20)
        let u = outer.union(inner)
        let expected = CGRect(x: 0, y: 0, width: 100, height: 100)
        #expect(boundingBoxIsApproximately(u, expected, tolerance: 0.01))
    }


    // MARK: - Intersection

    @Test("intersection of two overlapping rects is the overlap rect")
    func intersectionOverlap() {
        let a = rect(0, 0, 20, 20)
        let b = rect(10, 10, 20, 20)
        let i = a.intersection(b)
        let expected = CGRect(x: 10, y: 10, width: 10, height: 10)
        #expect(boundingBoxIsApproximately(i, expected, tolerance: 0.01))
    }

    @Test("intersection of disjoint rects is empty")
    func intersectionDisjoint() {
        let a = rect(0, 0, 10, 10)
        let b = rect(20, 20, 10, 10)
        let i = a.intersection(b)
        #expect(i.isEmpty)
    }

    @Test("intersection with fully-contained rect returns inner rect")
    func intersectionContaining() {
        let outer = rect(0, 0, 100, 100)
        let inner = rect(40, 40, 20, 20)
        let i = outer.intersection(inner)
        let expected = CGRect(x: 40, y: 40, width: 20, height: 20)
        #expect(boundingBoxIsApproximately(i, expected, tolerance: 0.01))
    }


    // MARK: - Subtracting

    @Test("subtracting disjoint rect returns original")
    func subtractingDisjoint() {
        let a = rect(0, 0, 10, 10)
        let b = rect(20, 20, 10, 10)
        let d = a.subtracting(b)
        let expected = CGRect(x: 0, y: 0, width: 10, height: 10)
        #expect(boundingBoxIsApproximately(d, expected, tolerance: 0.01))
    }

    @Test("subtracting fully-containing rect returns empty")
    func subtractingContaining() {
        let a = rect(40, 40, 20, 20)
        let big = rect(0, 0, 100, 100)
        let d = a.subtracting(big)
        #expect(d.isEmpty)
    }


    // MARK: - Symmetric Difference

    @Test("symmetricDifference of disjoint rects contains both")
    func xorDisjoint() {
        let a = rect(0, 0, 10, 10)
        let b = rect(20, 20, 10, 10)
        let x = a.symmetricDifference(b)
        let expected = CGRect(x: 0, y: 0, width: 30, height: 30)
        #expect(boundingBoxIsApproximately(x, expected, tolerance: 0.01))
    }

    @Test("symmetricDifference of identical rects is empty")
    func xorIdentical() {
        let a = rect(0, 0, 10, 10)
        let b = rect(0, 0, 10, 10)
        let x = a.symmetricDifference(b)
        // Identical rects cancel entirely.
        #expect(x.isEmpty || x.boundingBoxOfPath.width < 0.01)
    }


    // MARK: - Intersects

    @Test("intersects is true for overlapping rects")
    func intersectsOverlapping() {
        let a = rect(0, 0, 20, 20)
        let b = rect(10, 10, 20, 20)
        #expect(a.intersects(b))
    }

    @Test("intersects is false for disjoint rects")
    func intersectsDisjoint() {
        let a = rect(0, 0, 10, 10)
        let b = rect(20, 20, 10, 10)
        #expect(!a.intersects(b))
    }

    @Test("intersects is true when one rect contains the other")
    func intersectsContaining() {
        let outer = rect(0, 0, 100, 100)
        let inner = rect(40, 40, 20, 20)
        #expect(outer.intersects(inner))
        #expect(inner.intersects(outer))
    }

    @Test("intersects includes the closing edge of closed subpaths")
    func intersectsClosingEdge() {
        let closedPath = CGMutablePath()
        closedPath.move(to: CGPoint(x: 0, y: 0))
        closedPath.addLine(to: CGPoint(x: 10, y: 0))
        closedPath.addLine(to: CGPoint(x: 10, y: 10))
        closedPath.addLine(to: CGPoint(x: 0, y: 10))
        closedPath.closeSubpath()

        let crossingPath = CGMutablePath()
        crossingPath.move(to: CGPoint(x: -1, y: 4))
        crossingPath.addLine(to: CGPoint(x: 1, y: 4))
        crossingPath.addLine(to: CGPoint(x: 1, y: 6))
        crossingPath.addLine(to: CGPoint(x: -1, y: 6))
        crossingPath.closeSubpath()

        #expect(closedPath.intersects(crossingPath))
    }


    // MARK: - Normalized

    @Test("normalized drops zero-area subpaths")
    func normalizedDropsZeroArea() {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 10, y: 0))
        path.addLine(to: CGPoint(x: 10, y: 0))      // zero-length
        path.closeSubpath()
        path.addRect(CGRect(x: 20, y: 20, width: 10, height: 10))
        let n = path.normalized()
        // Zero-area triangle is removed; only the rect subpath remains.
        let expected = CGRect(x: 20, y: 20, width: 10, height: 10)
        #expect(boundingBoxIsApproximately(n, expected, tolerance: 0.01))
    }

    @Test("normalized applies winding and even-odd rules to nested contours")
    func normalizedAppliesFillRule() {
        let path = CGMutablePath()
        addOrientedRect(CGRect(x: 0, y: 0, width: 10, height: 10), clockwise: false, to: path)
        addOrientedRect(CGRect(x: 2, y: 2, width: 6, height: 6), clockwise: false, to: path)

        let winding = path.normalized(using: .winding)
        let evenOdd = path.normalized(using: .evenOdd)
        #expect(winding.contains(CGPoint(x: 5, y: 5), using: .winding))
        #expect(!evenOdd.contains(CGPoint(x: 5, y: 5), using: .winding))
        #expect(winding.commands.count == 5)
        #expect(evenOdd.commands.count == 10)
    }


    // MARK: - Components Separated

    @Test("componentsSeparated returns one path per subpath")
    func componentsSeparatedCount() {
        let path = CGMutablePath()
        path.addRect(CGRect(x: 0, y: 0, width: 10, height: 10))
        path.addRect(CGRect(x: 20, y: 0, width: 10, height: 10))
        path.addRect(CGRect(x: 40, y: 0, width: 10, height: 10))
        let components = path.componentsSeparated()
        #expect(components.count == 3)
    }

    @Test("componentsSeparated preserves bounding boxes of each subpath")
    func componentsSeparatedBoxes() {
        let path = CGMutablePath()
        path.addRect(CGRect(x: 0, y: 0, width: 10, height: 10))
        path.addRect(CGRect(x: 100, y: 100, width: 20, height: 20))
        let components = path.componentsSeparated()
        #expect(components.count == 2)
        let boxes: [CGRect] = [
            CGRect(x: 0, y: 0, width: 10, height: 10),
            CGRect(x: 100, y: 100, width: 20, height: 20)
        ]
        for expected in boxes {
            let matches = components.contains { boundingBoxIsApproximately($0, expected, tolerance: 0.01) }
            #expect(matches)
        }
    }

    @Test("componentsSeparated keeps a hole with its enclosing component")
    func componentsSeparatedGroupsHole() throws {
        let path = CGMutablePath()
        addOrientedRect(CGRect(x: 0, y: 0, width: 20, height: 20), clockwise: false, to: path)
        addOrientedRect(CGRect(x: 3, y: 3, width: 14, height: 14), clockwise: true, to: path)

        let component = try #require(path.componentsSeparated(using: .winding).only)
        #expect(component.contains(CGPoint(x: 1, y: 1), using: .winding))
        #expect(!component.contains(CGPoint(x: 5, y: 5), using: .winding))
        #expect(component.commands.count == 10)
    }

    @Test("componentsSeparated returns filled islands as independent components")
    func componentsSeparatedExtractsIsland() {
        let path = CGMutablePath()
        addOrientedRect(CGRect(x: 0, y: 0, width: 20, height: 20), clockwise: false, to: path)
        addOrientedRect(CGRect(x: 3, y: 3, width: 14, height: 14), clockwise: true, to: path)
        addOrientedRect(CGRect(x: 7, y: 7, width: 6, height: 6), clockwise: false, to: path)

        let components = path.componentsSeparated(using: .winding)
        #expect(components.count == 2)
        #expect(components.contains { $0.contains(CGPoint(x: 1, y: 1), using: .winding) })
        #expect(components.contains { $0.contains(CGPoint(x: 10, y: 10), using: .winding) })
    }


    // MARK: - Line Operations

    @Test("lineIntersection of open line vs rect keeps inside portion")
    func lineIntersectionSimple() {
        let line = CGMutablePath()
        line.move(to: CGPoint(x: -10, y: 5))
        line.addLine(to: CGPoint(x: 30, y: 5))

        let clipRect = rect(0, 0, 20, 20)
        let clipped = line.lineIntersection(clipRect)
        // Expected inside portion: x in [0, 20], y = 5
        let bb = clipped.boundingBoxOfPath
        #expect(abs(bb.minX - 0) < 0.01)
        #expect(abs(bb.maxX - 20) < 0.01)
        #expect(abs(bb.minY - 5) < 0.01)
        #expect(abs(bb.maxY - 5) < 0.01)
    }

    @Test("lineSubtracting of open line vs rect keeps outside portions")
    func lineSubtractingSimple() {
        let line = CGMutablePath()
        line.move(to: CGPoint(x: -10, y: 5))
        line.addLine(to: CGPoint(x: 30, y: 5))

        let clipRect = rect(0, 0, 20, 20)
        let outside = line.lineSubtracting(clipRect)
        let bb = outside.boundingBoxOfPath
        #expect(abs(bb.minX - -10) < 0.01)
        #expect(abs(bb.maxX - 30) < 0.01)
        #expect(abs(bb.minY - 5) < 0.01)
    }
}

private extension CGPathOperationsTests {
    func addOrientedRect(_ rect: CGRect, clockwise: Bool, to path: CGMutablePath) {
        let counterclockwise = [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.maxY),
        ]
        let points = clockwise ? Array(counterclockwise.reversed()) : counterclockwise
        guard let first = points.first else { return }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
    }
}

private extension Array {
    var only: Element? {
        count == 1 ? self[0] : nil
    }
}
