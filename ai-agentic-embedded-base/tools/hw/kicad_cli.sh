#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   tools/hw/kicad_cli.sh <args...>
# Picks local kicad-cli if present, otherwise uses docker image.
#
# Env:
#   KICAD_CLI_BIN: override local path
#   KICAD_DOCKER_IMAGE: override docker image (default: kicad/kicad:9.0.7-full)

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

IMG="${KICAD_DOCKER_IMAGE:-kicad/kicad:9.0.7-full}"

# run as current user to avoid root-owned artifacts
UIDGID="$(id -u):$(id -g)"
WORKDIR="$(pwd)"

exec docker run --rm   -u "$UIDGID"   -v "$WORKDIR:$WORKDIR"   -w "$WORKDIR"   "$IMG"   kicad-cli "$@"
