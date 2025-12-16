//
//  CGPointTests.swift
//  OpenCoreGraphics
//
//  Tests for CGPoint type
//

import Foundation
import Testing
@testable import OpenCoreGraphics

// Type aliases to avoid ambiguity with CoreFoundation types on macOS
private typealias CGFloat = OpenCoreGraphics.CGFloat
private typealias CGPoint = OpenCoreGraphics.CGPoint
private typealias CGAffineTransform = OpenCoreGraphics.CGAffineTransform

@Suite("CGPoint Tests")
struct CGPointTests {

    // MARK: - Initialization Tests

    @Suite("Initialization")
    struct InitializationTests {

        @Test("Default initializer creates zero point")
        func defaultInit() {
            let point = CGPoint()
            #expect(point.x.native == 0.0)
            #expect(point.y.native == 0.0)
        }

        @Test("Init with CGFloat coordinates")
        func initWithCGFloat() {
            let point = CGPoint(x: CGFloat(10.0), y: CGFloat(20.0))
            #expect(point.x.native == 10.0)
            #expect(point.y.native == 20.0)
        }

        @Test("Init with Double coordinates")
        func initWithDouble() {
            let point = CGPoint(x: 10.5, y: 20.5)
            #expect(point.x.native == 10.5)
            #expect(point.y.native == 20.5)
        }

        @Test("Init with Int coordinates")
        func initWithInt() {
            let point = CGPoint(x: 10, y: 20)
            #expect(point.x.native == 10.0)
            #expect(point.y.native == 20.0)
        }

        @Test("Init with negative coordinates")
        func initWithNegative() {
            let point = CGPoint(x: -5.0, y: -10.0)
            #expect(point.x.native == -5.0)
            #expect(point.y.native == -10.0)
        }
    }

    // MARK: - Static Properties Tests

    @Suite("Static Properties")
    struct StaticPropertiesTests {

        @Test("Zero point")
        func zeroPoint() {
            let zero = CGPoint.zero
            #expect(zero.x.native == 0.0)
            #expect(zero.y.native == 0.0)
        }
    }

    // MARK: - Property Mutation Tests

    @Suite("Property Mutation")
    struct PropertyMutationTests {

        @Test("Mutate x coordinate")
        func mutateX() {
            var point = CGPoint(x: 10.0, y: 20.0)
            point.x = CGFloat(50.0)
            #expect(point.x.native == 50.0)
            #expect(point.y.native == 20.0)
        }

        @Test("Mutate y coordinate")
        func mutateY() {
            var point = CGPoint(x: 10.0, y: 20.0)
            point.y = CGFloat(50.0)
            #expect(point.x.native == 10.0)
            #expect(point.y.native == 50.0)
        }
    }

    // MARK: - Equatable Tests

    @Suite("Equatable Conformance")
    struct EquatableTests {

        @Test("Equal points")
        func equalPoints() {
            let p1 = CGPoint(x: 10.0, y: 20.0)
            let p2 = CGPoint(x: 10.0, y: 20.0)
            #expect(p1 == p2)
        }

        @Test("Unequal points different x")
        func unequalPointsDifferentX() {
            let p1 = CGPoint(x: 10.0, y: 20.0)
            let p2 = CGPoint(x: 15.0, y: 20.0)
            #expect(p1 != p2)
        }

        @Test("Unequal points different y")
        func unequalPointsDifferentY() {
            let p1 = CGPoint(x: 10.0, y: 20.0)
            let p2 = CGPoint(x: 10.0, y: 25.0)
            #expect(p1 != p2)
        }

        @Test("equalTo method")
        func equalToMethod() {
            let p1 = CGPoint(x: 10.0, y: 20.0)
            let p2 = CGPoint(x: 10.0, y: 20.0)
            let p3 = CGPoint(x: 15.0, y: 20.0)
            #expect(p1.equalTo(p2))
            #expect(!p1.equalTo(p3))
        }

        @Test("Zero point equality")
        func zeroPointEquality() {
            let zero1 = CGPoint()
            let zero2 = CGPoint.zero
            #expect(zero1 == zero2)
        }
    }

    // MARK: - Hashable Tests

    @Suite("Hashable Conformance")
    struct HashableTests {

        @Test("Equal points have equal hashes")
        func equalPointsEqualHashes() {
            let p1 = CGPoint(x: 10.0, y: 20.0)
            let p2 = CGPoint(x: 10.0, y: 20.0)
            #expect(p1.hashValue == p2.hashValue)
        }

        @Test("Can be used in Set")
        func setUsage() {
            var set = Set<CGPoint>()
            set.insert(CGPoint(x: 1.0, y: 2.0))
            set.insert(CGPoint(x: 3.0, y: 4.0))
            set.insert(CGPoint(x: 1.0, y: 2.0))
            #expect(set.count == 2)
        }

        @Test("Can be used as Dictionary key")
        func dictionaryUsage() {
            var dict: [CGPoint: String] = [:]
            dict[CGPoint(x: 1.0, y: 2.0)] = "point1"
            dict[CGPoint(x: 3.0, y: 4.0)] = "point2"
            #expect(dict[CGPoint(x: 1.0, y: 2.0)] == "point1")
        }
    }

    // MARK: - Affine Transform Tests

