#!/bin/zsh
set -euo pipefail
PROJECT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
TEST_DIR="$PROJECT_DIR/build/saved-removal-tests"
mkdir -p "$TEST_DIR"
if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
source "$PROJECT_DIR/sources.zsh"
# Uses the app views and model without the app entry point, so no live clipboard monitor starts.
xcrun swiftc $SWIFT_TARGET -parse-as-library -plugin-path "$SWIFT_PLUGIN_DIR" $LIBRARY_SOURCES "$PROJECT_DIR/SavedRemovalTests.swift" -o "$TEST_DIR/SavedRemovalTests"
"$TEST_DIR/SavedRemovalTests" "$TEST_DIR"
