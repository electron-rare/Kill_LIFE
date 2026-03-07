#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMPOSE_FILE="$ROOT_DIR/deploy/cad/docker-compose.yml"
VERBOSE=0
DOCTOR=0
RUNTIME="${KICAD_MCP_RUNTIME:-auto}"
FORCE_BUILD=0
REQUESTED_RUNTIME="$RUNTIME"

usage() {
  cat <<'EOF'
Usage: tools/hw/run_kicad_mcp.sh [--doctor] [--verbose] [--debug] [--rebuild] [-- <server args>]

Launch the supported KiCad MCP server from the companion `mascarade` repo.

Options:
  --doctor    Print resolved paths and exit
  --verbose   Print resolved command before exec
  --debug     Enable verbose launcher + server logs
  --rebuild   Force a rebuild of the container image before launch
  -h, --help  Show this help

Environment:
  MASCARADE_DIR        Override the companion repo path (default: ../mascarade)
  KICAD_MCP_ENTRYPOINT Override the Node entrypoint
  KICAD_MCP_HOME       Override the MCP runtime home (default: .cad-home/kicad-mcp)
  NODE_BIN             Override the Node executable (default: node)
  KICAD_MCP_DATA_DIR   Override the writable data directory used by the server
  KICAD_MCP_RUNTIME    host | container | auto (default: auto)
  KICAD_MCP_LOG_LEVEL  error | warn | info | debug (default: warn)
EOF
}

log() {
  printf '[kill_life:mcp] %s\n' "$*" >&2
}

debug() {
  if [ "$VERBOSE" -eq 1 ]; then
    log "$*"
  fi
}

cleanup_container() {
  if [ -n "${ACTIVE_CONTAINER_NAME:-}" ]; then
    docker rm -f "$ACTIVE_CONTAINER_NAME" >/dev/null 2>&1 || true
  fi
}

die() {
  printf '[kill_life:mcp][err] %s\n' "$*" >&2
  exit 1
}

compose() {
  docker compose -f "$COMPOSE_FILE" "$@"
}

build_pythonpath() {
  local -a candidates=()
  local value=""

  if [ -n "${KICAD_PYTHONPATH:-}" ]; then
    value="${KICAD_PYTHONPATH}"
  elif [ -n "${PYTHONPATH:-}" ]; then
    value="${PYTHONPATH}"
  else
    candidates=(
      /usr/lib/kicad/lib/python3/dist-packages
      /usr/local/lib/kicad/lib/python3/dist-packages
      /usr/lib/python3/dist-packages
      /usr/local/lib/python3/dist-packages
      /usr/lib/python3.12/dist-packages
      /usr/local/lib/python3.12/dist-packages
    )
    for candidate in "${candidates[@]}"; do
      if [ -d "$candidate" ]; then
        if [ -n "$value" ]; then
          value="${value}:$candidate"
        else
          value="$candidate"
        fi
      fi
    done
  fi

  printf '%s' "$value"
}

resolve_probe_python() {
  if [ -n "${KICAD_PYTHON:-}" ]; then
    printf '%s' "$KICAD_PYTHON"
    return 0
  fi

  if [ -x "$SERVER_DIR/venv/bin/python" ]; then
    printf '%s' "$SERVER_DIR/venv/bin/python"
    return 0
  fi

  command -v python3 || true
}

