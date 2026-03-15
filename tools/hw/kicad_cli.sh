#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   tools/hw/kicad_cli.sh <args...>
# Picks local kicad-cli if present, otherwise uses docker image.
#
# Env:
#   KICAD_CLI_BIN: override local path
#   KICAD_DOCKER_IMAGE: override docker image (default: kicad/kicad:nightly)

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/runtime_home.sh"

BIN="${KICAD_CLI_BIN:-}"
if [[ -z "$BIN" ]]; then
  if command -v kicad-cli >/dev/null 2>&1; then
    BIN="kicad-cli"
  elif [[ -x "/Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli" ]]; then
    BIN="/Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli"
  fi
fi

if [[ -n "$BIN" ]]; then
  exec "$BIN" "$@"
fi

# docker fallback
if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: kicad-cli not found and docker not available." >&2
  exit 127
fi

IMG="${KICAD_DOCKER_IMAGE:-kicad/kicad:nightly}"

# run as current user to avoid root-owned artifacts
UIDGID="$(id -u):$(id -g)"
WORKDIR="$(pwd)"
kill_life_runtime_home_init "$WORKDIR" "kicad-cli" "$WORKDIR/.cad-home"
kill_life_runtime_home_ensure

exec docker run --rm \
  -u "$UIDGID" \
  -v "$WORKDIR:$WORKDIR" \
  -w "$WORKDIR" \
  -e HOME="$HOME" \
  -e XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
  -e XDG_CACHE_HOME="$XDG_CACHE_HOME" \
  "$IMG" \
  sh -lc 'set -e; mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"; exec kicad-cli "$@"' sh "$@"
