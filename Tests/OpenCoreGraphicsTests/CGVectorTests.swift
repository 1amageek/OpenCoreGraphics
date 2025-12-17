//
//  CGVectorTests.swift
//  OpenCoreGraphics
//
//  Tests for CGVector type
//

import Testing
@testable import OpenCoreGraphics

// Type alias to avoid ambiguity with CoreFoundation types on macOS
private typealias CGVector = OpenCoreGraphics.CGVector

@Suite("CGVector Tests")
struct CGVectorTests {

    // MARK: - Initialization Tests

    @Suite("Initialization")
    struct InitializationTests {

        @Test("Default initializer creates zero vector")
        func defaultInit() {
            let vector = CGVector()
            #expect(vector.dx == 0.0)
            #expect(vector.dy == 0.0)
        }

        @Test("Init with CGFloat components")
        func initWithCGFloat() {
            let vector = CGVector(dx: CGFloat(10.0), dy: CGFloat(20.0))
            #expect(vector.dx == 10.0)
            #expect(vector.dy == 20.0)
        }

        @Test("Init with Double components")
        func initWithDouble() {
            let vector = CGVector(dx: 10.5, dy: 20.5)
            #expect(vector.dx == 10.5)
            #expect(vector.dy == 20.5)
        }

        @Test("Init with Int components")
        func initWithInt() {
            let vector = CGVector(dx: 10, dy: 20)
            #expect(vector.dx == 10.0)
            #expect(vector.dy == 20.0)
        }

        @Test("Init with negative components")
        func initWithNegative() {
            let vector = CGVector(dx: -5.0, dy: -10.0)
            #expect(vector.dx == -5.0)
            #expect(vector.dy == -10.0)
        }
    }

    // MARK: - Static Properties Tests

    @Suite("Static Properties")
    struct StaticPropertiesTests {

        @Test("Zero vector")
        func zeroVector() {
            let zero = CGVector.zero
            #expect(zero.dx == 0.0)
            #expect(zero.dy == 0.0)
        }
    }

    // MARK: - Property Mutation Tests

    @Suite("Property Mutation")
    struct PropertyMutationTests {

        @Test("Mutate dx component")
        func mutateDx() {
            var vector = CGVector(dx: 10.0, dy: 20.0)
            vector.dx = CGFloat(50.0)
            #expect(vector.dx == 50.0)
            #expect(vector.dy == 20.0)
        }

        @Test("Mutate dy component")
        func mutateDy() {
            var vector = CGVector(dx: 10.0, dy: 20.0)
            vector.dy = CGFloat(50.0)
            #expect(vector.dx == 10.0)
            #expect(vector.dy == 50.0)
        }
    }

    // MARK: - Equatable Tests

    @Suite("Equatable Conformance")
    struct EquatableTests {

        @Test("Equal vectors")
        func equalVectors() {
            let v1 = CGVector(dx: 10.0, dy: 20.0)
            let v2 = CGVector(dx: 10.0, dy: 20.0)
            #expect(v1 == v2)
        }

        @Test("Unequal vectors different dx")
        func unequalVectorsDifferentDx() {
            let v1 = CGVector(dx: 10.0, dy: 20.0)
            let v2 = CGVector(dx: 15.0, dy: 20.0)
            #expect(v1 != v2)
        }

        @Test("Unequal vectors different dy")
        func unequalVectorsDifferentDy() {
            let v1 = CGVector(dx: 10.0, dy: 20.0)
            let v2 = CGVector(dx: 10.0, dy: 25.0)
            #expect(v1 != v2)
        }

        @Test("Zero vector equality")
        func zeroVectorEquality() {
            let zero1 = CGVector()
            let zero2 = CGVector.zero
            #expect(zero1 == zero2)
        }
    }

    // MARK: - Hashable Tests

    @Suite("Hashable Conformance")
    struct HashableTests {

