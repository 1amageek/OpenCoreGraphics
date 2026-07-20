#!/usr/bin/env bash
# Build OCGSmoke.wasm and stage it next to the HTML/JS loader.
#
# Uses Swift 6.3.1 because 6.2.3 deadlocks inside any @MainActor hop on WASM
# (see root workspace memory: feedback_wasm_swift_version_mainactor).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SMOKE_DIR="$SCRIPT_DIR/../../Examples/SmokeTest"
SDK="${OCG_SMOKE_SDK:-swift-6.3.1-RELEASE_wasm}"
JAVASCRIPTKIT_VERSION="${OCG_JAVASCRIPTKIT_VERSION:-0.56.1}"

if [[ -n "${OCG_SWIFT_BIN:-}" ]]; then
    SWIFT_COMMAND=("$OCG_SWIFT_BIN")
elif command -v swiftly >/dev/null 2>&1; then
    SWIFT_COMMAND=(swiftly run swift)
else
    SWIFT_COMMAND=(swift)
fi

echo "→ Building OCGSmoke against SDK=$SDK"
cd "$SMOKE_DIR"
"${SWIFT_COMMAND[@]}" package resolve --version "$JAVASCRIPTKIT_VERSION" javascriptkit
"${SWIFT_COMMAND[@]}" build \
    --product OCGSmoke \
    --swift-sdk "$SDK" \
    -c release \
    --disable-build-manifest-caching

BUILT_WASM="$SMOKE_DIR/.build/wasm32-unknown-wasip1/release/OCGSmoke.wasm"
JAVASCRIPTKIT_RUNTIME="$SMOKE_DIR/.build/checkouts/JavaScriptKit/Plugins/PackageToJS/Templates/runtime.mjs"
if [[ ! -f "$BUILT_WASM" ]]; then
    echo "✗ Build succeeded but $BUILT_WASM is missing" >&2
    exit 1
fi
if [[ ! -f "$JAVASCRIPTKIT_RUNTIME" ]]; then
    echo "✗ JavaScriptKit runtime was not found at $JAVASCRIPTKIT_RUNTIME" >&2
    exit 1
fi

cp "$BUILT_WASM" "$SMOKE_DIR/web/OCGSmoke.wasm"
cp "$JAVASCRIPTKIT_RUNTIME" "$SMOKE_DIR/web/runtime.mjs"
echo "✓ Staged $(du -h "$SMOKE_DIR/web/OCGSmoke.wasm" | awk '{print $1}') at Examples/SmokeTest/web/OCGSmoke.wasm"
