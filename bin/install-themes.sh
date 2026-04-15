#!/bin/bash
# Install custom Omarchy themes.
#
# For each theme: git clone the upstream config files, then replace the
# cloned backgrounds/ directory with a symlink to this repo's version, so
# that the custom background images are preserved and stay editable from
# the repo.
#
# Safe to re-run: already-cloned themes are skipped; the backgrounds symlink
# is always refreshed.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THEMES_DIR="$HOME/.config/omarchy/themes"
REPO_THEMES="$REPO_ROOT/config/omarchy-themes"

mkdir -p "$THEMES_DIR"

install_theme() {
  local name="$1"
  local url="$2"
  local dest="$THEMES_DIR/$name"
  local repo_backgrounds="$REPO_THEMES/$name/backgrounds"

  if [[ ! -d "$repo_backgrounds" ]]; then
    echo "  $name: missing $repo_backgrounds in repo, aborting" >&2
    return 1
  fi

  if [[ -d "$dest/.git" ]]; then
    echo "  $name: already cloned, skipping clone"
  elif [[ -d "$dest" ]]; then
    echo "  $name: path exists but is not a git checkout, skipping" >&2
    echo "    (move $dest aside if you want a fresh clone)" >&2
    return 0
  else
    echo "  $name: cloning from $url..."
    git clone --depth 1 "$url" "$dest"
  fi

  # Replace cloned backgrounds/ with symlink to repo version.
  if [[ -L "$dest/backgrounds" ]]; then
    :
  elif [[ -d "$dest/backgrounds" ]]; then
    rm -rf "$dest/backgrounds"
  fi
  ln -sfn "$repo_backgrounds" "$dest/backgrounds"
  echo "  $name: backgrounds -> $repo_backgrounds"
}

echo "Installing Omarchy themes..."
install_theme "arc-blueberry-custom" "https://github.com/vale-c/omarchy-arc-blueberry.git"
install_theme "solitude"              "https://github.com/HANCORE-linux/omarchy-solitude-theme.git"

echo
echo "Themes installed. Pick one via the Omarchy menu (Super + Ctrl + Shift + Space)"
echo "or with: omarchy-theme-set <theme-name>"
