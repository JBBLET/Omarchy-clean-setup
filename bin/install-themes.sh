#!/bin/bash
# Install custom Omarchy themes.
#
# For each theme: git clone the upstream config files if not already cloned.
# Background images are NOT symlinked because Omarchy's background-picker
# menu does not follow symlinks — instead they are copied into place by
# `sync-backgrounds.sh`, which is called at the end of this script and is
# also safe to run standalone after `git pull`.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THEMES_DIR="$HOME/.config/omarchy/themes"

mkdir -p "$THEMES_DIR"

install_theme() {
  local name="$1"
  local url="$2"
  local dest="$THEMES_DIR/$name"

  if [[ -d "$dest/.git" ]]; then
    echo "  $name: already cloned, skipping clone"
    return 0
  fi
  if [[ -d "$dest" ]]; then
    echo "  $name: path exists but is not a git checkout, skipping" >&2
    echo "    (move $dest aside if you want a fresh clone)" >&2
    return 0
  fi
  echo "  $name: cloning from $url..."
  git clone --depth 1 "$url" "$dest"
}

echo "Installing Omarchy themes..."
install_theme "arc-blueberry-custom" "https://github.com/vale-c/omarchy-arc-blueberry.git"
install_theme "solitude"              "https://github.com/HANCORE-linux/omarchy-solitude-theme.git"

echo
echo "Syncing custom backgrounds..."
"$REPO_ROOT/bin/sync-backgrounds.sh"

echo
echo "Themes installed. Pick one via the Omarchy menu (Super + Ctrl + Shift + Space)"
echo "or with: omarchy-theme-set <theme-name>"
