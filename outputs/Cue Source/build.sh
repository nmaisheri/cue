#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="${1:-$ROOT/../Cue.app}"
CACHE="${TMPDIR:-/tmp}/cue-swift-build"
export CLANG_MODULE_CACHE_PATH="$CACHE/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$CACHE/ModuleCache"
swift build --disable-sandbox --cache-path "$CACHE/cache" --package-path "$ROOT" --scratch-path "$CACHE" --product Cue -c release
# Sign outside cloud-synced folders so Finder metadata cannot race codesign.
STAGING="$(mktemp -d "$CACHE/staging.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
BUNDLE="$STAGING/Cue.app"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$CACHE/release/Cue" "$BUNDLE/Contents/MacOS/Cue"
cp "$ROOT/Info.plist" "$BUNDLE/Contents/Info.plist"
cp "$ROOT/Cue.icns" "$BUNDLE/Contents/Resources/Cue.icns"
xattr -cr "$BUNDLE"
codesign --force --sign - "$BUNDLE"
codesign --verify --deep --strict "$BUNDLE"
ditto --norsrc --noextattr "$BUNDLE" "$APP"
echo "Built $APP (quit any older running copy before reopening)"
