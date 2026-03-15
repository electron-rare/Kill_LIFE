#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPO_PARENT="$(cd "$ROOT_DIR/.." && pwd)"
IMAGE="${KICAD_MCP_IMAGE:-kill_life_cad-kicad-mcp:latest}"
DEST="${KICAD_AUX_CONTAINER_CACHE_DIR:-$HOME/Kill_LIFE/.cad-home/kicad-mcp/kicad-v10-libs}"
MASCARADE_DIR="${MASCARADE_DIR:-$REPO_PARENT/mascarade}"
INDEX_BUILDER="$MASCARADE_DIR/finetune/kicad_kic_ai/build_kicad_v10_indexes.py"
REFRESH=0
VERBOSE=0

usage() {
  cat <<'EOF'
Usage: tools/hw/sync_kicad_v10_libs.sh [--refresh] [--verbose]

Export KiCad v10 symbol and footprint libraries from the KiCad MCP container image
into a local cache directory used by the auxiliary MCP servers.

Options:
  --refresh   Rebuild the local cache even if it already exists
  --verbose   Print executed Docker operations
  -h, --help  Show this help

Environment:
  KICAD_MCP_IMAGE              Container image to inspect
  KICAD_AUX_CONTAINER_CACHE_DIR Destination cache directory
  MASCARADE_DIR                Companion repo used to prebuild indexes
EOF
}

log() {
  printf '[kill_life:kicad-v10-libs] %s\n' "$*" >&2
}

die() {
  printf '[kill_life:kicad-v10-libs][err] %s\n' "$*" >&2
  exit 1
}

run_cmd() {
  if [ "$VERBOSE" -eq 1 ]; then
    log "run: $*"
  fi
  "$@"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --refresh)
      REFRESH=1
      shift
      ;;
    --verbose)
      VERBOSE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

command -v docker >/dev/null 2>&1 || die "docker is required"
run_cmd docker image inspect "$IMAGE" >/dev/null 2>&1 || die "image not found: $IMAGE"

DEST="$(python3 - <<'PY' "$DEST"
import os
import sys
print(os.path.abspath(os.path.expanduser(sys.argv[1])))
PY
)"

SYMBOLS_DIR="$DEST/symbols"
FOOTPRINTS_DIR="$DEST/footprints"
SYMBOL_INDEX_FILE="$DEST/.symbol_index.sqlite3"
FOOTPRINT_INDEX_FILE="$DEST/.footprint_index.json"

if [ "$REFRESH" -eq 0 ] && [ -d "$SYMBOLS_DIR" ] && [ -d "$FOOTPRINTS_DIR" ]; then
  if [ -f "$SYMBOL_INDEX_FILE" ] && [ -f "$FOOTPRINT_INDEX_FILE" ]; then
    log "cache already present at $DEST"
    exit 0
  fi
  if [ -f "$INDEX_BUILDER" ]; then
    log "library cache present at $DEST; prewarming missing indexes"
    run_cmd env \
      KICAD_AUX_CONTAINER_CACHE_DIR="$DEST" \
      python3 "$INDEX_BUILDER" >/dev/null
  else
    log "library cache present at $DEST but index builder not found at $INDEX_BUILDER"
  fi
  exit 0
fi

STAGE_DIR="$(mktemp -d "${DEST%/*}/.kicad-v10-libs.stage.XXXXXX")"
CONTAINER_ID=""
BACKUP_DIR=""
cleanup() {
  if [ -n "$CONTAINER_ID" ]; then
    docker rm -f "$CONTAINER_ID" >/dev/null 2>&1 || true
  fi
  if [ -n "$STAGE_DIR" ] && [ -d "$STAGE_DIR" ]; then
    rm -rf "$STAGE_DIR"
  fi
  if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
    rm -rf "$BACKUP_DIR"
  fi
}
trap cleanup EXIT INT TERM

mkdir -p "$STAGE_DIR"
CONTAINER_ID="$(docker create "$IMAGE")"
run_cmd docker cp "$CONTAINER_ID:/usr/share/kicad/symbols" "$STAGE_DIR"
run_cmd docker cp "$CONTAINER_ID:/usr/share/kicad/footprints" "$STAGE_DIR"

if [ -f "$INDEX_BUILDER" ]; then
  log "prewarming KiCad v10 indexes"
  run_cmd env \
    KICAD_AUX_CONTAINER_CACHE_DIR="$STAGE_DIR" \
    python3 "$INDEX_BUILDER" --refresh >/dev/null
else
  log "index builder not found at $INDEX_BUILDER; skipping prewarm"
fi

mkdir -p "$(dirname "$DEST")"
if [ -e "$DEST" ]; then
  BACKUP_DIR="$(mktemp -d "${DEST%/*}/.kicad-v10-libs.backup.XXXXXX")"
  rmdir "$BACKUP_DIR"
  mv "$DEST" "$BACKUP_DIR"
fi
mv "$STAGE_DIR" "$DEST"
STAGE_DIR=""
if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
  rm -rf "$BACKUP_DIR"
  BACKUP_DIR=""
fi

trap - EXIT INT TERM
cleanup
log "synced KiCad v10 libraries to $DEST"
