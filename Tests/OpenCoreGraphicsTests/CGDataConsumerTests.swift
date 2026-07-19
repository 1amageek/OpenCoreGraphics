//
//  CGDataConsumerTests.swift
//  OpenCoreGraphics
//
//  Tests for CGDataConsumer
//

import Foundation
import Testing
@testable import OpenCoreGraphics

// Type aliases to avoid ambiguity with CoreFoundation types on macOS
private typealias CGDataConsumer = OpenCoreGraphics.CGDataConsumer
private typealias CGDataConsumerCallbacks = OpenCoreGraphics.CGDataConsumerCallbacks

@Suite("CGDataConsumer Tests")
struct CGDataConsumerTests {

    // MARK: - Initialization Tests

    @Suite("Initialization")
    struct InitializationTests {

        @Test("Init with Data")
        func initWithMutableData() {
            let data = Data()
            let consumer = CGDataConsumer(data: data)

            #expect(consumer != nil)
        }

        @Test("Init with callback without putBytes returns nil")
        func initCallbackWithoutPutBytes() {
            var callbacks = CGDataConsumerCallbacks(
                putBytes: nil,
                releaseConsumer: nil
            )

            let consumer = withUnsafePointer(to: &callbacks) { ptr in
                CGDataConsumer(info: nil, cbks: ptr)
            }

            #expect(consumer == nil)
        }

        @Test("Init with callback with putBytes")
        func initCallbackWithPutBytes() {
            var callbacks = CGDataConsumerCallbacks(
                putBytes: { _, _, count in return count },
                releaseConsumer: nil
            )

            let consumer = withUnsafePointer(to: &callbacks) { ptr in
                CGDataConsumer(info: nil, cbks: ptr)
            }

            #expect(consumer != nil)
        }
    }

    // MARK: - Write Tests

    @Suite("Writing Data")
    struct WriteTests {

        @Test("Write bytes to data consumer")
        func writeBytesToMutableData() {
            let data = Data()
            guard let consumer = CGDataConsumer(data: data) else {
                #expect(Bool(false), "Failed to create consumer")
                return
            }

            let bytes: [UInt8] = [1, 2, 3, 4, 5]
            let written = bytes.withUnsafeBufferPointer { buffer in
                consumer.putBytes(buffer.baseAddress, count: buffer.count)
            }

            #expect(written == 5)
        }

        @Test("Write empty bytes")
        func writeEmptyBytes() {
            let data = Data()
            guard let consumer = CGDataConsumer(data: data) else {
                #expect(Bool(false), "Failed to create consumer")
                return
            }

            let nilPtr: UnsafeRawPointer? = nil
            let written = consumer.putBytes(nilPtr, count: 0)

            #expect(written == 0)
        }

        @Test("Write multiple times")
        func writeMultipleTimes() {
            let data = Data()
            guard let consumer = CGDataConsumer(data: data) else {
                #expect(Bool(false), "Failed to create consumer")
                return
            }

            let bytes1: [UInt8] = [1, 2, 3]
            let bytes2: [UInt8] = [4, 5]

            bytes1.withUnsafeBufferPointer { buffer in
                _ = consumer.putBytes(buffer.baseAddress, count: buffer.count)
            }

            bytes2.withUnsafeBufferPointer { buffer in
                _ = consumer.putBytes(buffer.baseAddress, count: buffer.count)
            }

            // Consumer accumulates data internally
        }

        @Test("Write with nil buffer returns 0")
        func writeNilBuffer() {
            let data = Data()
            guard let consumer = CGDataConsumer(data: data) else {
                #expect(Bool(false), "Failed to create consumer")
                return
            }

            let nilPtr: UnsafeRawPointer? = nil
            let written = consumer.putBytes(nilPtr, count: 10)

            #expect(written == 0)
        }
    }

    // MARK: - Data Property Tests

    @Suite("Data Property")
    struct DataPropertyTests {

        @Test("Retrieve written data via data property")
        func retrieveWrittenData() {
            guard let consumer = CGDataConsumer(data: Data()) else {
                #expect(Bool(false), "Failed to create consumer")
                return
            }

            let bytes: [UInt8] = [0x01, 0x02, 0x03, 0x04]
            bytes.withUnsafeBufferPointer { buffer in
                _ = consumer.putBytes(buffer.baseAddress, count: buffer.count)
            }

            #expect(consumer.data == Data([0x01, 0x02, 0x03, 0x04]))
        }

