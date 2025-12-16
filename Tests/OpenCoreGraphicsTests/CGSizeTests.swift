//
//  CGSizeTests.swift
//  OpenCoreGraphics
//
//  Tests for CGSize type
//

import Foundation
import Testing
@testable import OpenCoreGraphics

// Type aliases to avoid ambiguity with CoreFoundation types on macOS
private typealias CGFloat = OpenCoreGraphics.CGFloat
private typealias CGSize = OpenCoreGraphics.CGSize
private typealias CGAffineTransform = OpenCoreGraphics.CGAffineTransform

@Suite("CGSize Tests")
struct CGSizeTests {

    // MARK: - Initialization Tests

    @Suite("Initialization")
    struct InitializationTests {

        @Test("Default initializer creates zero size")
        func defaultInit() {
            let size = CGSize()
            #expect(size.width.native == 0.0)
            #expect(size.height.native == 0.0)
        }

        @Test("Init with CGFloat dimensions")
        func initWithCGFloat() {
            let size = CGSize(width: CGFloat(100.0), height: CGFloat(200.0))
            #expect(size.width.native == 100.0)
            #expect(size.height.native == 200.0)
        }

        @Test("Init with Double dimensions")
        func initWithDouble() {
            let size = CGSize(width: 100.5, height: 200.5)
            #expect(size.width.native == 100.5)
            #expect(size.height.native == 200.5)
        }

        @Test("Init with Int dimensions")
        func initWithInt() {
            let size = CGSize(width: 100, height: 200)
            #expect(size.width.native == 100.0)
            #expect(size.height.native == 200.0)
        }

        @Test("Init with negative dimensions")
        func initWithNegative() {
            let size = CGSize(width: -50.0, height: -100.0)
            #expect(size.width.native == -50.0)
            #expect(size.height.native == -100.0)
        }
    }

    // MARK: - Static Properties Tests

    @Suite("Static Properties")
    struct StaticPropertiesTests {

        @Test("Zero size")
        func zeroSize() {
            let zero = CGSize.zero
            #expect(zero.width.native == 0.0)
            #expect(zero.height.native == 0.0)
        }
    }

    // MARK: - Property Mutation Tests

    @Suite("Property Mutation")
    struct PropertyMutationTests {

        @Test("Mutate width")
        func mutateWidth() {
            var size = CGSize(width: 100.0, height: 200.0)
            size.width = CGFloat(150.0)
            #expect(size.width.native == 150.0)
            #expect(size.height.native == 200.0)
        }

        @Test("Mutate height")
        func mutateHeight() {
            var size = CGSize(width: 100.0, height: 200.0)
            size.height = CGFloat(250.0)
            #expect(size.width.native == 100.0)
            #expect(size.height.native == 250.0)
        }
    }

    // MARK: - Equatable Tests

    @Suite("Equatable Conformance")
    struct EquatableTests {

        @Test("Equal sizes")
        func equalSizes() {
            let s1 = CGSize(width: 100.0, height: 200.0)
            let s2 = CGSize(width: 100.0, height: 200.0)
            #expect(s1 == s2)
        }

        @Test("Unequal sizes different width")
        func unequalSizesDifferentWidth() {
            let s1 = CGSize(width: 100.0, height: 200.0)
            let s2 = CGSize(width: 150.0, height: 200.0)
            #expect(s1 != s2)
        }

        @Test("Unequal sizes different height")
        func unequalSizesDifferentHeight() {
            let s1 = CGSize(width: 100.0, height: 200.0)
            let s2 = CGSize(width: 100.0, height: 250.0)
            #expect(s1 != s2)
        }

        @Test("equalTo method")
        func equalToMethod() {
            let s1 = CGSize(width: 100.0, height: 200.0)
            let s2 = CGSize(width: 100.0, height: 200.0)
            let s3 = CGSize(width: 150.0, height: 200.0)
            #expect(s1.equalTo(s2))
            #expect(!s1.equalTo(s3))
        }

        @Test("Zero size equality")
        func zeroSizeEquality() {
            let zero1 = CGSize()
            let zero2 = CGSize.zero
            #expect(zero1 == zero2)
        }
    }

    // MARK: - Hashable Tests

    @Suite("Hashable Conformance")
    struct HashableTests {

        @Test("Equal sizes have equal hashes")
        func equalSizesEqualHashes() {
            let s1 = CGSize(width: 100.0, height: 200.0)
            let s2 = CGSize(width: 100.0, height: 200.0)
            #expect(s1.hashValue == s2.hashValue)
        }

        @Test("Can be used in Set")
        func setUsage() {
            var set = Set<CGSize>()
            set.insert(CGSize(width: 100.0, height: 200.0))
            set.insert(CGSize(width: 300.0, height: 400.0))
            set.insert(CGSize(width: 100.0, height: 200.0))
            #expect(set.count == 2)
        }

