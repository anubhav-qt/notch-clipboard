# Shared source lists for the build and test scripts.
setopt extended_glob
APP_SOURCES=("$PROJECT_DIR"/*.swift~*Tests.swift "$PROJECT_DIR"/components/*.swift)
# Everything except the app entry point, so test programs can bring their own main.
LIBRARY_SOURCES=(${APP_SOURCES:#*/NotchClipboard.swift})
# Apple's @Generable macro lives in the platform plugins, not the default toolchain path.
SWIFT_PLUGIN_DIR="$(xcrun --sdk macosx --show-sdk-platform-path)/Developer/usr/lib/swift/host/plugins"
# Tests build for the same oldest macOS as the app, so availability checks are exercised.
SWIFT_TARGET=(-target arm64-apple-macosx14.0)
