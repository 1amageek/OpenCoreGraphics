//
//  CGDataConsumer.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//


import Foundation
import Synchronization


// MARK: - CGDataConsumerCallbacks

/// Copies data from a Core Graphics-supplied buffer into a data consumer.
///
/// - Parameters:
///   - info: A pointer to private data associated with the consumer.
///   - buffer: A pointer to the buffer containing the data to copy.
///   - count: The number of bytes to copy.
/// - Returns: The number of bytes actually written.
public typealias CGDataConsumerPutBytesCallback = @Sendable (
    UnsafeMutableRawPointer?,       // info
    UnsafeRawPointer?,              // buffer
    Int                             // count
) -> Int

/// Releases any private data or resources associated with the data consumer.
public typealias CGDataConsumerReleaseInfoCallback =
    @Sendable (UnsafeMutableRawPointer?) -> Void

/// A structure that contains pointers to callback functions that manage
/// the copying of data for a data consumer.
///
/// The functions specified by the `CGDataConsumerCallbacks` structure are responsible
/// for copying data that Core Graphics sends to your consumer and for handling the
/// consumer's basic memory management.
public struct CGDataConsumerCallbacks: Sendable {
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

internal enum CGDataConsumerError: Error, Equatable {
    case finalizationInProgress
}

/// An abstraction for data-writing tasks that eliminates the need to
/// manage a raw memory buffer.
public final class CGDataConsumer {
    private enum FinalizePlan {
        case none
        case write(URL, Data)
        case busy
    }

    /// The type of data consumer.
    private enum ConsumerType {
        case callback(info: UnsafeMutableRawPointer?, callbacks: CGDataConsumerCallbacks)
        case url(URL)
        case data
    }

    private struct State {
        var accumulatedData: Data?
        var isFinalizing = false
        var isFinalized = false
    }

    private let consumerType: ConsumerType
    private let state: Mutex<State>

    // MARK: - Initializers

    /// Creates a data consumer that uses callback functions to write data.
    ///
    /// - Parameters:
    ///   - info: A pointer to data that you want passed to your callbacks.
    ///   - cbks: A pointer to a callbacks structure.
    public init?(info: UnsafeMutableRawPointer?, cbks: UnsafePointer<CGDataConsumerCallbacks>) {
        guard cbks.pointee.putBytes != nil else { return nil }
        self.consumerType = .callback(
            info: info,
            callbacks: cbks.pointee
        )
        self.state = Mutex(
            State()
        )
    }

    /// Creates a data consumer that writes data to a location specified by a URL.
    ///
    /// - Parameter url: The URL to write to.
    public init?(url: URL) {
        self.consumerType = .url(url)
        self.state = Mutex(
            State(
                accumulatedData: Data()
            )
        )
    }

    /// Creates a data consumer that writes to a Data object.
    ///
    /// - Parameter data: Initial data to start with (optional).
    public init?(data: Data = Data()) {
        self.consumerType = .data
        self.state = Mutex(
            State(
                accumulatedData: data
            )
        )
    }

    deinit {
        let teardown = state.withLock {
            (
                $0.accumulatedData,
                $0.isFinalized
            )
        }
        switch consumerType {
        case .callback(let info, let callbacks):
            callbacks.releaseConsumer?(info)
        case .url(let url):
            // Best-effort write at teardown when caller did not call `finalize()`.
            // deinit can't throw, so failures are reported via stderr rather than
            // swallowed silently.
            if !teardown.1, let data = teardown.0 {
                do {
                    try data.write(to: url)
                } catch {
                    print("CGDataConsumer: fallback write failed in deinit: \(error)")
                }
            }
        case .data:
            // Data is already written to the mutable data object
            break
        }
    }

    // MARK: - Finalizing

    /// Writes the accumulated data of a URL-backed consumer to disk.
    ///
    /// Call this before the consumer is deallocated when you need explicit
    /// write-error reporting. For data-backed or callback-based consumers,
    /// `finalize()` is a no-op.
    ///
    /// - Throws: Any error produced by `Data.write(to:)`.
    internal func finalize() throws {
        let writePlan = state.withLock {
            state -> FinalizePlan in
            guard case .url(let url) = consumerType,
                  !state.isFinalized,
                  let data = state.accumulatedData else {
                return .none
            }
            guard !state.isFinalizing else {
                return .busy
            }
            state.isFinalizing = true
            return .write(url, data)
        }
        let url: URL
        let data: Data
        switch writePlan {
        case .none:
            return
        case .busy:
            throw CGDataConsumerError.finalizationInProgress
        case .write(let plannedURL, let plannedData):
            url = plannedURL
            data = plannedData
        }
        do {
            try data.write(to: url)
            state.withLock {
                $0.isFinalizing = false
                $0.isFinalized = true
            }
        } catch {
            state.withLock {
                $0.isFinalizing = false
            }
            throw error
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
        case .url:
            let accepted = state.withLock {
                state -> Bool in
                guard !state.isFinalizing,
                      !state.isFinalized else {
                    return false
                }
                let bufferPointer = UnsafeRawBufferPointer(
                    start: buffer,
                    count: count
                )
                state.accumulatedData?.append(
                    contentsOf: bufferPointer
                )
                return true
            }
            return accepted ? count : 0
        case .data:
            state.withLock {
                state in
                let bufferPointer = UnsafeRawBufferPointer(
                    start: buffer,
                    count: count
                )
                state.accumulatedData?.append(
                    contentsOf: bufferPointer
                )
            }
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
        state.withLock {
            switch consumerType {
            case .data, .url:
                return $0.accumulatedData
            case .callback:
                return nil
            }
        }
    }

    // MARK: - Type ID

    /// Returns the Core Foundation type identifier for Core Graphics data consumers.
    public class var typeID: UInt {
        return CGTypeIdentifier.dataConsumer
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