        @Test("Can be used as Dictionary key")
        func dictionaryUsage() {
            var dict: [CGSize: String] = [:]
            dict[CGSize(width: 100.0, height: 200.0)] = "size1"
            dict[CGSize(width: 300.0, height: 400.0)] = "size2"
            #expect(dict[CGSize(width: 100.0, height: 200.0)] == "size1")
        }
    }

    // MARK: - Affine Transform Tests

    @Suite("Affine Transform")
    struct AffineTransformTests {

        @Test("Apply identity transform")
        func applyIdentity() {
            let size = CGSize(width: 100.0, height: 200.0)
            let transformed = size.applying(CGAffineTransform.identity)
            #expect(transformed == size)
        }

        @Test("Apply scale transform")
        func applyScale() {
            let size = CGSize(width: 100.0, height: 200.0)
            let transform = CGAffineTransform(scaleX: 2.0, y: 0.5)
            let transformed = size.applying(transform)
            #expect(transformed.width.native == 200.0)
            #expect(transformed.height.native == 100.0)
        }

        @Test("Apply rotation transform 90 degrees")
        func applyRotation90() {
            let size = CGSize(width: 100.0, height: 0.0)
            let transform = CGAffineTransform(rotationAngle: CGFloat.pi / 2)
            let transformed = size.applying(transform)
            #expect(abs(transformed.width.native - 0.0) < 0.0001)
            #expect(abs(transformed.height.native - 100.0) < 0.0001)
        }

        @Test("Apply uniform scale")
        func applyUniformScale() {
            let size = CGSize(width: 50.0, height: 100.0)
            let transform = CGAffineTransform(scaleX: 3.0, y: 3.0)
            let transformed = size.applying(transform)
            #expect(transformed.width.native == 150.0)
            #expect(transformed.height.native == 300.0)
        }

        @Test("Apply transform to zero size")
        func applyToZero() {
            let size = CGSize.zero
            let transform = CGAffineTransform(scaleX: 2.0, y: 2.0)
            let transformed = size.applying(transform)
            #expect(transformed == CGSize.zero)
        }
    }

    // MARK: - Codable Tests

    @Suite("Codable Conformance")
    struct CodableTests {

        @Test("Encode and decode")
        func encodeAndDecode() throws {
            let original = CGSize(width: 100.5, height: 200.5)
            let encoder = JSONEncoder()
            let data = try encoder.encode(original)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(CGSize.self, from: data)
            #expect(original == decoded)
        }

        @Test("Encode and decode zero size")
        func encodeAndDecodeZero() throws {
            let original = CGSize.zero
            let encoder = JSONEncoder()
            let data = try encoder.encode(original)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(CGSize.self, from: data)
            #expect(original == decoded)
        }

        @Test("Encode and decode negative dimensions")
        func encodeAndDecodeNegative() throws {
            let original = CGSize(width: -100.5, height: -200.5)
            let encoder = JSONEncoder()
            let data = try encoder.encode(original)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(CGSize.self, from: data)
            #expect(original == decoded)
        }

        @Test("JSON structure contains width and height keys")
        func jsonStructure() throws {
            let size = CGSize(width: 100.0, height: 200.0)
            let encoder = JSONEncoder()
            let data = try encoder.encode(size)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            #expect(json?["width"] != nil)
            #expect(json?["height"] != nil)
        }
    }

    // MARK: - Debug Description Tests

    @Suite("Debug Description")
    struct DebugDescriptionTests {

        @Test("Debug description format")
        func debugDescriptionFormat() {
            let size = CGSize(width: 100.0, height: 200.0)
            #expect(size.debugDescription.contains("100"))
            #expect(size.debugDescription.contains("200"))
        }

        @Test("Debug description for zero size")
        func debugDescriptionZero() {
            let size = CGSize.zero
            #expect(size.debugDescription.contains("0"))
        }
    }

    // MARK: - Edge Cases

    @Suite("Edge Cases")
    struct EdgeCaseTests {

        @Test("Very large dimensions")
        func veryLargeDimensions() {
            let large = CGFloat.greatestFiniteMagnitude / 2
            let size = CGSize(width: large, height: large)
            #expect(size.width == large)
            #expect(size.height == large)
        }

        @Test("Very small dimensions")
        func verySmallDimensions() {
            let small = CGFloat.leastNonzeroMagnitude
            let size = CGSize(width: small, height: small)
            #expect(size.width == small)
            #expect(size.height == small)
        }

        @Test("Mixed positive and negative")
        func mixedDimensions() {
            let size = CGSize(width: 100.0, height: -200.0)
            #expect(size.width.native == 100.0)
            #expect(size.height.native == -200.0)
        }

        @Test("Square size")
        func squareSize() {
            let size = CGSize(width: 100.0, height: 100.0)
            #expect(size.width == size.height)
        }
    }
}
