#!/bin/bash
# Relocate XDG user dirs under ~/user/.
# Creates ~/user/{Desktop,Documents,Downloads,Music,Pictures,Public,Templates,Videos},
# symlinks the repo's user-dirs.dirs into ~/.config/user-dirs.dirs, and removes
# the empty stock dirs at the top of $HOME.
#
# Intended to run as the FIRST step of the bootstrap, before any app has
# dropped files into ~/Documents, ~/Downloads, etc. Safe to re-run. Will not
# delete non-empty directories.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
USER_BASE="$HOME/user"
DIRS=(Desktop Documents Downloads Music Pictures Public Templates Videos)

echo "Creating $USER_BASE and subdirs..."
mkdir -p "$USER_BASE"
for d in "${DIRS[@]}"; do
  mkdir -p "$USER_BASE/$d"
done

echo "Linking user-dirs.dirs..."
mkdir -p "$HOME/.config"
ln -sfn "$REPO_ROOT/config/xdg/user-dirs.dirs" "$HOME/.config/user-dirs.dirs"

# Disable xdg-user-dirs-update so it doesn't rewrite the file on next login.
cat > "$HOME/.config/user-dirs.conf" <<'EOF'
enabled=False
EOF

echo "Cleaning up empty stock dirs in \$HOME..."
for d in "${DIRS[@]}"; do
  stock="$HOME/$d"
  if [[ -d "$stock" && ! -L "$stock" ]]; then
    if [[ -z "$(ls -A "$stock" 2>/dev/null)" ]]; then
      rmdir "$stock"
      echo "  removed empty $stock"
    else
      echo "  kept $stock (not empty — move contents into $USER_BASE/$d manually)"
    fi
  fi
done

echo
echo "XDG user dirs now point under $USER_BASE."
echo "Log out and back in (or relaunch Hyprland) for all apps to pick up the change."
