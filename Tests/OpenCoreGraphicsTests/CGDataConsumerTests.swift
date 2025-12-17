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

            var bytes: [UInt8] = [1, 2, 3, 4, 5]
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

            var bytes1: [UInt8] = [1, 2, 3]
            var bytes2: [UInt8] = [4, 5]

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

        @Test("Get type ID")
        func getTypeID() {
            // Just verify it doesn't crash
            let _ = CGDataConsumer.typeID
        }
    }
}
