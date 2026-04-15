# Omarchy-clean-setup

Personal dotfiles and bootstrap scripts for provisioning a laptop running
[Omarchy](https://omarchy.org) (Hyprland-based Arch).

Goal: **fresh install → one paste → fully configured machine**, no manual
post-install steps beyond a handful of hardware-specific items (monitors,
NVIDIA env vars).

## TL;DR

On a freshly installed Omarchy machine, open a terminal and paste:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/JBBLET/Omarchy-clean-setup/main/bootstrap.sh)
```

That's it. Walk through the two interactive prompts (GitHub device-code in
the browser, git user.name / user.email if not already set), then let
`install.sh` run to completion. Log out and back in when it's done.

## What actually happens

The two entry points split the work cleanly:

### `bootstrap.sh` — gets you to a working clone

Run on a machine that has nothing yet. Handles the chicken-and-egg of
"how do I clone a private repo before I have SSH set up".

1. Pre-flight: refuse root, check this is actually Omarchy, network reachable.
2. Generate `~/.ssh/id_ed25519` (no passphrase — we're on a fresh box).
3. `gh auth login --web` — opens a browser with a device code.
4. Upload the new public key to GitHub (idempotent by title + by key content).
5. Verify `ssh -T git@github.com`.
6. Prompt for `git config --global user.name / user.email` if missing.
7. `GIT_LFS_SKIP_SMUDGE=1 git clone` the repo to `~/Omarchy-clean-setup`
   (LFS smudge is skipped here because git-lfs isn't installed yet —
   phase 1 of `install.sh` installs it and does the pull).
8. `exec ./install.sh "$@"` — hands off without leaving a second shell.

### `install.sh` — the 14-phase bring-up

Safe to re-run on an already-configured machine. Every step is idempotent
(`--needed` pacman, `ln -sfn`, grep-before-append, `[[ -d .git ]]` skip-checks).

| # | Phase | Notes |
|---|---|---|
| 1 | `git-lfs install` + `git lfs pull` | Pulls theme background images |
| 2 | `bin/setup-user-dirs.sh` | Relocates XDG user dirs under `~/user/` — must run before any app writes into `$HOME` |
| 3 | Pacman packages (`packages/pacman.txt`) | Via `omarchy-pkg-add`, falls back to raw pacman |
| 4 | Dev runtimes via mise | `omarchy-install-dev-env python` + `mise use -g java@temurin-17` |
| 5 | AUR packages (`packages/aur.txt`) | Via `omarchy-pkg-aur-add`; currently just `google-chrome` |
| 6 | Dotfile symlinks | Hypr file-by-file, nvim whole-dir, venv presets |
| 7 | Japanese input method | fcitx5 profile + config symlinks (packages from phase 3, env vars baked into `config/hypr/envs.conf`) |
| 8 | Shell wiring | Sources `shell/mkvenv.sh` from `~/.bashrc` |
| 9 | Omarchy themes | `bin/install-themes.sh` clones upstream themes and overlays custom backgrounds |
| 10 | Theme hooks | `theme-hook-update` — installs [imbypass/omarchy-theme-hook](https://github.com/imbypass/omarchy-theme-hook) |
| 11 | Omarchy webapps | `bin/install-webapps.sh` — needs Chrome from phase 5 |
| 12 | Nightlight automation | `nightlight/install-nightlight.sh` |
| 13 | Default browser | `xdg-settings set default-web-browser google-chrome.desktop` |
| 14 | Clone projects + vault | `bin/clone-projects.sh` — LAST because it needs the SSH key |

### Dry-run

`./install.sh --dry-run` prints every mutating command without executing it.
Read-only checks still run so you can see which branches the script would
take on your actual machine. Sub-installers are announced but not recursively
dry-run.

## Design rules

- **Defer to Omarchy.** Omarchy's `omarchy-base.packages` and
  `omarchy-other.packages` already ship docker (with full daemon config),
  tmux, lazygit, lazydocker, neovim, ripgrep, fd, tree-sitter-cli,
  libreoffice-fresh, obsidian, spotify, claude-code, fcitx5, mise, and
  many more. **Do not re-list any of these in `packages/pacman.txt` or
  `aur.txt`** — it fights the distro. Always check Omarchy's package lists
  before adding something.
- **Languages go through `mise`, not pacman.** Omarchy's philosophy is
  polyglot runtime management via mise. Hard-coding `JAVA_HOME` in
  `envs.conf` or shell rc would override mise and break per-project
  version switching — don't do it.
- **Symlinks, not copies.** The repo is the source of truth. Edits in
  `~/.config/hypr/` flow back to the repo automatically because those
  files are symlinks.
- **Hypr configs are symlinked file-by-file**, not whole-directory, so
  Omarchy's own hardware files (`monitors.conf`, anything in
  `~/.config/hypr/` that Omarchy ships) coexist with our customization.
- **Hardware-bound configs stay out of the repo.** `monitors.conf`,
  `input.conf`, and the NVIDIA env block are machine-specific and must
  be recreated manually on the new laptop (see phase 1–2 of the
  post-install checklist below).
- **Idempotent everything.** `--needed`, `ln -sfn`, grep-before-append.

## Post-install checklist

After `install.sh` prints "Bootstrap complete":

1. **Create `~/.config/hypr/monitors.conf`** for this laptop's displays
   (the repo intentionally does not track it — run `hyprctl monitors`
   to see what's attached).
2. **If NVIDIA**, add the NVIDIA env vars back to
   `~/.config/hypr/hyprland.conf` (stripped from the snapshot).
3. **Log out and back in** (or Super+Esc → Relaunch) so the new XDG user
   dirs, default browser, fcitx5/Mozc, and shell wiring take effect.
4. **Open `nvim` once** to let LazyVim sync plugins from `lazy-lock.json`,
   then `:Mason` to install language servers.
5. **Sign in to Spotify and Chrome.**
6. **`claude`** in a terminal to authenticate Claude Code (Omarchy ships
   `claude-code` natively — no npm install needed).
7. **Verify mise runtimes:** `mise ls` should show python + java@temurin-17.
   For other languages: `omarchy-install-dev-env <node|ruby|go|rust|...>`.
8. **If `bin/clone-projects.sh` was skipped** (no SSH key yet), re-run it
   after fixing SSH: `./bin/clone-projects.sh`.

## Re-running on a partially-configured machine

`install.sh` is designed to be safe to re-run, but be aware:

- 🟢 Package phases, mise runtimes, nvim symlink, venv presets, mkvenv
  wiring, themes, theme hooks, webapps, nightlight, default browser —
  all fully idempotent.
- 🟡 Hypr and fcitx5 symlinks replace existing files **without backing
  them up**. If you manually customized `~/.config/hypr/bindings.conf`
  on a target machine, move it aside before running.
- 🟡 Phase 2 (XDG user dirs) moves `~/Documents`, `~/Downloads`, etc.
  under `~/user/`. If the machine already has files in the old
  locations, they'll be moved. Check `bin/setup-user-dirs.sh` first.

## Layout

```
.
├── bootstrap.sh          # Fresh-machine entry point (SSH + clone + handoff)
├── install.sh            # 14-phase orchestrator, idempotent, --dry-run
├── bin/                  # Sub-installers (setup-user-dirs, install-themes,
│                         #   install-webapps, clone-projects)
├── config/
│   ├── hypr/             # hyprland.conf, bindings.conf, looknfeel.conf, ...
│   ├── nvim/             # Whole LazyVim config (owned by this repo)
│   ├── fcitx5/           # Mozc-default profile + Ctrl+Space toggle
│   └── omarchy-themes/   # Custom theme backgrounds (git-lfs tracked)
├── nightlight/           # Systemd units + installer for hyprsunset automation
├── packages/
│   ├── pacman.txt        # Only what Omarchy doesn't already ship
│   └── aur.txt           # Currently just google-chrome
├── shell/
│   └── mkvenv.sh         # `mkvenv <name>` helper, sourced from ~/.bashrc
└── venv-presets/         # Requirements files symlinked into ~/.venvs/
```
