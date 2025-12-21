//
//  CGDataConsumer.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//

#if arch(wasm32)

import Foundation


// MARK: - CGDataConsumerCallbacks

/// Copies data from a Core Graphics-supplied buffer into a data consumer.
///
/// - Parameters:
///   - info: A pointer to private data associated with the consumer.
///   - buffer: A pointer to the buffer containing the data to copy.
///   - count: The number of bytes to copy.
/// - Returns: The number of bytes actually written.
public typealias CGDataConsumerPutBytesCallback = (
    UnsafeMutableRawPointer?,       // info
    UnsafeRawPointer?,              // buffer
    Int                             // count
) -> Int

/// Releases any private data or resources associated with the data consumer.
public typealias CGDataConsumerReleaseInfoCallback = (UnsafeMutableRawPointer?) -> Void

/// A structure that contains pointers to callback functions that manage
/// the copying of data for a data consumer.
///
/// The functions specified by the `CGDataConsumerCallbacks` structure are responsible
/// for copying data that Core Graphics sends to your consumer and for handling the
/// consumer's basic memory management.
public struct CGDataConsumerCallbacks: @unchecked Sendable {
    /// A pointer to the callback function that copies data to the consumer.
    public var putBytes: CGDataConsumerPutBytesCallback?

    /// A pointer to the callback function that releases private data.
    public var releaseConsumer: CGDataConsumerReleaseInfoCallback?

    /// Creates an empty data consumer callbacks structure.
    public init() {
        self.putBytes = nil
        self.releaseConsumer = nil
    }

    /// Creates data consumer callbacks.
    public init(putBytes: CGDataConsumerPutBytesCallback?,
                releaseConsumer: CGDataConsumerReleaseInfoCallback?) {
        self.putBytes = putBytes
        self.releaseConsumer = releaseConsumer
    }
}

// MARK: - CGDataConsumer

/// An abstraction for data-writing tasks that eliminates the need to
/// manage a raw memory buffer.
public class CGDataConsumer: @unchecked Sendable {

    /// The type of data consumer.
    private enum ConsumerType {
        case callback(info: UnsafeMutableRawPointer?, callbacks: CGDataConsumerCallbacks)
        case url(URL)
        case data
    }

    /// The consumer type.
    private let consumerType: ConsumerType

    /// Accumulated data for data-backed consumers.
    private var accumulatedData: Data?

    // MARK: - Initializers

    /// Creates a data consumer that uses callback functions to write data.
    ///
    /// - Parameters:
    ///   - info: A pointer to data that you want passed to your callbacks.
    ///   - cbks: A pointer to a callbacks structure.
    public init?(info: UnsafeMutableRawPointer?, cbks: UnsafePointer<CGDataConsumerCallbacks>) {
        guard cbks.pointee.putBytes != nil else { return nil }
        self.consumerType = .callback(info: info, callbacks: cbks.pointee)
    }

    /// Creates a data consumer that writes data to a location specified by a URL.
    ///
    /// - Parameter url: The URL to write to.
    public init?(url: URL) {
        self.consumerType = .url(url)
        self.accumulatedData = Data()
    }

    /// Creates a data consumer that writes to a Data object.
    ///
    /// - Parameter data: Initial data to start with (optional).
    public init?(data: Data = Data()) {
        self.consumerType = .data
        self.accumulatedData = data
    }

    deinit {
        switch consumerType {
        case .callback(let info, let callbacks):
            callbacks.releaseConsumer?(info)
        case .url(let url):
            // Write accumulated data to URL
            if let data = accumulatedData {
                try? data.write(to: url)
            }
        case .data:
            // Data is already written to the mutable data object
            break
        }
    }

    // MARK: - Writing Data

    /// Writes data to the consumer.
    ///
    /// - Parameters:
    ///   - buffer: The buffer containing the data to write.
    ///   - count: The number of bytes to write.
    /// - Returns: The number of bytes actually written.
    @discardableResult
    public func putBytes(_ buffer: UnsafeRawPointer?, count: Int) -> Int {
        guard let buffer = buffer, count > 0 else { return 0 }

        switch consumerType {
        case .callback(let info, let callbacks):
            return callbacks.putBytes?(info, buffer, count) ?? 0
        case .url, .data:
            let bufferPointer = UnsafeRawBufferPointer(start: buffer, count: count)
            accumulatedData?.append(contentsOf: bufferPointer)
            return count
        }
    }

    // MARK: - Accessing Data

    /// Returns the accumulated data written to this consumer.
    ///
    /// This property is only available for data-backed and URL-backed consumers.
    /// For callback-based consumers, this returns `nil`.
    ///
    /// - Returns: The data written to the consumer, or `nil` for callback consumers.
    public var data: Data? {
        switch consumerType {
        case .data, .url:
            return accumulatedData
        case .callback:
            return nil
        }
    }

    // MARK: - Type ID

    /// Returns the Core Foundation type identifier for Core Graphics data consumers.
    public class var typeID: UInt {
        return 0 // Placeholder
    }
}

// MARK: - Equatable

extension CGDataConsumer: Equatable {
    public static func == (lhs: CGDataConsumer, rhs: CGDataConsumer) -> Bool {
        return lhs === rhs
    }
}

// MARK: - Hashable

extension CGDataConsumer: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

#endif

