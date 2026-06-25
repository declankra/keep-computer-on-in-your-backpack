#!/bin/zsh
set -eu

REPO_URL="${REPO_URL:-https://github.com/declankra/keep-computer-on-in-your-backpack.git}"
WORK_DIR="${TMPDIR:-/tmp}/backpack-awake-install"
SOURCE_DIR="${BACKPACK_AWAKE_SOURCE_DIR:-}"
APP_NAME="Backpack Awake.app"
APP_DIR="$HOME/Applications/$APP_NAME"
STATE_DIR="$HOME/Library/Application Support/BackpackAwake"
LOGIN_AGENT="$HOME/Library/LaunchAgents/com.declankramper.backpack-awake-menu.plist"
CONTROLLER_DIR="/Library/Application Support/BackpackAwake"
CONTROLLER_PATH="$CONTROLLER_DIR/backpack-awake-controller"
CONTROLLER_PLIST="/Library/LaunchDaemons/com.declankramper.backpack-awake-controller.plist"
LOG_DIR="/Library/Logs/BackpackAwake"

need_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

need_command swiftc
need_command codesign

if [[ -n "$SOURCE_DIR" ]]; then
  WORK_DIR="$SOURCE_DIR"
else
  need_command git
  rm -rf "$WORK_DIR"
  git clone --depth 1 "$REPO_URL" "$WORK_DIR"
fi

mkdir -p "$APP_DIR/Contents/MacOS" "$HOME/Applications" "$STATE_DIR" "$HOME/Library/LaunchAgents"

swiftc "$WORK_DIR/Sources/main.swift" -framework AppKit -o "$APP_DIR/Contents/MacOS/BackpackAwakeMenu"
cp "$WORK_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"
codesign --force --deep --sign - "$APP_DIR" >/dev/null

if [[ ! -f "$STATE_DIR/state" ]]; then
  printf 'off\n' > "$STATE_DIR/state"
fi

cat > "$LOGIN_AGENT" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.declankramper.backpack-awake-menu</string>

  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/open</string>
    <string>$APP_DIR</string>
  </array>

  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
PLIST

if [[ "${BACKPACK_AWAKE_SKIP_PRIVILEGED:-0}" != "1" ]]; then
  echo "Installing the privileged controller. macOS may ask for your password once."
  sudo mkdir -p "$CONTROLLER_DIR" "$LOG_DIR"
  sudo install -o root -g wheel -m 755 "$WORK_DIR/scripts/backpack-awake-controller" "$CONTROLLER_PATH"
  sudo install -o root -g wheel -m 644 "$WORK_DIR/scripts/com.declankramper.backpack-awake-controller.plist" "$CONTROLLER_PLIST"
  sudo launchctl bootout system "$CONTROLLER_PLIST" 2>/dev/null || true
  sudo launchctl bootstrap system "$CONTROLLER_PLIST"
  sudo launchctl kickstart -k system/com.declankramper.backpack-awake-controller
else
  echo "Skipping privileged controller install."
fi

if [[ "${BACKPACK_AWAKE_SKIP_LAUNCH:-0}" != "1" ]]; then
  launchctl bootout "gui/$(id -u)" "$LOGIN_AGENT" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$LOGIN_AGENT"
  launchctl kickstart -k "gui/$(id -u)/com.declankramper.backpack-awake-menu"
  open "$APP_DIR"
fi

echo "Installed. Look for the backpack icon in your menu bar."
