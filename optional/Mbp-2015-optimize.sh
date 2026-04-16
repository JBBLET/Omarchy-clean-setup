#!/bin/bash
# MacBook Pro 2015 performance optimiser for Omarchy.
#
# Installs and configures:
#   - mbpfan      : fan control tuned for the MBP 2015 thermals
#   - thermald    : Intel thermal management daemon
#   - zram        : compressed swap in RAM (reduces I/O on the ageing SSD/HDD)
#   - power-profiles-daemon : balanced/power-saver/performance profiles via UI or CLI
#
# Safe to re-run: package installs use --needed, config files are only written
# when missing (pass --force to overwrite), services are enabled idempotently.
#
# Usage:
#   cd ~/Omarchy-clean-setup/optional && ./Mbp-2015-optimize.sh [--force]
#
# Prerequisites:
#   - Omarchy install (Arch + Hyprland)
#   - yay or omarchy-pkg-aur-add available (for mbpfan AUR package)

set -euo pipefail

FORCE=0
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    -h|--help)
      sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) printf 'unknown argument: %s\n' "$arg" >&2; exit 2 ;;
  esac
done

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()   { printf '    \033[1;32mok\033[0m %s\n' "$*"; }
warn() { printf '    \033[1;33m!\033[0m %s\n' "$*" >&2; }

[[ $EUID -ne 0 ]] || { echo "Do not run as root — the script uses sudo internally." >&2; exit 1; }
command -v pacman >/dev/null 2>&1 || { echo "pacman not found — Arch/Omarchy only." >&2; exit 1; }

log "Caching sudo credentials"
sudo -v

# ── 1. Pacman packages ────────────────────────────────────────────────────────

log "Installing pacman packages"
sudo pacman -S --needed --noconfirm thermald zram-generator zstd power-profiles-daemon
ok "pacman packages ready"

# ── 2. AUR: mbpfan ────────────────────────────────────────────────────────────

log "Installing mbpfan (AUR)"
if pacman -Q mbpfan &>/dev/null; then
  ok "mbpfan already installed"
elif command -v omarchy-pkg-aur-add >/dev/null 2>&1; then
  omarchy-pkg-aur-add mbpfan
elif command -v yay >/dev/null 2>&1; then
  yay -S --needed --noconfirm mbpfan
else
  warn "Neither omarchy-pkg-aur-add nor yay found — install mbpfan manually, then re-run."
  exit 1
fi

# ── 3. mbpfan config ─────────────────────────────────────────────────────────
#
# Tuned for the MBP 2015 (dual-core Intel Broadwell, single fan at 2000–6200 RPM).
# Increase low_temp/high_temp if the fan feels too aggressive at idle.

log "Configuring mbpfan"
MBPFAN_CONF=/etc/mbpfan.conf
if [[ -f "$MBPFAN_CONF" && $FORCE -eq 0 ]]; then
  ok "$MBPFAN_CONF already exists — skipping (pass --force to overwrite)"
else
  sudo tee "$MBPFAN_CONF" > /dev/null <<'EOF'
[general]
# MBP 2015 — single fan, Broadwell CPU
min_fan1_speed = 2000
max_fan1_speed = 6200

# Celsius thresholds: fan starts ramping at low_temp, reaches max at high_temp.
# Shut down if temperature exceeds max_temp.
low_temp          = 63
high_temp         = 66
max_temp          = 86
polling_interval  = 7
EOF
  ok "$MBPFAN_CONF written"
fi
sudo systemctl enable --now mbpfan
ok "mbpfan enabled"

# ── 4. thermald ───────────────────────────────────────────────────────────────

log "Enabling thermald"
sudo systemctl enable --now thermald
ok "thermald enabled"

# ── 5. zram ───────────────────────────────────────────────────────────────────
#
# Allocates half of physical RAM as a zstd-compressed swap device.
# Reduces writes to the internal SSD/HDD and keeps the system responsive
# under memory pressure (e.g. running a JVM + browser simultaneously).

log "Configuring zram"
ZRAM_CONF=/etc/systemd/zram-generator.conf
if [[ -f "$ZRAM_CONF" && $FORCE -eq 0 ]]; then
  ok "$ZRAM_CONF already exists — skipping (pass --force to overwrite)"
else
  sudo tee "$ZRAM_CONF" > /dev/null <<'EOF'
[zram0]
zram-size             = ram / 2
compression-algorithm = zstd
EOF
  ok "$ZRAM_CONF written"
fi
sudo systemctl daemon-reload
# zram0 is a generated device — start it only if the unit exists after daemon-reload
if systemctl list-units --full --all | grep -q 'dev-zram0.swap'; then
  sudo systemctl start dev-zram0.swap 2>/dev/null || true
  ok "zram0 swap active"
else
  ok "zram0 will activate on next boot"
fi

# ── 6. power-profiles-daemon ──────────────────────────────────────────────────
#
# Provides balanced / power-saver / performance profiles toggled via
# `powerprofilesctl set <profile>` or the Waybar power-profiles module.
# Turbo boost is managed automatically per profile — no manual no_turbo tweak needed.

log "Enabling power-profiles-daemon"
sudo systemctl enable --now power-profiles-daemon
powerprofilesctl set balanced
ok "power-profiles-daemon enabled — current profile: $(powerprofilesctl get)"

# ── done ──────────────────────────────────────────────────────────────────────

cat <<'EOF'

============================================================
  MBP 2015 optimisation complete.
============================================================

Switch power profiles:
  powerprofilesctl set power-saver    # battery / quiet
  powerprofilesctl set balanced       # default
  powerprofilesctl set performance    # plugged in / heavy workload

Check fan activity:
  sudo mbpfan -t   # print current temps and fan speed

Check zram:
  zramctl          # shows compressed swap usage
  swapon --show    # verify /dev/zram0 is active

Tune fan thresholds:
  sudo $EDITOR /etc/mbpfan.conf
  sudo systemctl restart mbpfan

EOF
