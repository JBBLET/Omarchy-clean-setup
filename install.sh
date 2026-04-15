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

# Neovim: whole directory (we own it). On a fresh Omarchy machine,
# `omarchy-nvim-setup` has already copied Omarchy's stock LazyVim config to
# ~/.config/nvim as a real directory — we back that up (timestamped) and
# replace it with a symlink to our version. Already-a-symlink → just relink.
NVIM_DIR="$HOME/.config/nvim"
if [[ -L "$NVIM_DIR" || ! -e "$NVIM_DIR" ]]; then
  run ln -sfn "$REPO_ROOT/config/nvim" "$NVIM_DIR"
  ok "nvim linked"
else
  NVIM_BAK="$NVIM_DIR.bak.$(date +%Y%m%d-%H%M%S)"
  warn "$NVIM_DIR is a real directory (Omarchy default?), backing up to $NVIM_BAK"
  run mv "$NVIM_DIR" "$NVIM_BAK"
  run ln -sfn "$REPO_ROOT/config/nvim" "$NVIM_DIR"
  ok "nvim linked (previous config at $NVIM_BAK)"
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

# fcitx5 was likely started by Omarchy's default Hyprland autostart before
# install.sh ran — it doesn't know about the mozc addon (installed in phase 3)
# or the new profile (symlinked just above). Restart it so the next keypress
# picks up both. Swallow errors: fcitx5 might not be running at all (e.g. when
# install.sh is re-run from a TTY), in which case `pkill` exits non-zero.
if pgrep -x fcitx5 >/dev/null 2>&1; then
  run bash -c 'pkill -x fcitx5 2>/dev/null; sleep 0.3; fcitx5 -d >/dev/null 2>&1 &'
  ok "fcitx5 restarted to load mozc + new profile"
else
  ok "fcitx5 not running — it will start via hypr autostart on next session"
fi

# ── 8. Application desktop entries (TUI apps: LazySQL, LazyDocker) ───────
#
# Registers TUI apps (lazysql, lazydocker) in Walker / app launchers by
# dropping .desktop files into ~/.local/share/applications/. Icons live
# alongside at ~/.local/share/applications/icons/ (matching the path
# baked into the .desktop Icon= field). The desktop files are stored in
# the repo with an __HOME__ placeholder which we rewrite with the real
# $HOME at install time — this avoids committing a machine-specific path
# into git. Copies, not symlinks, so xdg-desktop-database / walker pick
# them up without any follow-symlink caveats.

log "Installing application desktop entries"
APPS_SRC="$REPO_ROOT/config/applications"
APPS_DST="$HOME/.local/share/applications"
ICONS_DST="$APPS_DST/icons"
if [[ -d "$APPS_SRC" ]]; then
  run mkdir -p "$APPS_DST" "$ICONS_DST"
  for icon in "$APPS_SRC"/icons/*; do
    [[ -f "$icon" ]] || continue
    run install -m 0644 "$icon" "$ICONS_DST/$(basename "$icon")"
  done
  for desktop in "$APPS_SRC"/*.desktop; do
    [[ -f "$desktop" ]] || continue
    dest="$APPS_DST/$(basename "$desktop")"
    if (( DRY_RUN )); then
      dry "sed 's|__HOME__|$HOME|g' $desktop > $dest"
    else
      sed "s|__HOME__|$HOME|g" "$desktop" > "$dest"
      chmod 0644 "$dest"
    fi
  done
  if command -v update-desktop-database >/dev/null 2>&1; then
    run update-desktop-database "$APPS_DST"
  fi
  ok "desktop entries installed to $APPS_DST"
else
  warn "no $APPS_SRC — skipping desktop entries"
fi

# ── 9. Tmux session scripts ──────────────────────────────────────────────
#
# The scripts under bin/tmux-sessions/ are project-session launchers (one per
# project). They get installed (copied, not symlinked, since we want them on
# PATH without exposing the whole bin/ subdirectory) into ~/.local/bin/ with
# the .sh extension stripped — so `tmux-finlib.sh` becomes `tmux-finlib` on
# the PATH. `install -m 0755` is idempotent and handles the chmod in one shot.

log "Installing tmux session scripts"
run mkdir -p "$HOME/.local/bin"
for f in "$REPO_ROOT"/bin/tmux-sessions/*.sh; do
  [[ -f "$f" ]] || continue
  dest="$HOME/.local/bin/$(basename "$f" .sh)"
  run install -m 0755 "$f" "$dest"
done
ok "tmux session scripts installed to ~/.local/bin/"

# ── 10. Shell wiring: source mkvenv from ~/.bashrc ───────────────────────

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

# ── 11. Omarchy themes ────────────────────────────────────────────────────

log "Installing Omarchy themes"
run "$REPO_ROOT/bin/install-themes.sh"

# ── 12. Omarchy theme hooks (imbypass/omarchy-theme-hook) ─────────────────
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

# ── 13. Omarchy webapps ───────────────────────────────────────────────────

log "Installing Omarchy webapps"
run "$REPO_ROOT/bin/install-webapps.sh"

# ── 14. Nightlight automation ─────────────────────────────────────────────

log "Installing nightlight automation"
run "$REPO_ROOT/nightlight/install-nightlight.sh"

# ── 15. Default browser: Google Chrome ────────────────────────────────────

log "Setting Google Chrome as default browser"
if (( DRY_RUN )); then
  dry "xdg-settings set default-web-browser google-chrome.desktop"
elif [[ -f /usr/share/applications/google-chrome.desktop ]]; then
  xdg-settings set default-web-browser google-chrome.desktop
  ok "default browser: $(xdg-settings get default-web-browser)"
else
  warn "google-chrome.desktop not found — skipping (did the AUR install fail?)"
fi

# ── 16. Clone personal projects + vault (needs SSH key) ─────────────────

log "Cloning personal project repos and Obsidian vault"
run "$REPO_ROOT/bin/clone-projects.sh"

# ── 17. Restart waybar so it picks up the new config/theme ───────────────
#
# Waybar auto-reloads on style.css changes (reload_style_on_change: true)
# but NOT on config.jsonc changes, and it's been running throughout this
# script with a stale config + theme. Without this kick, workspace numbers
# and a few other modules render incorrectly until the next login. Using
# the Omarchy wrapper so we stay on the distro's blessed restart path; if
# it's missing we fall back to a manual pkill + relaunch.

log "Restarting waybar to pick up new config and theme"
if command -v omarchy-restart-waybar >/dev/null 2>&1; then
  run omarchy-restart-waybar
elif pgrep -x waybar >/dev/null 2>&1; then
  run bash -c 'pkill -x waybar 2>/dev/null; sleep 0.3; waybar >/dev/null 2>&1 &'
  ok "waybar restarted (manual fallback)"
else
  ok "waybar not running — will start via hypr autostart on next session"
fi

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
