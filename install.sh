#!/bin/zsh
set -eu

REPO_URL="${REPO_URL:-https://github.com/declankra/keep-computer-on-in-your-backpack.git}"
WORK_DIR="${TMPDIR:-/tmp}/backpack-awake-install"
APP_NAME="Backpack Awake.app"
APP_DIR="$HOME/Applications/$APP_NAME"
STATE_DIR="$HOME/Library/Application Support/BackpackAwake"
LOGIN_AGENT="$HOME/Library/LaunchAgents/com.declankramper.backpack-awake-menu.plist"

need_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

need_command git
need_command swiftc
need_command codesign

rm -rf "$WORK_DIR"
git clone --depth 1 "$REPO_URL" "$WORK_DIR"

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

echo "Installing the privileged controller. macOS may ask for your password once."
sudo mkdir -p /usr/local/sbin
sudo install -o root -g wheel -m 755 "$WORK_DIR/scripts/backpack-awake-controller" /usr/local/sbin/backpack-awake-controller
sudo install -o root -g wheel -m 644 "$WORK_DIR/scripts/com.declankramper.backpack-awake-controller.plist" /Library/LaunchDaemons/com.declankramper.backpack-awake-controller.plist
sudo launchctl bootout system /Library/LaunchDaemons/com.declankramper.backpack-awake-controller.plist 2>/dev/null || true
sudo launchctl bootstrap system /Library/LaunchDaemons/com.declankramper.backpack-awake-controller.plist
sudo launchctl kickstart -k system/com.declankramper.backpack-awake-controller

if [[ "${BACKPACK_AWAKE_SKIP_LAUNCH:-0}" != "1" ]]; then
  launchctl bootout "gui/$(id -u)" "$LOGIN_AGENT" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$LOGIN_AGENT"
  launchctl kickstart -k "gui/$(id -u)/com.declankramper.backpack-awake-menu"
  open "$APP_DIR"
fi

echo "Installed. Look for the backpack icon in your menu bar."
