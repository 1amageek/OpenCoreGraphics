//
//  WebGPURendererManager.swift
//  OpenCoreGraphics
//
//  Internal manager for WebGPU renderer lifecycle.
//  Provides automatic renderer setup for CGContext on WASM.
//

#if arch(wasm32)
import Foundation
import SwiftWebGPU
import JavaScriptKit

/// Internal manager for WebGPU renderer lifecycle.
///
/// This class handles the initialization and management of WebGPU resources,
/// providing renderers to CGContext instances automatically. Users do not
/// interact with this class directly - it is an internal implementation detail.
///
/// ## Important: Async Initialization Required
///
/// WebGPU requires asynchronous initialization. Call `initialize()` once
/// at application startup before creating any CGContext:
///
/// ```swift
/// // At app startup
/// await WebGPURendererManager.shared.initialize()
///
/// // Then use CGContext normally
/// let context = CGContext(...)
/// ```
internal final class WebGPURendererManager: @unchecked Sendable {

    // MARK: - Singleton

    /// Shared instance for managing WebGPU renderers.
    static let shared = WebGPURendererManager()

    // MARK: - Properties

    /// The WebGPU device, lazily initialized.
    private var device: GPUDevice?

    /// Whether WebGPU has been initialized.
    private var isInitialized = false

    /// Whether initialization is in progress.
    private var isInitializing = false

    /// Initialization error if any occurred.
    private var initializationError: Error?

    /// Lock for thread-safe initialization.
    private let lock = NSLock()

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Initializes WebGPU asynchronously.
    ///
    /// This method should be called once at application startup before
    /// creating any CGContext. It initializes the WebGPU device which
    /// is required for rendering.
    ///
    /// ```swift
    /// // At app startup
    /// await WebGPURendererManager.shared.initialize()
    /// ```
    func initialize() async {
        await initializeWebGPU()
    }

    /// Returns whether WebGPU is initialized and ready.
    var isReady: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isInitialized && device != nil
    }

    /// Creates a renderer for a CGContext.
    ///
    /// This method returns a configured renderer delegate for the context.
    /// Returns nil if WebGPU has not been initialized yet.
    ///
    /// - Parameters:
    ///   - width: The width of the rendering target.
    ///   - height: The height of the rendering target.
    /// - Returns: A renderer delegate, or nil if WebGPU is not available.
    func createRenderer(width: Int, height: Int) -> CGContextRendererDelegate? {
        lock.lock()
        defer { lock.unlock() }

        guard let device = device else {
            // WebGPU not initialized yet
            return nil
        }

        // Create and return a new renderer with default texture format
        // The texture format is typically bgra8unorm for canvas rendering
        return CGWebGPUContextRenderer(
            device: device,
            textureFormat: .bgra8unorm,
            viewportWidth: CGFloat(width),
            viewportHeight: CGFloat(height)
        )
    }

    /// Creates a renderer asynchronously, initializing WebGPU if needed.
    ///
    /// This method performs async WebGPU initialization if not already done,
    /// then returns a configured renderer delegate.
    ///
    /// - Parameters:
    ///   - width: The width of the rendering target.
    ///   - height: The height of the rendering target.
    /// - Returns: A renderer delegate, or nil if WebGPU is not available.
    func createRendererAsync(width: Int, height: Int) async -> CGContextRendererDelegate? {
        // Ensure WebGPU is initialized
        if !isInitialized {
            await initializeWebGPU()
        }

        lock.lock()
        defer { lock.unlock() }

        guard let device = device else {
            return nil
        }

        // Create and return a new renderer with default texture format
        return CGWebGPUContextRenderer(
            device: device,
            textureFormat: .bgra8unorm,
            viewportWidth: CGFloat(width),
            viewportHeight: CGFloat(height)
        )
    }

    // MARK: - Private Methods

    /// Asynchronously initializes WebGPU.
    private func initializeWebGPU() async {
        lock.lock()
        if isInitialized || isInitializing {
            lock.unlock()
            return
        }
        isInitializing = true
        lock.unlock()

        do {
            // Get the GPU from the navigator
            let gpu = JSObject.global.navigator.gpu
            guard !gpu.isUndefined else {
                lock.lock()
                initializationError = WebGPUError.notSupported
                isInitialized = true
                isInitializing = false
                lock.unlock()
                return
            }

            // Request adapter
            let adapterPromise = gpu.requestAdapter()
            let adapter = try await JSPromise(adapterPromise.object!)!.value

            guard !adapter.isUndefined && !adapter.isNull else {
                lock.lock()
                initializationError = WebGPUError.adapterNotAvailable
                isInitialized = true
                isInitializing = false
                lock.unlock()
                return
            }

            // Request device
            let devicePromise = adapter.requestDevice()
            let deviceJS = try await JSPromise(devicePromise.object!)!.value

            guard !deviceJS.isUndefined && !deviceJS.isNull else {
                lock.lock()
                initializationError = WebGPUError.deviceNotAvailable
                isInitialized = true
                isInitializing = false
                lock.unlock()
                return
            }

            lock.lock()
            self.device = GPUDevice(from: deviceJS)
            isInitialized = true
            isInitializing = false
            lock.unlock()

        } catch {
            lock.lock()
            initializationError = error
            isInitialized = true
            isInitializing = false
            lock.unlock()
        }
    }
}

// MARK: - Errors

/// Errors that can occur during WebGPU initialization.
internal enum WebGPUError: Error {
    case notSupported
    case adapterNotAvailable
    case deviceNotAvailable
}

#endif
