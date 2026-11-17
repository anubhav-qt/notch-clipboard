#!/bin/zsh
set -euo pipefail
PROJECT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
APP_DIR="$PROJECT_DIR/build/Notch Clipboard.app"
export MACOSX_DEPLOYMENT_TARGET=14.0
if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
source "$PROJECT_DIR/sources.zsh"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
xcrun swiftc -O -whole-module-optimization $SWIFT_TARGET -plugin-path "$SWIFT_PLUGIN_DIR" \
  -parse-as-library $APP_SOURCES \
  -framework AppKit -framework SwiftUI -framework QuartzCore -framework CoreFoundation -framework PDFKit \
  -Xlinker -weak_framework -Xlinker FoundationModels \
  -o "$APP_DIR/Contents/MacOS/NotchClipboard"
cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>NotchClipboard</string>
<key>CFBundleIdentifier</key><string>local.notchclipboard.app</string>
<key>CFBundleName</key><string>Notch Clipboard</string>
<key>CFBundleDisplayName</key><string>Notch Clipboard</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.1</string>
<key>CFBundleVersion</key><string>11</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - --identifier local.notchclipboard.app "$APP_DIR"
printf 'Built %s\n' "$APP_DIR"