    @Suite("Affine Transform")
    struct AffineTransformTests {

        @Test("Apply identity transform")
        func applyIdentity() {
            let point = CGPoint(x: 10.0, y: 20.0)
            let transformed = point.applying(CGAffineTransform.identity)
            #expect(transformed == point)
        }

        @Test("Apply translation transform")
        func applyTranslation() {
            let point = CGPoint(x: 10.0, y: 20.0)
            let transform = CGAffineTransform(translationX: 5.0, y: 10.0)
            let transformed = point.applying(transform)
            #expect(transformed.x.native == 15.0)
            #expect(transformed.y.native == 30.0)
        }

        @Test("Apply scale transform")
        func applyScale() {
            let point = CGPoint(x: 10.0, y: 20.0)
            let transform = CGAffineTransform(scaleX: 2.0, y: 3.0)
            let transformed = point.applying(transform)
            #expect(transformed.x.native == 20.0)
            #expect(transformed.y.native == 60.0)
        }

        @Test("Apply rotation transform 90 degrees")
        func applyRotation90() {
            let point = CGPoint(x: 1.0, y: 0.0)
            let transform = CGAffineTransform(rotationAngle: CGFloat.pi / 2)
            let transformed = point.applying(transform)
            #expect(abs(transformed.x.native - 0.0) < 0.0001)
            #expect(abs(transformed.y.native - 1.0) < 0.0001)
        }

        @Test("Apply rotation transform 180 degrees")
        func applyRotation180() {
            let point = CGPoint(x: 1.0, y: 0.0)
            let transform = CGAffineTransform(rotationAngle: CGFloat.pi)
            let transformed = point.applying(transform)
            #expect(abs(transformed.x.native - (-1.0)) < 0.0001)
            #expect(abs(transformed.y.native - 0.0) < 0.0001)
        }

        @Test("Apply combined transform")
        func applyCombinedTransform() {
            let point = CGPoint(x: 1.0, y: 0.0)
            let scale = CGAffineTransform(scaleX: 2.0, y: 2.0)
            let translate = CGAffineTransform(translationX: 10.0, y: 10.0)
            let combined = scale.concatenating(translate)
            let transformed = point.applying(combined)
            #expect(transformed.x.native == 12.0)
            #expect(transformed.y.native == 10.0)
        }

        @Test("Apply transform to zero point")
        func applyToZero() {
            let point = CGPoint.zero
            let transform = CGAffineTransform(translationX: 5.0, y: 10.0)
            let transformed = point.applying(transform)
            #expect(transformed.x.native == 5.0)
            #expect(transformed.y.native == 10.0)
        }
    }

    // MARK: - Codable Tests

    @Suite("Codable Conformance")
    struct CodableTests {

        @Test("Encode and decode")
        func encodeAndDecode() throws {
            let original = CGPoint(x: 10.5, y: 20.5)
            let encoder = JSONEncoder()
            let data = try encoder.encode(original)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(CGPoint.self, from: data)
            #expect(original == decoded)
        }

        @Test("Encode and decode zero point")
        func encodeAndDecodeZero() throws {
            let original = CGPoint.zero
            let encoder = JSONEncoder()
            let data = try encoder.encode(original)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(CGPoint.self, from: data)
            #expect(original == decoded)
        }

        @Test("Encode and decode negative coordinates")
        func encodeAndDecodeNegative() throws {
            let original = CGPoint(x: -100.5, y: -200.5)
            let encoder = JSONEncoder()
            let data = try encoder.encode(original)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(CGPoint.self, from: data)
            #expect(original == decoded)
        }

        @Test("JSON structure contains x and y keys")
        func jsonStructure() throws {
            let point = CGPoint(x: 10.0, y: 20.0)
            let encoder = JSONEncoder()
            let data = try encoder.encode(point)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            #expect(json?["x"] != nil)
            #expect(json?["y"] != nil)
        }
    }

    // MARK: - Debug Description Tests

    @Suite("Debug Description")
    struct DebugDescriptionTests {

        @Test("Debug description format")
        func debugDescriptionFormat() {
            let point = CGPoint(x: 10.0, y: 20.0)
            #expect(point.debugDescription.contains("10"))
            #expect(point.debugDescription.contains("20"))
        }

        @Test("Debug description for zero point")
        func debugDescriptionZero() {
            let point = CGPoint.zero
            #expect(point.debugDescription.contains("0"))
        }
    }

    // MARK: - Edge Cases

    @Suite("Edge Cases")
    struct EdgeCaseTests {

        @Test("Very large coordinates")
        func veryLargeCoordinates() {
            let large = CGFloat.greatestFiniteMagnitude / 2
            let point = CGPoint(x: large, y: large)
            #expect(point.x == large)
            #expect(point.y == large)
        }

        @Test("Very small coordinates")
        func verySmallCoordinates() {
            let small = CGFloat.leastNonzeroMagnitude
            let point = CGPoint(x: small, y: small)
            #expect(point.x == small)
            #expect(point.y == small)
        }

        @Test("Mixed positive and negative")
        func mixedCoordinates() {
            let point = CGPoint(x: 10.0, y: -20.0)
            #expect(point.x.native == 10.0)
            #expect(point.y.native == -20.0)
        }
    }
}
