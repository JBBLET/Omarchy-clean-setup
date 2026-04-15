#!/bin/bash
# Sync the custom theme backgrounds from this repo into the live
# ~/.config/omarchy/themes/<name>/backgrounds/ directories.
#
# Omarchy's background-picker menu does not follow symlinks, so the
# background images must exist as real files under the theme directory.
# This script copies them on top of whatever is there — safe to re-run
# after `git pull` to pick up new or updated backgrounds.
#
# It does NOT change the active background. After running, open:
#     Super + Ctrl + Alt + Space   (Omarchy background menu)
# and pick the one you want.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THEMES_DIR="$HOME/.config/omarchy/themes"
REPO_THEMES="$REPO_ROOT/config/omarchy-themes"

if [[ ! -d "$REPO_THEMES" ]]; then
  echo "No repo themes dir at $REPO_THEMES — nothing to sync" >&2
  exit 0
fi

shopt -s nullglob
synced=0
for theme_path in "$REPO_THEMES"/*/; do
  name="$(basename "$theme_path")"
  src="$theme_path/backgrounds"
  dest="$THEMES_DIR/$name/backgrounds"

  if [[ ! -d "$src" ]]; then
    continue
  fi
  if [[ ! -d "$THEMES_DIR/$name" ]]; then
    echo "  $name: theme not installed at $THEMES_DIR/$name, skipping"
    continue
  fi

  # If Omarchy currently ships a real dir, keep it (only the first time).
  # On subsequent runs this is already our copy and we just overwrite.
  mkdir -p "$dest"

  # Copy each image individually. We don't delete pre-existing files so a
  # user can drop extra backgrounds into the theme dir without this script
  # blowing them away.
  for img in "$src"/*.{png,jpg,jpeg,PNG,JPG,JPEG}; do
    [[ -f "$img" ]] || continue
    install -m 0644 "$img" "$dest/$(basename "$img")"
  done
  echo "  $name: backgrounds synced to $dest"
  synced=$((synced + 1))
done

if (( synced == 0 )); then
  echo "Nothing to sync (no matching themes found)." >&2
else
  echo
  echo "Done. Open the background picker (Super+Ctrl+Alt+Space) to select one."
fi