        @Test("Data property returns empty data when nothing written")
        func dataPropertyEmptyWhenNothingWritten() {
            guard let consumer = CGDataConsumer(data: Data()) else {
                #expect(Bool(false), "Failed to create consumer")
                return
            }

            #expect(consumer.data == Data())
        }

        @Test("Data property accumulates multiple writes")
        func dataPropertyAccumulatesMultipleWrites() {
            guard let consumer = CGDataConsumer(data: Data()) else {
                #expect(Bool(false), "Failed to create consumer")
                return
            }

            let bytes1: [UInt8] = [0x01, 0x02]
            let bytes2: [UInt8] = [0x03, 0x04, 0x05]

            bytes1.withUnsafeBufferPointer { buffer in
                _ = consumer.putBytes(buffer.baseAddress, count: buffer.count)
            }

            bytes2.withUnsafeBufferPointer { buffer in
                _ = consumer.putBytes(buffer.baseAddress, count: buffer.count)
            }

            #expect(consumer.data == Data([0x01, 0x02, 0x03, 0x04, 0x05]))
        }

        @Test("Data property returns nil for callback consumer")
        func dataPropertyNilForCallbackConsumer() {
            var callbacks = CGDataConsumerCallbacks(
                putBytes: { _, _, count in return count },
                releaseConsumer: nil
            )

            guard let consumer = withUnsafePointer(to: &callbacks, { ptr in
                CGDataConsumer(info: nil, cbks: ptr)
            }) else {
                #expect(Bool(false), "Failed to create consumer")
                return
            }

            #expect(consumer.data == nil)
        }

        @Test("Data property preserves initial data")
        func dataPropertyPreservesInitialData() {
            let initialData = Data([0xAA, 0xBB])
            guard let consumer = CGDataConsumer(data: initialData) else {
                #expect(Bool(false), "Failed to create consumer")
                return
            }

            let bytes: [UInt8] = [0xCC, 0xDD]
            bytes.withUnsafeBufferPointer { buffer in
                _ = consumer.putBytes(buffer.baseAddress, count: buffer.count)
            }

            #expect(consumer.data == Data([0xAA, 0xBB, 0xCC, 0xDD]))
        }
    }

    // MARK: - Equatable Tests

    @Suite("Equatable Conformance")
    struct EquatableTests {

        @Test("Same instance is equal")
        func sameInstanceEqual() {
            let data = Data()
            let consumer = CGDataConsumer(data: data)

            #expect(consumer == consumer)
        }

        @Test("Different instances are not equal")
        func differentInstancesNotEqual() {
            let data1 = Data()
            let data2 = Data()
            let consumer1 = CGDataConsumer(data: data1)
            let consumer2 = CGDataConsumer(data: data2)

            #expect(consumer1 != consumer2)
        }
    }

    // MARK: - Hashable Tests

    @Suite("Hashable Conformance")
    struct HashableTests {

        @Test("Can be used in Set")
        func setUsage() {
            var set = Set<CGDataConsumer>()
            let data1 = Data()
            let data2 = Data()

            if let consumer1 = CGDataConsumer(data: data1),
               let consumer2 = CGDataConsumer(data: data2) {
                set.insert(consumer1)
                set.insert(consumer2)
                set.insert(consumer1)  // Duplicate

                #expect(set.count == 2)
            }
        }
    }

    // MARK: - Callbacks Structure Tests

    @Suite("Callbacks Structure")
    struct CallbacksStructureTests {

        @Test("Create callbacks structure")
        func createCallbacksStructure() {
            let callbacks = CGDataConsumerCallbacks(
                putBytes: { _, _, count in return count },
                releaseConsumer: { _ in }
            )

            #expect(callbacks.putBytes != nil)
            #expect(callbacks.releaseConsumer != nil)
        }

        @Test("Callbacks with nil functions")
        func callbacksWithNilFunctions() {
            let callbacks = CGDataConsumerCallbacks(
                putBytes: nil,
                releaseConsumer: nil
            )

            #expect(callbacks.putBytes == nil)
            #expect(callbacks.releaseConsumer == nil)
        }
    }

    // MARK: - Type ID Tests

    @Suite("Type ID")
    struct TypeIDTests {

        @Test("Get type ID returns consistent value")
        func getTypeIDConsistent() {
            let typeID1 = CGDataConsumer.typeID
            let typeID2 = CGDataConsumer.typeID

            #expect(typeID1 == typeID2)
        }
    }

