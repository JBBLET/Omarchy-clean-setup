# mkvenv — create and activate a Python venv seeded with a preset requirements file.
#
# Usage:
#   mkvenv <name> [preset]
#     name   venv directory name (created under ~/.venvs/<name>)
#     preset requirements preset (default: pybase) — resolved to ~/.venvs/<preset>-requirements.txt
#
# Presets live in this repo under venv-presets/ and are symlinked into ~/.venvs/ by the bootstrap.
# Add a new preset by dropping a <name>-requirements.txt file into venv-presets/.

mkvenv() {
  local name="$1"
  local preset="${2:-pybase}"
  local venv_dir="$HOME/.venvs/$name"
  local req_file="$HOME/.venvs/${preset}-requirements.txt"

  if [[ -z "$name" ]]; then
    echo "usage: mkvenv <name> [preset]" >&2
    return 1
  fi

  if [[ -e "$venv_dir" ]]; then
    echo "mkvenv: $venv_dir already exists" >&2
    return 1
  fi

  if [[ ! -f "$req_file" ]]; then
    echo "mkvenv: preset not found: $req_file" >&2
    echo "  available presets:" >&2
    ls "$HOME/.venvs/"*-requirements.txt 2>/dev/null | sed 's|.*/||; s|-requirements\.txt$||; s|^|    |' >&2
    return 1
  fi

  python -m venv "$venv_dir" || return 1
  # shellcheck disable=SC1091
  source "$venv_dir/bin/activate" || return 1
  pip install --upgrade pip
  pip install -r "$req_file"
  echo "mkvenv: $venv_dir ready (preset: $preset)"
}