probe_pcbnew() {
  local probe_python="$1"
  local pythonpath="$2"

  [ -n "$probe_python" ] || return 1

  if [ -n "$pythonpath" ]; then
    env PYTHONPATH="$pythonpath" "$probe_python" -c 'import pcbnew' >/dev/null 2>&1
    return $?
  fi

  "$probe_python" -c 'import pcbnew' >/dev/null 2>&1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --doctor)
      DOCTOR=1
      shift
      ;;
    --runtime)
      [ "$#" -ge 2 ] || die "--runtime requires a value"
      RUNTIME="$2"
      REQUESTED_RUNTIME="$RUNTIME"
      shift 2
      ;;
    --runtime=*)
      RUNTIME="${1#*=}"
      REQUESTED_RUNTIME="$RUNTIME"
      shift
      ;;
    --container)
      RUNTIME="container"
      REQUESTED_RUNTIME="$RUNTIME"
      shift
      ;;
    --host)
      RUNTIME="host"
      REQUESTED_RUNTIME="$RUNTIME"
      shift
      ;;
    --verbose)
      VERBOSE=1
      shift
      ;;
    --debug)
      VERBOSE=1
      export KICAD_MCP_LOG_LEVEL="${KICAD_MCP_LOG_LEVEL:-debug}"
      export KICAD_PYTHON_STDERR_LOG_LEVEL="${KICAD_PYTHON_STDERR_LOG_LEVEL:-DEBUG}"
      export KICAD_PYTHON_FILE_LOG_LEVEL="${KICAD_PYTHON_FILE_LOG_LEVEL:-DEBUG}"
      shift
      ;;
    --profile|--profile=*)
      die "KiCad MCP now exposes a single stable runtime; remove --profile"
      ;;
    --rebuild)
      FORCE_BUILD=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
  esac
done

REPO_PARENT="$(cd "$ROOT_DIR/.." && pwd)"
export CAD_HOST_ROOT="${CAD_HOST_ROOT:-$REPO_PARENT}"
export CAD_WORKSPACE_DIR="${CAD_WORKSPACE_DIR:-$ROOT_DIR}"
export KICAD_MCP_IMAGE="${KICAD_MCP_IMAGE:-kill_life_cad-kicad-mcp:latest}"
export KICAD_MCP_LOG_LEVEL="${KICAD_MCP_LOG_LEVEL:-warn}"
export KICAD_PYTHON_STDERR_LOG_LEVEL="${KICAD_PYTHON_STDERR_LOG_LEVEL:-WARNING}"
export KICAD_PYTHON_FILE_LOG_LEVEL="${KICAD_PYTHON_FILE_LOG_LEVEL:-INFO}"
MASCARADE_DIR="${MASCARADE_DIR:-$REPO_PARENT/mascarade}"
SERVER_DIR="$MASCARADE_DIR/finetune/kicad_mcp_server"
ENTRYPOINT="${KICAD_MCP_ENTRYPOINT:-$SERVER_DIR/dist/index.js}"
NODE_BIN="${NODE_BIN:-node}"
MCP_HOME="${KICAD_MCP_HOME:-$ROOT_DIR/.cad-home/kicad-mcp}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$MCP_HOME/.config}"
CACHE_HOME="${XDG_CACHE_HOME:-$MCP_HOME/.cache}"
DATA_DIR="${KICAD_MCP_DATA_DIR:-$MCP_HOME/data}"
PYTHONPATH_VALUE="$(build_pythonpath)"
PROBE_PYTHON="$(resolve_probe_python)"
HOST_PCBNEW_STATUS="missing"
CONTAINER_STATUS="unknown"

if probe_pcbnew "$PROBE_PYTHON" "$PYTHONPATH_VALUE"; then
  HOST_PCBNEW_STATUS="ok"
fi

if command -v docker >/dev/null 2>&1 && [ -f "$COMPOSE_FILE" ]; then
  CONTAINER_STATUS="available"
else
  CONTAINER_STATUS="missing"
fi

case "$RUNTIME" in
  auto)
    if [ "$HOST_PCBNEW_STATUS" = "ok" ]; then
      RUNTIME="host"
    else
      RUNTIME="container"
    fi
    ;;
  host|container)
    ;;
  *)
    die "invalid runtime: $RUNTIME"
    ;;
esac

if [ "$DOCTOR" -eq 1 ]; then
  cat <<EOF