    // MARK: - Sendable Tests

    @Suite("Sendable Conformance")
    struct SendableTests {

        @Test("CGDataConsumer is Sendable")
        func dataConsumerIsSendable() {
            let data = Data()
            let consumer = CGDataConsumer(data: data)

            // Verify CGDataConsumer can be used as Sendable
            let sendableConsumer: (any Sendable)? = consumer
            #expect(sendableConsumer != nil)
        }

        @Test("CGDataConsumerCallbacks is Sendable")
        func callbacksIsSendable() {
            let callbacks = CGDataConsumerCallbacks(
                putBytes: { _, _, count in return count },
                releaseConsumer: nil
            )

            // Verify CGDataConsumerCallbacks can be used as Sendable
            let sendableCallbacks: any Sendable = callbacks
            #expect(type(of: sendableCallbacks) == CGDataConsumerCallbacks.self)
        }
    }

    // MARK: - Finalize Tests

    @Suite("Finalize")
    struct FinalizeTests {

        @Test("finalize on data-backed consumer does not throw and preserves data")
        func finalize_dataBacked_isNoOpAndPreservesData() throws {
            guard let consumer = CGDataConsumer(data: Data()) else {
                #expect(Bool(false), "Failed to create consumer")
                return
            }

            let bytes: [UInt8] = [0xDE, 0xAD, 0xBE, 0xEF]
            bytes.withUnsafeBufferPointer { buffer in
                _ = consumer.putBytes(buffer.baseAddress, count: buffer.count)
            }

            try consumer.finalize()

            #expect(consumer.data == Data([0xDE, 0xAD, 0xBE, 0xEF]))
        }

        @Test("finalize twice on data-backed consumer is idempotent")
        func finalize_calledTwice_idempotent() throws {
            // For data-backed consumers `finalize()` is a documented no-op.
            // Call it twice to confirm the second call does not throw and
            // does not mutate the accumulated data.
            guard let consumer = CGDataConsumer(data: Data()) else {
                #expect(Bool(false), "Failed to create consumer")
                return
            }

            let bytes: [UInt8] = [1, 2, 3]
            bytes.withUnsafeBufferPointer { buffer in
                _ = consumer.putBytes(buffer.baseAddress, count: buffer.count)
            }

            try consumer.finalize()
            try consumer.finalize()

            #expect(consumer.data == Data([1, 2, 3]))
        }

        @Test("finalize on callback-backed consumer does not throw")
        func finalize_callbackBacked_noThrow() throws {
            // For callback consumers finalize() is a no-op (the callback
            // sink receives bytes synchronously in putBytes).
            var callbacks = CGDataConsumerCallbacks(
                putBytes: { _, _, count in return count },
                releaseConsumer: nil
            )

            guard let consumer = withUnsafePointer(to: &callbacks, { ptr in
                CGDataConsumer(info: nil, cbks: ptr)
            }) else {
                #expect(Bool(false), "Failed to create consumer")
                return
            }

            try consumer.finalize()
        }

        @Test("URL-backed consumer finalize writes accumulated data to disk")
        func finalize_urlBacked_writesToDisk() throws {
            // Pick a unique temp path so concurrent runs don't collide.
            let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            let url = tmpDir.appendingPathComponent("cgdataconsumer-finalize-\(UUID().uuidString).bin")
            defer {
                do {
                    if FileManager.default.fileExists(atPath: url.path) {
                        try FileManager.default.removeItem(at: url)
                    }
                } catch {
                    Issue.record("Failed to remove temporary file: \(error)")
                }
            }

            guard let consumer = CGDataConsumer(url: url) else {
                #expect(Bool(false), "Failed to create URL-backed consumer")
                return
            }

            let bytes: [UInt8] = [0xCA, 0xFE]
            bytes.withUnsafeBufferPointer { buffer in
                _ = consumer.putBytes(buffer.baseAddress, count: buffer.count)
            }

            try consumer.finalize()

            #expect(FileManager.default.fileExists(atPath: url.path))
            let written = try Data(contentsOf: url)
            #expect(written == Data([0xCA, 0xFE]))
        }

