#!/bin/zsh
set -euo pipefail
PROJECT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
TEST_DIR="$PROJECT_DIR/build/live-tests"
mkdir -p "$TEST_DIR"
if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
source "$PROJECT_DIR/sources.zsh"
# Drives the installed, running app with the real pointer. Never presses Clear History.
xcrun swiftc $SWIFT_TARGET -parse-as-library "$PROJECT_DIR/ClipboardStore.swift" "$PROJECT_DIR/ClipCategory.swift" "$PROJECT_DIR/LiveTests.swift" -o "$TEST_DIR/LiveTests"
"$TEST_DIR/LiveTests"
