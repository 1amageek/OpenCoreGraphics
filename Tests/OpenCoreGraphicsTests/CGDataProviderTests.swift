//
//  CGDataProviderTests.swift
//  OpenCoreGraphics
//
//  Tests for CGDataProvider
//

import Testing
import Foundation
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

        @Test("Init with C-string filename for non-existent file returns nil")
        func initWithNonExistentCStringFilename() {
            // The `UnsafePointer<CChar>` overload must likewise fail-soft
            // (returning nil) rather than crash when the path is missing.
            let path = "/nonexistent/path/to/cstring.dat"
            let provider = path.withCString { cString in
                CGDataProvider(filename: cString)
            }

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

        @Test("Init with direct callbacks without accessors returns nil")
        func initWithDirectCallbacksWithoutAccessors() {
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

            #expect(provider == nil)
        }

        @Test("Init with direct callbacks with getBytesAtPosition")
        func initWithDirectCallbacksWithGetBytesAtPosition() {
            final class DirectState {
                let bytes: [UInt8]

                init(bytes: [UInt8]) {
                    self.bytes = bytes
                }
            }

            let state = DirectState(bytes: [1, 2, 3, 4])
            var callbacks = CGDataProviderDirectCallbacks(
                version: 0,
                getBytePointer: nil,
                releaseBytePointer: nil,
                getBytesAtPosition: { info, buffer, position, count in
                    guard let info, let buffer, position >= 0 else { return 0 }
                    let state = Unmanaged<DirectState>.fromOpaque(info).takeUnretainedValue()
                    let start = Int(position)
                    guard start < state.bytes.count else { return 0 }
                    let byteCount = min(count, state.bytes.count - start)
                    state.bytes.withUnsafeBufferPointer { source in
                        guard let baseAddress = source.baseAddress else { return }
                        buffer.copyMemory(
                            from: UnsafeRawPointer(baseAddress.advanced(by: start)),
                            byteCount: byteCount
                        )
                    }
                    return byteCount
                },
                releaseInfo: nil
            )

            let info = Unmanaged.passUnretained(state).toOpaque()
            let provider = withUnsafePointer(to: &callbacks) { ptr in
                CGDataProvider(directInfo: info, size: Int64(state.bytes.count), callbacks: ptr)
            }

            #expect(provider != nil)
            #expect(provider?.size == 4)
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

        @Test("Data property materializes direct callbacks")
        func dataPropertyDirectCallbacks() {
            final class DirectState {
                let bytes: [UInt8]

                init(bytes: [UInt8]) {
                    self.bytes = bytes
                }
            }

            let state = DirectState(bytes: [5, 6, 7, 8, 9])
            var callbacks = CGDataProviderDirectCallbacks(
                version: 0,
                getBytePointer: nil,
                releaseBytePointer: nil,
                getBytesAtPosition: { info, buffer, position, count in
                    guard let info, let buffer, position >= 0 else { return 0 }
                    let state = Unmanaged<DirectState>.fromOpaque(info).takeUnretainedValue()
                    let start = Int(position)
                    guard start < state.bytes.count else { return 0 }
                    let byteCount = min(count, state.bytes.count - start)
                    state.bytes.withUnsafeBufferPointer { source in
                        guard let baseAddress = source.baseAddress else { return }
                        buffer.copyMemory(
                            from: UnsafeRawPointer(baseAddress.advanced(by: start)),
                            byteCount: byteCount
                        )
                    }
                    return byteCount
                },
                releaseInfo: nil
            )

            let info = Unmanaged.passUnretained(state).toOpaque()
            let provider = withUnsafePointer(to: &callbacks) { ptr in
                CGDataProvider(directInfo: info, size: Int64(state.bytes.count), callbacks: ptr)
            }

            #expect(provider?.data == Data(state.bytes))
        }

        @Test("Data property materializes sequential callbacks")
        func dataPropertySequentialCallbacks() {
            final class SequentialState {
                let bytes: [UInt8]
                var offset: Int = 0

                init(bytes: [UInt8]) {
                    self.bytes = bytes
                }
            }

            let state = SequentialState(bytes: [10, 11, 12, 13, 14, 15])
            var callbacks = CGDataProviderSequentialCallbacks(
                version: 0,
                getBytes: { info, buffer, count in
                    guard let info, let buffer else { return 0 }
                    let state = Unmanaged<SequentialState>.fromOpaque(info).takeUnretainedValue()
                    guard state.offset < state.bytes.count else { return 0 }
                    let byteCount = min(count, state.bytes.count - state.offset)
                    state.bytes.withUnsafeBufferPointer { source in
                        guard let baseAddress = source.baseAddress else { return }
                        buffer.copyMemory(
                            from: UnsafeRawPointer(baseAddress.advanced(by: state.offset)),
                            byteCount: byteCount
                        )
                    }
                    state.offset += byteCount
                    return byteCount
                },
                skipForward: nil,
                rewind: { info in
                    guard let info else { return }
                    let state = Unmanaged<SequentialState>.fromOpaque(info).takeUnretainedValue()
                    state.offset = 0
                },
                releaseInfo: nil
            )

            let info = Unmanaged.passUnretained(state).toOpaque()
            let provider = withUnsafePointer(to: &callbacks) { ptr in
                CGDataProvider(sequentialInfo: info, callbacks: ptr)
            }

            #expect(provider?.data == Data(state.bytes))
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
