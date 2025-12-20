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
internal final class WebGPURendererManager: @unchecked Sendable {

    // MARK: - Singleton

    /// Shared instance for managing WebGPU renderers.
    static let shared = WebGPURendererManager()

    // MARK: - Properties

    /// The WebGPU device, lazily initialized.
    private var device: GPUDevice?

    /// Whether WebGPU has been initialized.
    private var isInitialized = false

    /// Initialization error if any occurred.
    private var initializationError: Error?

    /// Lock for thread-safe initialization.
    private let lock = NSLock()

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Creates a renderer for a CGContext.
    ///
    /// This method lazily initializes WebGPU on first call and returns
    /// a configured renderer delegate for the context.
    ///
    /// - Parameters:
    ///   - width: The width of the rendering target.
    ///   - height: The height of the rendering target.
    /// - Returns: A renderer delegate, or nil if WebGPU is not available.
    func createRenderer(width: Int, height: Int) -> CGContextRendererDelegate? {
        lock.lock()
        defer { lock.unlock() }

        // Try to initialize WebGPU if not already done
        if !isInitialized {
            initializeWebGPUSync()
        }

        guard let device = device else {
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

    /// Creates a renderer asynchronously.
    ///
    /// This method performs async WebGPU initialization and returns
    /// a configured renderer delegate.
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

    /// Synchronously initializes WebGPU.
    private func initializeWebGPUSync() {
        guard !isInitialized else { return }

        do {
            // Get the GPU from the navigator
            let gpu = JSObject.global.navigator.gpu
            guard !gpu.isUndefined else {
                initializationError = WebGPUError.notSupported
                isInitialized = true
                return
            }

            // Note: In synchronous context, we can't await adapter/device.
            // This is a limitation - async initialization is preferred.
            isInitialized = true
        } catch {
            initializationError = error
            isInitialized = true
        }
    }

    /// Asynchronously initializes WebGPU.
    private func initializeWebGPU() async {
        lock.lock()
        guard !isInitialized else {
            lock.unlock()
            return
        }
        lock.unlock()

        do {
            // Get the GPU from the navigator
            let gpu = JSObject.global.navigator.gpu
            guard !gpu.isUndefined else {
                lock.lock()
                initializationError = WebGPUError.notSupported
                isInitialized = true
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
                lock.unlock()
                return
            }

            lock.lock()
            self.device = GPUDevice(from: deviceJS)
            isInitialized = true
            lock.unlock()

        } catch {
            lock.lock()
            initializationError = error
            isInitialized = true
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
