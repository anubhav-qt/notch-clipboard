#!/bin/zsh
set -euo pipefail
APP_DIR="$HOME/Applications/Notch Clipboard.app"
AGENT_PATH="$HOME/Library/LaunchAgents/local.notchclipboard.app.plist"
launchctl bootout "gui/$(id -u)/local.notchclipboard.app" 2>/dev/null || true
if [[ -x "$APP_DIR/Contents/MacOS/NotchClipboard" ]]; then
  "$APP_DIR/Contents/MacOS/NotchClipboard" --restore-screenshots
fi
rm -f "$AGENT_PATH"
if [[ -d "$APP_DIR" && -f "$APP_DIR/Contents/Info.plist" ]]; then
  /usr/bin/python3 - "$APP_DIR" <<'PY'
import pathlib, plistlib, shutil, sys
path = pathlib.Path(sys.argv[1])
with (path / 'Contents/Info.plist').open('rb') as f:
    info = plistlib.load(f)
if info.get('CFBundleIdentifier') != 'local.notchclipboard.app':
    raise SystemExit('Refusing to remove an unrelated app')
shutil.rmtree(path)
PY
fi
printf 'Uninstalled. Original screenshot shortcuts restored. Saved history remains in Library/Application Support/Notch Clipboard.\n'
