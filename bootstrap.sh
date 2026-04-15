#!/bin/bash
# Omarchy-clean-setup bootstrap — run on a fresh Omarchy install.
#
# This is the chicken-and-egg entry point: it gets you from "just installed
# Omarchy" to "install.sh is running", handling SSH key generation, GitHub
# authentication, and the initial clone of this repo.
#
# USAGE
#
#   # Quick (one paste):
#   bash <(curl -fsSL https://raw.githubusercontent.com/JBBLET/Omarchy-clean-setup/main/bootstrap.sh)
#
#   # Cautious (recommended the first time):
#   curl -fsSL https://raw.githubusercontent.com/JBBLET/Omarchy-clean-setup/main/bootstrap.sh -o /tmp/bootstrap.sh
#   less /tmp/bootstrap.sh
#   bash /tmp/bootstrap.sh
#
# WHAT IT DOES
#
#   1. Pre-flight (not root, Omarchy detected, network up).
#   2. Generate ~/.ssh/id_ed25519 if absent.
#   3. Authenticate gh CLI to GitHub (opens browser — interactive).
#   4. Upload the SSH public key to GitHub (idempotent by title).
#   5. Verify SSH to github.com.
#   6. Prompt for git user.name / user.email if not configured.
#   7. Clone the repo to ~/Omarchy-clean-setup (with GIT_LFS_SKIP_SMUDGE=1
#      so it doesn't fail before install.sh installs git-lfs).
#   8. Hand off to ./install.sh.

set -euo pipefail

REPO_URL="git@github.com:JBBLET/Omarchy-clean-setup.git"
REPO_DIR="$HOME/Omarchy-clean-setup"

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()   { printf '    \033[1;32mok\033[0m %s\n' "$*"; }
warn() { printf '    \033[1;33m!\033[0m %s\n' "$*" >&2; }
die()  { printf '\n\033[1;31mFAIL:\033[0m %s\n' "$*" >&2; exit 1; }

# ── pre-flight ────────────────────────────────────────────────────────────

[[ $EUID -ne 0 ]] || die "do not run bootstrap as root"
command -v omarchy-version >/dev/null 2>&1 || die "this script expects an Omarchy install (omarchy-version not found)"
command -v gh               >/dev/null 2>&1 || die "gh CLI not found — it should be in omarchy-base.packages"
command -v git              >/dev/null 2>&1 || die "git not found"
curl -fsS --max-time 5 https://api.github.com >/dev/null || die "no network to api.github.com"

log "Omarchy detected: $(omarchy-version 2>/dev/null || echo '?')"

# ── 1. SSH key ────────────────────────────────────────────────────────────

SSH_KEY="$HOME/.ssh/id_ed25519"
SSH_PUB="$SSH_KEY.pub"

log "Checking SSH key at $SSH_KEY"
if [[ -f "$SSH_KEY" && -f "$SSH_PUB" ]]; then
  ok "SSH key already exists, reusing it"
else
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  ssh-keygen -t ed25519 -C "$(hostname) $(date +%F)" -f "$SSH_KEY" -N ""
  ok "generated new ed25519 key"
fi

# Start ssh-agent and add the key so `git clone` over SSH works in this shell.
if [[ -z "${SSH_AUTH_SOCK:-}" ]] || ! ssh-add -l >/dev/null 2>&1; then
  eval "$(ssh-agent -s)" >/dev/null
fi
ssh-add "$SSH_KEY" 2>/dev/null || true

# ── 2. gh CLI auth ────────────────────────────────────────────────────────

log "Checking GitHub auth via gh"
if gh auth status >/dev/null 2>&1; then
  ok "gh already authenticated as $(gh api user -q .login 2>/dev/null || echo '?')"
else
  echo "    A browser window will open and gh will print a one-time code."
  echo "    Paste the code into the browser to authorize."
  gh auth login --hostname github.com --git-protocol ssh --web
fi

# ── 3. Upload SSH public key (idempotent) ─────────────────────────────────

log "Ensuring SSH key is on GitHub"
KEY_TITLE="$(hostname)-$(date +%F)"
if gh ssh-key list --json title -q '.[].title' 2>/dev/null | grep -Fxq "$KEY_TITLE"; then
  ok "key titled '$KEY_TITLE' already on GitHub"
elif gh ssh-key list --json key -q '.[].key' 2>/dev/null | grep -Fq "$(cut -d' ' -f2 "$SSH_PUB")"; then
  ok "this public key is already registered on GitHub under a different title"
else
  gh ssh-key add "$SSH_PUB" --title "$KEY_TITLE"
  ok "uploaded key '$KEY_TITLE'"
fi

# ── 4. Verify SSH to GitHub ───────────────────────────────────────────────

log "Verifying SSH to github.com"
# github's ssh -T always exits 1 (no shell access), even on successful auth,
# so we ignore the exit code and match on the output string. Captured into a
# variable so `set -o pipefail` doesn't misinterpret ssh's exit 1 as a failure
# of the pipeline. Retry a few times because a freshly-uploaded key can take
# a second or two to propagate on GitHub's side.
SSH_OK=0
for attempt in 1 2 3 4 5; do
  SSH_OUT="$(ssh -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 || true)"
  if grep -q 'successfully authenticated' <<<"$SSH_OUT"; then
    SSH_OK=1
    break
  fi
  warn "ssh verify attempt $attempt failed, retrying in 2s..."
  sleep 2
done
if (( SSH_OK )); then
  ok "ssh -T git@github.com works"
else
  printf '%s\n' "$SSH_OUT" >&2
  die "SSH to github.com failed — check 'ssh -vT git@github.com' manually"
fi

# ── 5. Git identity ───────────────────────────────────────────────────────

log "Checking git identity"
GIT_NAME="$(git config --global user.name  || true)"
GIT_EMAIL="$(git config --global user.email || true)"
if [[ -z "$GIT_NAME" ]]; then
  read -r -p "    git user.name  : " GIT_NAME
  git config --global user.name  "$GIT_NAME"
fi
if [[ -z "$GIT_EMAIL" ]]; then
  read -r -p "    git user.email : " GIT_EMAIL
  git config --global user.email "$GIT_EMAIL"
fi
ok "git identity: $GIT_NAME <$GIT_EMAIL>"

# ── 6. Clone the repo ─────────────────────────────────────────────────────

log "Cloning $REPO_URL"
if [[ -d "$REPO_DIR/.git" ]]; then
  ok "$REPO_DIR already a git checkout, skipping clone"
else
  if [[ -e "$REPO_DIR" ]]; then
    die "$REPO_DIR exists but is not a git checkout — move it aside first"
  fi
  # Skip LFS smudge: git-lfs isn't installed yet, install.sh phase 1 handles
  # the install + lfs pull.
  GIT_LFS_SKIP_SMUDGE=1 git clone "$REPO_URL" "$REPO_DIR"
  ok "cloned to $REPO_DIR"
fi

# ── 7. Hand off to install.sh ─────────────────────────────────────────────

log "Handing off to install.sh"
cd "$REPO_DIR"
exec ./install.sh "$@"
