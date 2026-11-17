#!/bin/zsh
set -euo pipefail
PROJECT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
TEST_DIR="$PROJECT_DIR/build/presentation-tests"
mkdir -p "$TEST_DIR"
if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
xcrun swiftc -parse-as-library "$PROJECT_DIR/NotchGeometry.swift" "$PROJECT_DIR/NotchGeometryTests.swift" -o "$TEST_DIR/NotchGeometryTests"
"$TEST_DIR/NotchGeometryTests"
xcrun swiftc -parse-as-library "$PROJECT_DIR/PanelSurface.swift" "$PROJECT_DIR/PanelSurfaceTests.swift" -o "$TEST_DIR/PanelSurfaceTests"
"$TEST_DIR/PanelSurfaceTests"
xcrun swiftc -parse-as-library "$PROJECT_DIR/PanelSurface.swift" "$PROJECT_DIR/components/HoverRegion.swift" "$PROJECT_DIR/HoverTests.swift" -o "$TEST_DIR/HoverTests"
"$TEST_DIR/HoverTests"
