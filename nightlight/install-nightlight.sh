#!/bin/bash
# Nightlight automation installer for Omarchy.
# Sets up hyprsunset to run 19:00-07:00 via systemd user timers,
# plus a login-time hook (wired separately in config/hypr/hyprland.conf).
#
# Safe to re-run: symlinks are refreshed, timers are re-enabled.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
LOCAL_BIN="$HOME/.local/bin"

mkdir -p "$SYSTEMD_USER_DIR" "$LOCAL_BIN"

echo "Linking systemd user units..."
for unit in nightlight-on.service nightlight-off.service nightlight-on.timer nightlight-off.timer; do
  ln -sfn "$SCRIPT_DIR/$unit" "$SYSTEMD_USER_DIR/$unit"
done

echo "Linking nightlight-auto.sh into $LOCAL_BIN..."
ln -sfn "$SCRIPT_DIR/nightlight-auto.sh" "$LOCAL_BIN/nightlight-auto.sh"
chmod +x "$SCRIPT_DIR/nightlight-auto.sh"

echo "Reloading systemd user daemon..."
systemctl --user daemon-reload

echo "Enabling timers..."
systemctl --user enable --now nightlight-on.timer
systemctl --user enable --now nightlight-off.timer

echo
echo "Nightlight automation installed."
echo "  - ON at 19:00, OFF at 07:00 (systemd timers)"
echo "  - Login hook is wired via config/hypr/hyprland.conf -> exec-once = ~/.local/bin/nightlight-auto.sh"
echo "  - Check: systemctl --user list-timers | grep nightlight"
echo "  - To change temperature, edit nightlight-on.service and nightlight-auto.sh (-t 4500, lower = warmer)"
