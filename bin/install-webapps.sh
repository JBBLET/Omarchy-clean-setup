#!/bin/bash
# Install Omarchy webapps from packages/webapps.txt.
# Format: Name | URL   (comments start with #, blank lines ignored)
# Icons are fetched automatically from Google's favicon service.
#
# Safe to re-run: omarchy-webapp-install overwrites .desktop files on each call.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$REPO_ROOT/packages/webapps.txt"

command -v omarchy-webapp-install >/dev/null 2>&1 || {
  echo "omarchy-webapp-install not found — this script must run on Omarchy" >&2
  exit 1
}
[[ -f "$MANIFEST" ]] || { echo "manifest not found: $MANIFEST" >&2; exit 1; }

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

echo "Installing Omarchy webapps..."
while IFS='|' read -r name url _rest; do
  name="$(trim "$name")"
  url="$(trim "$url")"
  [[ -z "$name" || "$name" =~ ^# ]] && continue
  [[ -z "$url" ]] && { echo "  skipping '$name' (no url)"; continue; }

  echo "  $name -> $url"
  # Third arg empty -> omarchy-webapp-install falls back to Google's favicon.
  omarchy-webapp-install "$name" "$url" ""
done < "$MANIFEST"

echo "Done. Webapps available via the app launcher (Super + Space)."
