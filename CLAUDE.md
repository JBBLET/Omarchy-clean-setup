# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

Personal dotfiles and bootstrap scripts for provisioning a laptop with [Omarchy](https://omarchy.org) (Hyprland-based Arch setup). The goal: wipe/fresh-install, clone this repo, run one script, end up with a fully configured machine — no manual post-install steps.

Target workflow: `git clone` → `./install.sh` (or equivalent entrypoint) → done.

## Architecture (intended)

The repo is currently empty and being built from scratch. Expected shape:

- **Bootstrap script** — top-level entrypoint that orchestrates the full setup. Should be idempotent (safe to re-run) and fail loudly rather than silently skipping steps.
- **Dotfiles** — configs for Hyprland, Waybar, Walker, terminal, etc. Typically live under a `config/` or `dotfiles/` directory and are symlinked into `~/.config/` by the bootstrap script (don't copy — symlink, so edits flow back to the repo).
- **Package lists** — pacman/AUR/flatpak package manifests, installed by the bootstrap script.
- **Post-install hooks** — anything that must run after packages + symlinks (enabling services, setting defaults, etc.).

When adding structure, keep the layout flat and obvious. A new contributor (or future Claude) should understand the repo from `ls` alone.

## Working with this repo

- The user runs Omarchy on Arch Linux with Hyprland. Assume that environment.
- For edits to files under `~/.config/hypr/`, `~/.config/waybar/`, `~/.config/walker/`, terminals, etc., use the `omarchy` skill — it has the conventions and pitfalls for Omarchy-specific config.
- Omarchy itself lives in `~/.local/share/omarchy/` on the user's machine. This repo is **not** a fork of Omarchy — it's user customization layered on top. Don't edit Omarchy source from here.
- Prefer symlink-based dotfile management over copy-based. The repo should be the source of truth once set up.
- Bootstrap scripts must be safe to re-run on an already-configured machine (idempotent).