        @Test("Equal vectors have equal hashes")
        func equalVectorsEqualHashes() {
            let v1 = CGVector(dx: 10.0, dy: 20.0)
            let v2 = CGVector(dx: 10.0, dy: 20.0)
            #expect(v1.hashValue == v2.hashValue)
        }

        @Test("Can be used in Set")
        func setUsage() {
            var set = Set<CGVector>()
            set.insert(CGVector(dx: 1.0, dy: 2.0))
            set.insert(CGVector(dx: 3.0, dy: 4.0))
            set.insert(CGVector(dx: 1.0, dy: 2.0))
            #expect(set.count == 2)
        }

        @Test("Can be used as Dictionary key")
        func dictionaryUsage() {
            var dict: [CGVector: String] = [:]
            dict[CGVector(dx: 1.0, dy: 2.0)] = "vector1"
            dict[CGVector(dx: 3.0, dy: 4.0)] = "vector2"
            #expect(dict[CGVector(dx: 1.0, dy: 2.0)] == "vector1")
        }
    }

    // MARK: - Codable Tests

    @Suite("Codable Conformance")
    struct CodableTests {

        @Test("Encode and decode")
        func encodeAndDecode() throws {
            let original = CGVector(dx: 10.5, dy: 20.5)
            let encoder = JSONEncoder()
            let data = try encoder.encode(original)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(CGVector.self, from: data)
            #expect(original == decoded)
        }

        @Test("Encode and decode zero vector")
        func encodeAndDecodeZero() throws {
            let original = CGVector.zero
            let encoder = JSONEncoder()
            let data = try encoder.encode(original)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(CGVector.self, from: data)
            #expect(original == decoded)
        }

        @Test("Encode and decode negative components")
        func encodeAndDecodeNegative() throws {
            let original = CGVector(dx: -100.5, dy: -200.5)
            let encoder = JSONEncoder()
            let data = try encoder.encode(original)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(CGVector.self, from: data)
            #expect(original == decoded)
        }

        @Test("JSON structure contains dx and dy keys")
        func jsonStructure() throws {
            let vector = CGVector(dx: 10.0, dy: 20.0)
            let encoder = JSONEncoder()
            let data = try encoder.encode(vector)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            #expect(json?["dx"] != nil)
            #expect(json?["dy"] != nil)
        }
    }

    // MARK: - Debug Description Tests

    @Suite("Debug Description")
    struct DebugDescriptionTests {

        @Test("Debug description format")
        func debugDescriptionFormat() {
            let vector = CGVector(dx: 10.0, dy: 20.0)
            #expect(vector.debugDescription.contains("10"))
            #expect(vector.debugDescription.contains("20"))
        }

        @Test("Debug description for zero vector")
        func debugDescriptionZero() {
            let vector = CGVector.zero
            #expect(vector.debugDescription.contains("0"))
        }
    }

    // MARK: - Edge Cases

    @Suite("Edge Cases")
    struct EdgeCaseTests {

        @Test("Very large components")
        func veryLargeComponents() {
            let large = CGFloat.greatestFiniteMagnitude / 2
            let vector = CGVector(dx: large, dy: large)
            #expect(vector.dx == large)
            #expect(vector.dy == large)
        }

        @Test("Very small components")
        func verySmallComponents() {
            let small = CGFloat.leastNonzeroMagnitude
            let vector = CGVector(dx: small, dy: small)
            #expect(vector.dx == small)
            #expect(vector.dy == small)
        }

        @Test("Mixed positive and negative")
        func mixedComponents() {
            let vector = CGVector(dx: 10.0, dy: -20.0)
            #expect(vector.dx == 10.0)
            #expect(vector.dy == -20.0)
        }

        @Test("Unit vectors")
        func unitVectors() {
            let unitX = CGVector(dx: 1.0, dy: 0.0)
            let unitY = CGVector(dx: 0.0, dy: 1.0)
            #expect(unitX.dx == 1.0)
            #expect(unitX.dy == 0.0)
            #expect(unitY.dx == 0.0)
            #expect(unitY.dy == 1.0)
        }
    }
}
