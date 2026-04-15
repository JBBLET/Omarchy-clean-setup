#!/bin/bash
# Omarchy clean-setup bootstrap.
#
# Run once after a fresh Omarchy install to reach a fully configured machine.
# Safe to re-run: every step is idempotent.
#
# Usage:
#   cd ~/Omarchy-clean-setup && ./install.sh [--dry-run]
#
# Flags:
#   --dry-run   Print every mutating action without executing it. Read-only
#               checks (file existence, grep) still run so you see which
#               branches the script would take on your machine. Sub-installers
#               (setup-user-dirs, install-themes, install-nightlight) are
#               announced but not invoked in dry-run.
#
# Prerequisites:
#   - Fresh Omarchy install (Arch + Hyprland)
#   - Git configured (user.name, user.email) and this repo cloned locally
#   - Network connectivity
#
# Note on LFS:
#   The repo stores theme background images via git-lfs. If you cloned with
#   GIT_LFS_SKIP_SMUDGE=1 (or before git-lfs was installed on this machine),
#   this script will install git-lfs and pull the LFS content before any
#   step that needs those images.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help)
      sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) printf 'unknown argument: %s\n' "$arg" >&2; exit 2 ;;
  esac
done

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()   { printf '    \033[1;32mok\033[0m %s\n' "$*"; }
warn() { printf '    \033[1;33m!\033[0m %s\n' "$*" >&2; }
die()  { printf '\n\033[1;31mFAIL:\033[0m %s\n' "$*" >&2; exit 1; }
dry()  { printf '    \033[1;35m[dry-run]\033[0m %s\n' "$*"; }

# run <cmd...> — executes in normal mode, prints in dry-run mode.
run() {
  if (( DRY_RUN )); then
    dry "$*"
  else
    "$@"
  fi
}

if (( DRY_RUN )); then
  printf '\n\033[1;35m*** DRY RUN — no changes will be made ***\033[0m\n'
fi

# ── pre-flight ────────────────────────────────────────────────────────────

[[ $EUID -ne 0 ]] || die "do not run this script as root"
command -v pacman >/dev/null 2>&1 || die "pacman not found — this script is for Arch/Omarchy"
command -v sudo   >/dev/null 2>&1 || die "sudo not found"
[[ -d "$REPO_ROOT/.git" ]]        || die "$REPO_ROOT is not a git checkout (LFS step needs it)"

log "Caching sudo credentials"
if (( DRY_RUN )); then
  dry "sudo -v"
else
  sudo -v
fi

# ── 1. git-lfs: install and pull binary assets ────────────────────────────

log "Ensuring git-lfs is installed and LFS content is present"
if ! command -v git-lfs >/dev/null 2>&1; then
  run sudo pacman -S --needed --noconfirm git-lfs
else
  ok "git-lfs already present"
fi
run git -C "$REPO_ROOT" lfs install --local
run git -C "$REPO_ROOT" lfs pull
ok "LFS step scheduled"

# ── 2. XDG user dirs — relocate under ~/user/ (must run before anything    #
#       writes into $HOME) ────────────────────────────────────────────────

log "Relocating XDG user dirs under ~/user/"
run "$REPO_ROOT/bin/setup-user-dirs.sh"

# ── 3. Pacman packages ────────────────────────────────────────────────────
#
# Uses Omarchy's `omarchy-pkg-add` wrapper instead of raw `pacman -S`. The
# wrapper checks for missing packages, runs `pacman -S --noconfirm --needed`,
# and verifies post-install with `pacman -Q` to catch silent failures.

