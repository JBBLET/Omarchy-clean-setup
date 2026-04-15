#!/bin/bash
# Clone personal project repos and the Obsidian vault, and install the tmux
# session scripts into ~/.local/bin so they're on PATH.
#
# Intended as the LAST step of install.sh, because it depends on:
#   - setup-user-dirs (targets live under ~/user/Documents/...)
#   - ssh-agent / an SSH key authorized with GitHub (all repos use git@ URLs)
#
# Safe to re-run: already-cloned repos are skipped; scripts are re-copied.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECTS_DIR="$HOME/user/Documents/Projects"
DOCS_DIR="$HOME/user/Documents"
BIN_DIR="$HOME/.local/bin"
TMUX_SRC_DIR="$REPO_ROOT/bin/tmux-sessions"

# ── SSH prerequisite check ───────────────────────────────────────────────

if ! compgen -G "$HOME/.ssh/*.pub" > /dev/null; then
  cat >&2 <<EOF
No SSH public key found in ~/.ssh/.
All repos in this step are cloned over SSH, so you need a key first:

  ssh-keygen -t ed25519 -C your-email@example.com
  cat ~/.ssh/id_ed25519.pub   # add this to https://github.com/settings/keys
  ssh -T git@github.com       # verify: should say "Hi JBBLET!"

Then re-run install.sh (or this script) to clone the repos.
EOF
  exit 1
fi

mkdir -p "$PROJECTS_DIR" "$BIN_DIR"

# ── helpers ──────────────────────────────────────────────────────────────

clone_to() {
  local url="$1"
  local dest="$2"
  local name="$3"

  if [[ -d "$dest/.git" ]]; then
    echo "  $name: already cloned, skipping"
    return 0
  fi
  if [[ -d "$dest" ]]; then
    echo "  $name: path exists but is not a git checkout, skipping" >&2
    echo "    (move $dest aside if you want a fresh clone)" >&2
    return 0
  fi
  echo "  $name: cloning $url..."
  git clone "$url" "$dest"
}

install_tmux_script() {
  local script="$1"
  local src="$TMUX_SRC_DIR/$script"
  local dest="$BIN_DIR/${script%.sh}"   # strip .sh so it's tmux-finlib, not tmux-finlib.sh

  if [[ ! -f "$src" ]]; then
    echo "  tmux script missing in repo: $src" >&2
    return 1
  fi
  install -m 0755 "$src" "$dest"
  echo "  installed $(basename "$dest") -> $dest"
}

# ── clones ───────────────────────────────────────────────────────────────

echo "Cloning project repos..."
clone_to "git@github.com:JBBLET/FinLib.git"    "$PROJECTS_DIR/FinLib"    "FinLib"
clone_to "git@github.com:JBBLET/Sanctuary.git" "$PROJECTS_DIR/Sanctuary" "Sanctuary"

echo "Cloning Obsidian vault..."
clone_to "git@github.com:JBBLET/JB-s-Vault.git" "$DOCS_DIR/JB-s-Vault" "JB-s-Vault"

echo "Installing tmux session launchers..."
install_tmux_script "tmux-finlib.sh"
install_tmux_script "tmux-sanctuary.sh"

echo
echo "Done. Launch a session with:"
echo "  tmux-finlib"
echo "  tmux-sanctuary"
