# uvinit — initialise a new uv project seeded with a preset requirements file.
#
# Usage:
#   uvinit [preset]
#     preset   requirements preset (default: pybase) — resolved to ~/.venvs/<preset>-requirements.txt
#
# Presets live in this repo under venv-presets/ and are symlinked into ~/.venvs/ by install.sh.
# Add a new preset by dropping a <name>-requirements.txt file into venv-presets/.

uvinit() {
  local preset="${1:-pybase}"
  local req_file="$HOME/.venvs/${preset}-requirements.txt"

  if ! command -v uv >/dev/null 2>&1; then
    echo "uvinit: uv not found — install it first" >&2
    return 1
  fi

  if [[ ! -f "$req_file" ]]; then
    echo "uvinit: preset not found: $req_file" >&2
    echo "  available presets:" >&2
    ls "$HOME/.venvs/"*-requirements.txt 2>/dev/null | sed 's|.*/||; s|-requirements\.txt$||; s|^|    |' >&2
    return 1
  fi

  uv init || return 1
  uv add -r "$req_file"
  echo "uvinit: project ready (preset: $preset)"
}
