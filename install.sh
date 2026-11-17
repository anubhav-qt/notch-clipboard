#!/bin/zsh
set -euo pipefail
PROJECT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
APP_DIR="$HOME/Applications/Notch Clipboard.app"
AGENT_PATH="$HOME/Library/LaunchAgents/local.notchclipboard.app.plist"
DATA_DIR="$HOME/Library/Application Support/Notch Clipboard"
"$PROJECT_DIR/build.sh"
mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents" "$DATA_DIR"
chmod 700 "$DATA_DIR"
launchctl bootout "gui/$(id -u)/local.notchclipboard.app" 2>/dev/null || true
# A clean copy, so files dropped from the build do not linger.
rm -rf "$APP_DIR"
ditto "$PROJECT_DIR/build/Notch Clipboard.app" "$APP_DIR"
"$APP_DIR/Contents/MacOS/NotchClipboard" --configure-screenshots
# plistlib escapes spaces and any special characters in account paths.
/usr/bin/python3 - "$APP_DIR" "$AGENT_PATH" "$DATA_DIR" <<'PY'
import os, plistlib, sys
app, agent, data = sys.argv[1:]
value = {
  'Label': 'local.notchclipboard.app',
  'ProgramArguments': [app + '/Contents/MacOS/NotchClipboard'],
  'RunAtLoad': True,
  'LimitLoadToSessionType': 'Aqua',
  'ProcessType': 'Interactive',
  'StandardOutPath': data + '/app.log',
  'StandardErrorPath': data + '/app.log',
}
with open(agent, 'wb') as f:
    plistlib.dump(value, f)
os.chmod(agent, 0o600)
PY
/usr/bin/python3 - "$AGENT_PATH" <<'PY'
import os, subprocess, sys, time
for attempt in range(12):
    result = subprocess.run(['launchctl', 'bootstrap', f'gui/{os.getuid()}', sys.argv[1]], capture_output=True)
    if result.returncode == 0:
        break
    time.sleep(0.2)
else:
    sys.stderr.buffer.write(result.stderr)
    raise SystemExit(result.returncode)
PY
printf 'Installed and started %s\n' "$APP_DIR"