        @Test("URL-backed consumer flushes to disk on deinit when finalize not called")
        func urlBacked_deinitFlushes_bestEffort() throws {
            // deinit performs a best-effort write when the caller never called
            // finalize(). Confirm the file exists after the consumer scope ends.
            let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            let url = tmpDir.appendingPathComponent("cgdataconsumer-deinit-\(UUID().uuidString).bin")
            defer {
                do {
                    if FileManager.default.fileExists(atPath: url.path) {
                        try FileManager.default.removeItem(at: url)
                    }
                } catch {
                    Issue.record("Failed to remove temporary file: \(error)")
                }
            }

            do {
                guard let consumer = CGDataConsumer(url: url) else {
                    #expect(Bool(false), "Failed to create URL-backed consumer")
                    return
                }
                let bytes: [UInt8] = [0xAB, 0xCD]
                bytes.withUnsafeBufferPointer { buffer in
                    _ = consumer.putBytes(buffer.baseAddress, count: buffer.count)
                }
                // Intentionally do not call finalize; let deinit flush.
            }

            #expect(FileManager.default.fileExists(atPath: url.path))
            let written = try Data(contentsOf: url)
            #expect(written == Data([0xAB, 0xCD]))
        }

        @Test("URL-backed consumer does not re-flush in deinit after finalize")
        func urlBacked_finalizeThenDeinit_noDoubleWrite() throws {
            // After finalize() sets the flag, deinit's best-effort write is
            // skipped. Verify by deleting the file after finalize — deinit
            // must not resurrect it.
            let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            let url = tmpDir.appendingPathComponent("cgdataconsumer-noredo-\(UUID().uuidString).bin")
            defer {
                do {
                    if FileManager.default.fileExists(atPath: url.path) {
                        try FileManager.default.removeItem(at: url)
                    }
                } catch {
                    Issue.record("Failed to remove temporary file: \(error)")
                }
            }

            do {
                guard let consumer = CGDataConsumer(url: url) else {
                    #expect(Bool(false), "Failed to create URL-backed consumer")
                    return
                }
                let bytes: [UInt8] = [0x01]
                bytes.withUnsafeBufferPointer { buffer in
                    _ = consumer.putBytes(buffer.baseAddress, count: buffer.count)
                }
                try consumer.finalize()
                #expect(FileManager.default.fileExists(atPath: url.path))

                try FileManager.default.removeItem(at: url)
                #expect(!FileManager.default.fileExists(atPath: url.path))
            }

            // If deinit incorrectly re-wrote the file, it would exist here.
            #expect(!FileManager.default.fileExists(atPath: url.path))
        }
    }

    // MARK: - Custom Callback Tests

    @Suite("Custom Callback Behavior")
    struct CustomCallbackTests {

        @Test("Custom callback receives correct data")
        func customCallbackReceivesData() {
            var receivedData = Data()

            var callbacks = CGDataConsumerCallbacks(
                putBytes: { info, buffer, count in
                    guard let buffer = buffer else { return 0 }
                    let bufferPointer = UnsafeRawBufferPointer(start: buffer, count: count)
                    receivedData.append(contentsOf: bufferPointer)
                    return count
                },
                releaseConsumer: nil
            )

            guard let consumer = withUnsafePointer(to: &callbacks, { ptr in
                CGDataConsumer(info: nil, cbks: ptr)
            }) else {
                #expect(Bool(false), "Failed to create consumer")
                return
            }

            let testBytes: [UInt8] = [0x48, 0x65, 0x6C, 0x6C, 0x6F] // "Hello"
            let written = testBytes.withUnsafeBufferPointer { buffer in
                consumer.putBytes(buffer.baseAddress, count: buffer.count)
            }

            #expect(written == 5)
            #expect(receivedData.count == 5)
            #expect(Array(receivedData) == testBytes)
        }

        @Test("Custom callback can return partial write")
        func customCallbackPartialWrite() {
            var callbacks = CGDataConsumerCallbacks(
                putBytes: { _, _, count in
                    // Only write half the bytes
                    return count / 2
                },
                releaseConsumer: nil
            )

            guard let consumer = withUnsafePointer(to: &callbacks, { ptr in
                CGDataConsumer(info: nil, cbks: ptr)
            }) else {
                #expect(Bool(false), "Failed to create consumer")
                return
            }

            let testBytes: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
            let written = testBytes.withUnsafeBufferPointer { buffer in
                consumer.putBytes(buffer.baseAddress, count: buffer.count)
            }

            #expect(written == 5) // Half of 10
        }
    }
}
