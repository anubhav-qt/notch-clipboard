#!/bin/zsh
set -euo pipefail
PROJECT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
TEST_DIR="$PROJECT_DIR/build/space-tests"
mkdir -p "$TEST_DIR"
if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
# Exercises the running app with temporary test windows and native Space transitions.
# It restores the previous foreground app and does not change the clipboard.
xcrun swiftc -parse-as-library "$PROJECT_DIR/SpaceTests.swift" -o "$TEST_DIR/SpaceTests"
"$TEST_DIR/SpaceTests" "$TEST_DIR/results.json"
/usr/bin/python3 - "$TEST_DIR/results.json" <<'PY'
import json, sys
with open(sys.argv[1]) as file:
    rows = json.load(file)
for row in rows:
    print(('PASS' if row['passed'] else 'FAIL') + ': ' + row['stage'])
if not rows or rows[-1]['stage'] != 'complete' or not all(row['passed'] for row in rows):
    raise SystemExit(1)
PY