log "Installing pacman packages"
mapfile -t PKGS < <(grep -vE '^\s*(#|$)' "$REPO_ROOT/packages/pacman.txt")
if (( ${#PKGS[@]} > 0 )); then
  if command -v omarchy-pkg-add >/dev/null 2>&1; then
    run omarchy-pkg-add "${PKGS[@]}"
  else
    warn "omarchy-pkg-add not found — falling back to raw pacman"
    run sudo pacman -S --needed --noconfirm "${PKGS[@]}"
  fi
else
  ok "no pacman packages listed"
fi

# ── 4. Dev runtimes via mise (Omarchy philosophy) ────────────────────────
#
# Omarchy ships `mise` in its base packages and activates it in bash via
# ~/.local/share/omarchy/default/bash/init. Languages (python, node, java,
# ruby, go, ...) are NOT installed via pacman — they are managed by mise.
#
#   - Python: install via Omarchy's wrapper, which also installs `uv`.
#   - Java:   pinned to temurin-17 via mise directly. The Omarchy wrapper
#             (`omarchy-install-dev-env java`) only supports @latest; we need
#             17 for the FinLib project so we bypass the wrapper.
#   - Node:   already installed by Omarchy first-boot via mise-work.sh,
#             nothing to do here.

log "Installing dev runtimes via mise"
if ! command -v mise >/dev/null 2>&1; then
  warn "mise not found — Omarchy should ship it; skipping runtime setup"
elif ! command -v omarchy-install-dev-env >/dev/null 2>&1; then
  warn "omarchy-install-dev-env not found — skipping Python wrapper"
else
  run omarchy-install-dev-env python
  run mise use -g java@temurin-17
  ok "mise runtimes configured (python + java@temurin-17)"
fi

# ── 5. AUR packages ───────────────────────────────────────────────────────

log "Installing AUR packages"
mapfile -t AUR_PKGS < <(grep -vE '^\s*(#|$)' "$REPO_ROOT/packages/aur.txt")
if (( ${#AUR_PKGS[@]} > 0 )); then
  if command -v omarchy-pkg-aur-add >/dev/null 2>&1; then
    run omarchy-pkg-aur-add "${AUR_PKGS[@]}"
  elif command -v yay >/dev/null 2>&1; then
    warn "omarchy-pkg-aur-add not found — falling back to raw yay"
    run yay -S --needed --noconfirm "${AUR_PKGS[@]}"
  elif (( DRY_RUN )); then
    warn "neither omarchy-pkg-aur-add nor yay found — would fail in a real run"
  else
    die "neither omarchy-pkg-aur-add nor yay found — Omarchy should ship them"
  fi
else
  ok "no AUR packages listed"
fi

# ── 6. Dotfile symlinks ───────────────────────────────────────────────────
#
# Note: Omarchy ships claude-code natively (in omarchy-base.packages), so there
# is no separate "install Claude Code via npm" phase here. Run `claude` after
# bootstrap to authenticate.

log "Linking dotfiles"

# Hypr: file-by-file so Omarchy's own files (monitors.conf, etc.) coexist.
run mkdir -p "$HOME/.config/hypr"
for f in "$REPO_ROOT"/config/hypr/*.conf; do
  run ln -sfn "$f" "$HOME/.config/hypr/$(basename "$f")"
done
ok "hypr configs linked"

# Neovim: whole directory (we own it).
if [[ -L "$HOME/.config/nvim" || ! -e "$HOME/.config/nvim" ]]; then
  run ln -sfn "$REPO_ROOT/config/nvim" "$HOME/.config/nvim"
  ok "nvim linked"
else
  warn "$HOME/.config/nvim exists and is not a symlink — skipping, back it up manually"
fi

# Venv presets: symlink each requirements file under ~/.venvs/
run mkdir -p "$HOME/.venvs"
for f in "$REPO_ROOT"/venv-presets/*.txt; do
  run ln -sfn "$f" "$HOME/.venvs/$(basename "$f")"
done
ok "venv presets linked"

# ── 7. Japanese input method (fcitx5 + Mozc) ──────────────────────────────
#
# Configures system-wide Japanese input via fcitx5 with the Mozc engine.
# Packages are installed in phase 3; the IM environment variables and the
# `exec-once = fcitx5 -d` autostart line are baked into config/hypr/envs.conf
# and config/hypr/autostart.conf, which were symlinked in phase 6.
# This phase only places the user-side fcitx5 profile (input-method selection
# and hotkeys) by symlinking from the repo so the new machine inherits the
# same Ctrl+Space toggle and "mozc" default IM as the source machine.

log "Configuring Japanese input (fcitx5 + Mozc)"
run mkdir -p "$HOME/.config/fcitx5"
for f in "$REPO_ROOT"/config/fcitx5/*; do
  [[ -f "$f" ]] || continue
  run ln -sfn "$f" "$HOME/.config/fcitx5/$(basename "$f")"
done
ok "fcitx5 profile linked (mozc set as default IM)"

# ── 8. Shell wiring: source mkvenv from ~/.bashrc ─────────────────────────

log "Wiring mkvenv into ~/.bashrc"
BASHRC="$HOME/.bashrc"
if ! grep -Fqs "$REPO_ROOT/shell/mkvenv.sh" "$BASHRC" 2>/dev/null; then
  if (( DRY_RUN )); then
    dry "append 'source \"$REPO_ROOT/shell/mkvenv.sh\"' to $BASHRC"
  else
    {
      printf '\n# Omarchy-clean-setup: mkvenv helper\n'
      printf 'source "%s/shell/mkvenv.sh"\n' "$REPO_ROOT"
    } >> "$BASHRC"
    ok "added mkvenv source line"
  fi
else
  ok "mkvenv already sourced"
fi

# ── 9. Omarchy themes ─────────────────────────────────────────────────────

log "Installing Omarchy themes"
run "$REPO_ROOT/bin/install-themes.sh"

# ── 10. Omarchy theme hooks (imbypass/omarchy-theme-hook) ─────────────────
#
# Installs the community theme-set / theme-set.d/ hook framework which
# repaints alacritty, ghostty, kitty, gtk, waybar, walker, mako, swayosd,
# discord, spotify, vscode, zed, firefox, chromium, ... whenever the Omarchy
# theme changes. Uses Omarchy's bundled wrapper `theme-hook-update`
# (~/.local/share/omarchy/bin/theme-hook-update) which git-clones
# https://github.com/imbypass/omarchy-theme-hook and drops the scripts into
# ~/.config/omarchy/hooks/. Safe to re-run — the wrapper overwrites in place.
# Side effect: the wrapper re-applies the current theme at the end.

log "Installing Omarchy theme hooks"
if command -v theme-hook-update >/dev/null 2>&1; then
  run theme-hook-update
else
  warn "theme-hook-update not found in PATH — skipping theme hooks"
fi

# ── 11. Omarchy webapps ───────────────────────────────────────────────────

log "Installing Omarchy webapps"
run "$REPO_ROOT/bin/install-webapps.sh"

# ── 12. Nightlight automation ─────────────────────────────────────────────

log "Installing nightlight automation"
run "$REPO_ROOT/nightlight/install-nightlight.sh"

# ── 13. Default browser: Google Chrome ────────────────────────────────────

log "Setting Google Chrome as default browser"
if (( DRY_RUN )); then
  dry "xdg-settings set default-web-browser google-chrome.desktop"
elif [[ -f /usr/share/applications/google-chrome.desktop ]]; then
  xdg-settings set default-web-browser google-chrome.desktop
  ok "default browser: $(xdg-settings get default-web-browser)"
else
  warn "google-chrome.desktop not found — skipping (did the AUR install fail?)"
fi

# ── 14. Clone personal projects + vault (LAST step — requires SSH key) ───

log "Cloning personal project repos and Obsidian vault"
run "$REPO_ROOT/bin/clone-projects.sh"

# ── done ──────────────────────────────────────────────────────────────────

if (( DRY_RUN )); then
  printf '\n\033[1;35m*** DRY RUN complete — no changes were made ***\033[0m\n\n'
  exit 0
fi

cat <<'EOF'

============================================================
  Bootstrap complete.
============================================================

Manual follow-ups:
  1. Edit ~/.config/hypr/monitors.conf for this laptop's displays
     (repo intentionally does not track monitors.conf).
  2. If the new machine has NVIDIA, add the NVIDIA env vars back to
     ~/.config/hypr/hyprland.conf (they were stripped from the snapshot).
  3. Log out and back in (or Super+Esc -> Relaunch) so apps pick up the
     new XDG user dirs, default browser, fcitx5/Mozc, and shell wiring.
  4. Open nvim once to let LazyVim sync plugins from lazy-lock.json,
     then run :Mason to install language servers.
  5. Sign in to Spotify and Chrome.
  6. Run `claude` in a terminal to authenticate Claude Code (Omarchy
     ships claude-code natively — no npm install needed).
  7. Verify mise runtimes:  mise ls   (should show python + java@temurin-17)
     If you need other languages, use the Omarchy menu:
        omarchy-install-dev-env <node|ruby|go|rust|...>
  8. If the project/vault clone step was skipped (no SSH key yet),
     generate a key, add it to GitHub, then re-run:
        ./bin/clone-projects.sh

EOF