ROOT_DIR=$ROOT_DIR
MASCARADE_DIR=$MASCARADE_DIR
SERVER_DIR=$SERVER_DIR
ENTRYPOINT=$ENTRYPOINT
NODE_BIN=$NODE_BIN
KICAD_MCP_HOME=$MCP_HOME
XDG_CONFIG_HOME=$CONFIG_HOME
XDG_CACHE_HOME=$CACHE_HOME
KICAD_MCP_DATA_DIR=$DATA_DIR
PROBE_PYTHON=$PROBE_PYTHON
KICAD_PYTHONPATH=$PYTHONPATH_VALUE
HOST_PCBNEW_IMPORT=$HOST_PCBNEW_STATUS
CONTAINER_STATUS=$CONTAINER_STATUS
KICAD_MCP_IMAGE=$KICAD_MCP_IMAGE
KICAD_MCP_LOG_LEVEL=$KICAD_MCP_LOG_LEVEL
KICAD_PYTHON_STDERR_LOG_LEVEL=$KICAD_PYTHON_STDERR_LOG_LEVEL
REQUESTED_RUNTIME=$REQUESTED_RUNTIME
SELECTED_RUNTIME=$RUNTIME
EOF
  exit 0
fi

[ -d "$MASCARADE_DIR" ] || die "companion repo not found: $MASCARADE_DIR"
[ -n "$PROBE_PYTHON" ] || die "no Python executable found for KiCad MCP runtime"

mkdir -p "$MCP_HOME" "$CONFIG_HOME" "$CACHE_HOME" "$DATA_DIR"

export HOME="$MCP_HOME"
export XDG_CONFIG_HOME="$CONFIG_HOME"
export XDG_CACHE_HOME="$CACHE_HOME"
export KICAD_MCP_DATA_DIR="$DATA_DIR"
if [ -n "$PYTHONPATH_VALUE" ]; then
  export KICAD_PYTHONPATH="$PYTHONPATH_VALUE"
fi

if [ "$RUNTIME" = "host" ]; then
  command -v "$NODE_BIN" >/dev/null 2>&1 || die "node executable not found: $NODE_BIN"
  [ -f "$ENTRYPOINT" ] || die "MCP entrypoint missing: $ENTRYPOINT (run npm build in mascarade/finetune/kicad_mcp_server)"
  probe_pcbnew "$PROBE_PYTHON" "${KICAD_PYTHONPATH:-}" || die "pcbnew is not importable from $PROBE_PYTHON. Install KiCad with Python bindings, set KICAD_PYTHON/KICAD_PYTHONPATH, or use --container."
  debug "exec host $NODE_BIN $ENTRYPOINT $*"
  exec "$NODE_BIN" "$ENTRYPOINT" "$@"
fi

command -v docker >/dev/null 2>&1 || die "docker is required for container runtime"
[ -f "$COMPOSE_FILE" ] || die "compose file not found: $COMPOSE_FILE"

if [ "$FORCE_BUILD" -eq 1 ] || ! docker image inspect "$KICAD_MCP_IMAGE" >/dev/null 2>&1; then
  log "Building kicad-mcp container (KiCad v10 via kicad/kicad:nightly-full)"
  compose build kicad-mcp >&2
fi

ACTIVE_CONTAINER_NAME="${KICAD_MCP_CONTAINER_NAME:-kill-life-kicad-mcp-$(id -u)-$$}"
trap cleanup_container EXIT INT TERM

debug "exec container kicad-mcp $*"
docker run --rm -i --init \
  --name "$ACTIVE_CONTAINER_NAME" \
  --user "$(id -u):$(id -g)" \
  --workdir "$CAD_WORKSPACE_DIR" \
  -v "$CAD_HOST_ROOT:$CAD_HOST_ROOT" \
  -e HOME="$MCP_HOME" \
  -e XDG_CONFIG_HOME="$CONFIG_HOME" \
  -e XDG_CACHE_HOME="$CACHE_HOME" \
  -e KICAD_MCP_DATA_DIR="$DATA_DIR" \
  -e KICAD_MCP_LOG_LEVEL="$KICAD_MCP_LOG_LEVEL" \
  -e KICAD_PYTHON_STDERR_LOG_LEVEL="$KICAD_PYTHON_STDERR_LOG_LEVEL" \
  -e KICAD_PYTHON_FILE_LOG_LEVEL="$KICAD_PYTHON_FILE_LOG_LEVEL" \
  "$KICAD_MCP_IMAGE" \
  sh -lc 'set -e; mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$KICAD_MCP_DATA_DIR"; exec node /opt/kicad-mcp/server/dist/index.js "$@"' sh "$@"
status=$?
trap - EXIT INT TERM
cleanup_container
exit $status
