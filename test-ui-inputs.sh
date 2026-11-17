#!/bin/zsh
set -euo pipefail
PROJECT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
TEST_DIR="$PROJECT_DIR/build/ui-input-tests"
mkdir -p "$TEST_DIR"
if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
source "$PROJECT_DIR/sources.zsh"
# Clicks and types into a test copy of the panel. Moves the pointer briefly; uses a private clipboard.
cd "$PROJECT_DIR"
xcrun swiftc $SWIFT_TARGET -parse-as-library -plugin-path "$SWIFT_PLUGIN_DIR" $LIBRARY_SOURCES "$PROJECT_DIR/UIInputTests.swift" -o "$TEST_DIR/UIInputTests"
"$TEST_DIR/UIInputTests" "$TEST_DIR"
