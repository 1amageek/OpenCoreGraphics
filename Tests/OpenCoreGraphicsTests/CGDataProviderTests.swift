//
//  CGDataProviderTests.swift
//  OpenCoreGraphics
//
//  Tests for CGDataProvider
//

import Foundation
import Testing
@testable import OpenCoreGraphics

// Type aliases to avoid ambiguity with CoreFoundation types on macOS
private typealias CGDataProvider = OpenCoreGraphics.CGDataProvider
private typealias CGDataProviderSequentialCallbacks = OpenCoreGraphics.CGDataProviderSequentialCallbacks
private typealias CGDataProviderDirectCallbacks = OpenCoreGraphics.CGDataProviderDirectCallbacks

@Suite("CGDataProvider Tests")
struct CGDataProviderTests {

    // MARK: - Initialization Tests

    @Suite("Initialization")
    struct InitializationTests {

        @Test("Init with Data")
        func initWithData() {
            let testData = Data([0, 1, 2, 3, 4, 5])
            let provider = CGDataProvider(data: testData)

            #expect(provider.data != nil)
            #expect(provider.data?.count == 6)
            #expect(provider.size == 6)
        }

        @Test("Init with empty data")
        func initWithEmptyData() {
            let testData = Data()
            let provider = CGDataProvider(data: testData)

            #expect(provider.data != nil)
            #expect(provider.size == 0)
        }

        @Test("Init with URL for non-existent file returns nil")
        func initWithNonExistentURL() {
            let url = URL(fileURLWithPath: "/nonexistent/path/to/file.dat")
            let provider = CGDataProvider(url: url)

            #expect(provider == nil)
        }

        @Test("Init with filename for non-existent file returns nil")
        func initWithNonExistentFilename() {
            let provider = CGDataProvider(filename: "/nonexistent/path/to/file.dat")

            #expect(provider == nil)
        }

        @Test("Init with raw data pointer")
        func initWithRawPointer() {
            var bytes: [UInt8] = [0, 1, 2, 3, 4]

            let provider = bytes.withUnsafeMutableBufferPointer { buffer in
                CGDataProvider(
                    dataInfo: nil,
                    data: UnsafeRawPointer(buffer.baseAddress!),
                    size: buffer.count,
                    releaseData: nil
                )
            }

            #expect(provider != nil)
            #expect(provider?.size == 5)
        }

        @Test("Init with sequential callbacks without getBytes returns nil")
        func initSequentialWithoutGetBytes() {
            var callbacks = CGDataProviderSequentialCallbacks(
                version: 0,
                getBytes: nil,
                skipForward: nil,
                rewind: nil,
                releaseInfo: nil
            )

            let provider = withUnsafePointer(to: &callbacks) { ptr in
                CGDataProvider(sequentialInfo: nil, callbacks: ptr)
            }

            #expect(provider == nil)
        }

        @Test("Init with sequential callbacks with getBytes")
        func initSequentialWithGetBytes() {
            var callbacks = CGDataProviderSequentialCallbacks(
                version: 0,
                getBytes: { _, _, _ in return 0 },
                skipForward: nil,
                rewind: nil,
                releaseInfo: nil
            )

            let provider = withUnsafePointer(to: &callbacks) { ptr in
                CGDataProvider(sequentialInfo: nil, callbacks: ptr)
            }

            #expect(provider != nil)
        }

        @Test("Init with direct callbacks")
        func initWithDirectCallbacks() {
            var callbacks = CGDataProviderDirectCallbacks(
                version: 0,
                getBytePointer: nil,
                releaseBytePointer: nil,
                getBytesAtPosition: nil,
                releaseInfo: nil
            )

            let provider = withUnsafePointer(to: &callbacks) { ptr in
                CGDataProvider(directInfo: nil, size: 100, callbacks: ptr)
            }

            #expect(provider != nil)
            #expect(provider?.size == 100)
        }
    }

    // MARK: - Properties Tests

    @Suite("Properties")
    struct PropertiesTests {

        @Test("Data property for direct provider")
        func dataPropertyDirect() {
            let testData = Data([10, 20, 30, 40])
            let provider = CGDataProvider(data: testData)

            #expect(provider.data == testData)
        }

        @Test("Size property")
        func sizeProperty() {
            let testData = Data(repeating: 0, count: 100)
            let provider = CGDataProvider(data: testData)

            #expect(provider.size == 100)
        }

        @Test("Info property for direct provider is nil")
        func infoPropertyDirect() {
            let testData = Data([1, 2, 3])
            let provider = CGDataProvider(data: testData)

            #expect(provider.info == nil)
        }

        @Test("Type ID")
        func typeID() {
            // Just check that it doesn't crash
            let _ = CGDataProvider.typeID
        }
    }

    // MARK: - Equatable Tests

    @Suite("Equatable Conformance")
    struct EquatableTests {

        @Test("Same instance is equal")
        func sameInstanceEqual() {
            let testData = Data([1, 2, 3])
            let provider = CGDataProvider(data: testData)

            #expect(provider == provider)
        }

        @Test("Different instances are not equal")
        func differentInstancesNotEqual() {
            let testData = Data([1, 2, 3])
            let provider1 = CGDataProvider(data: testData)
            let provider2 = CGDataProvider(data: testData)

            #expect(provider1 != provider2)
        }
    }

    // MARK: - Hashable Tests

    @Suite("Hashable Conformance")
    struct HashableTests {

        @Test("Can be used in Set")
        func setUsage() {
            var set = Set<CGDataProvider>()
            let provider1 = CGDataProvider(data: Data([1, 2, 3]))
            let provider2 = CGDataProvider(data: Data([4, 5, 6]))

            set.insert(provider1)
            set.insert(provider2)
            set.insert(provider1)  // Duplicate

            #expect(set.count == 2)
        }

        @Test("Can be used as Dictionary key")
        func dictionaryKeyUsage() {
            var dict = [CGDataProvider: String]()
            let provider = CGDataProvider(data: Data([1, 2, 3]))

            dict[provider] = "test"

            #expect(dict[provider] == "test")
        }
    }

    // MARK: - Callbacks Structure Tests

    @Suite("Callbacks Structures")
    struct CallbacksStructuresTests {

        @Test("Sequential callbacks default version")
        func sequentialCallbacksDefaultVersion() {
            let callbacks = CGDataProviderSequentialCallbacks(
                version: 0,
                getBytes: nil,
                skipForward: nil,
                rewind: nil,
                releaseInfo: nil
            )

            #expect(callbacks.version == 0)
        }

        @Test("Direct callbacks structure")
        func directCallbacksStructure() {
            let callbacks = CGDataProviderDirectCallbacks(
                version: 0,
                getBytePointer: nil,
                releaseBytePointer: nil,
                getBytesAtPosition: nil,
                releaseInfo: nil
            )

            #expect(callbacks.version == 0)
            #expect(callbacks.getBytePointer == nil)
        }
    }

    // MARK: - Edge Cases

    @Suite("Edge Cases")
    struct EdgeCaseTests {

        @Test("Large data")
        func largeData() {
            let largeData = Data(repeating: 0xFF, count: 1_000_000)
            let provider = CGDataProvider(data: largeData)

            #expect(provider.size == 1_000_000)
        }

        @Test("Binary data preservation")
        func binaryDataPreservation() {
            let binaryData = Data([0x00, 0xFF, 0x7F, 0x80, 0x01])
            let provider = CGDataProvider(data: binaryData)

            #expect(provider.data == binaryData)
        }
    }
}
