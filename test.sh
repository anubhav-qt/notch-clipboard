#!/bin/zsh
set -euo pipefail
PROJECT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
TEST_DIR="$PROJECT_DIR/build/unit-tests"
mkdir -p "$TEST_DIR"
if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
source "$PROJECT_DIR/sources.zsh"

# Each test program is compiled with only the code it needs, then run.
run_test() {
  local name="$1"
  shift
  xcrun swiftc $SWIFT_TARGET -parse-as-library -plugin-path "$SWIFT_PLUGIN_DIR" "$@" -o "$TEST_DIR/$name"
  "$TEST_DIR/$name" "$TEST_DIR"
}

run_test ClipboardTests "$PROJECT_DIR/ClipCategory.swift" "$PROJECT_DIR/ClipboardStore.swift" "$PROJECT_DIR/Tests.swift"
run_test ClipboardAgeTests "$PROJECT_DIR/ClipboardAge.swift" "$PROJECT_DIR/ClipboardAgeTests.swift"
run_test MonitorScheduleTests "$PROJECT_DIR/MonitorSchedule.swift" "$PROJECT_DIR/MonitorScheduleTests.swift"
run_test HoverDismissalTests "$PROJECT_DIR/HoverDismissal.swift" "$PROJECT_DIR/HoverDismissalTests.swift"
run_test ModelTests $LIBRARY_SOURCES "$PROJECT_DIR/ModelTests.swift"
run_test CategoryTests $LIBRARY_SOURCES "$PROJECT_DIR/CategoryTests.swift"
run_test CategoryListTests "$PROJECT_DIR/ClipCategory.swift" "$PROJECT_DIR/CategoryList.swift" "$PROJECT_DIR/ClipboardStore.swift" "$PROJECT_DIR/ClipCategorizer.swift" "$PROJECT_DIR/CategoryListTests.swift" -framework PDFKit
run_test SelectionTests $LIBRARY_SOURCES "$PROJECT_DIR/SelectionTests.swift"
run_test AccentTests $LIBRARY_SOURCES "$PROJECT_DIR/AccentTests.swift"
