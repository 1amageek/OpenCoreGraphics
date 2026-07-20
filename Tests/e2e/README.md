# OpenCoreGraphics E2E tests

Browser-based end-to-end tests that exercise the full CGContext → WebGPU
readback pipeline inside real headless Chromium. The smoke-test draws known
fills, images, patterns, masks, shadows, tone-mapped pixels, and strokes,
routes them through the GPU, and asserts the pixel bytes through Swift Testing.

## What is covered

| Spec | Signal validated | Layers exercised |
|---|---|---|
| `wasm_tests.spec.ts` | All 10 Swift `@Test` functions complete without issues | JavaScriptKit bridge, WASI reactor ABI, `setupGraphicsContext`, `CGContext`, `makeImageAsync` |
| Fill and resource readback | RGB fills, image masks, callback patterns, image drawing, shadows, and HDR tone mapping produce the expected pixels | WebGPU render passes, textures, masks, GPU→CPU readback |
| Stroke geometry | Round and square caps, round and miter joins, and dashed strokes produce distinct expected color coverage | `CGPath` dashing, shared stroke geometry, WebGPU tessellation, GPU→CPU readback |

## Prerequisites

1. **Toolchain.** Swift 6.3.1 + the matching WASM SDK. The toolchain must be
   6.3.1 (not 6.2.3) — 6.2.3 deadlocks inside any `@MainActor` hop on WASM.
   `build.sh` prefers `~/.swiftly/bin/swift` when available so the build does
   not accidentally use Xcode's `/usr/bin/swift`.

2. **Build the WASM artifact.**
   ```bash
   ./build.sh
   ```
   This pins JavaScriptKit to `0.56.1`, compiles `Examples/SmokeTest` with
   the `swift-6.3.1-RELEASE_wasm` SDK, and copies `OCGSmoke.wasm` next to the
   HTML/JS loader. `server.mjs` aborts early if the `.wasm` is missing.

3. **Install Playwright (first run only).**
   ```bash
   npm install
   npx playwright install chromium
   ```

## Running

```bash
npm test              # All specs, headless
npm run test:headed   # Visible browser
npm run test:ui       # Playwright UI mode
npm run serve         # Just serve on :8766 (no tests)
```

Override the port with `E2E_PORT=9000 npm test`.

## Why assertions go through a Swift harness, not canvas pixels

`drawImage(webgpuCanvas, 0, 0)` into a 2D context returns an empty image in
most browsers — the `GPUCanvasContext` swap texture is destroyed after
present, so anything read back via the DOM is blank. OCG already performs
its own GPU→CPU readback inside `makeImageAsync()`, so the smoke-test
captures those bytes Swift-side and exposes them through
the Swift Testing runner. Structured test events are exposed through
`window.__wasm_tests`, which the Playwright spec waits for and validates.

This decouples the test from browser-specific canvas readback limitations
and makes assertions deterministic.

## Relationship to megaman E2E

`megaman/tests/e2e/` exercises the full OpenSpriteKit → OpenCoreAnimation
→ OpenCoreGraphics stack. This suite is the **isolation** layer: when
megaman breaks, run this first to localise the regression to (or rule
out) the CGContext layer. Same runtime pattern — JavaScriptKit 0.56.1 on a
WASI reactor module, Playwright + zero-dep Node server — so the skills and
tooling carry across.
