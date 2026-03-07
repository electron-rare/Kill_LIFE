#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
COMPOSE_FILE="$ROOT_DIR/deploy/cad/docker-compose.yml"
VERBOSE=0

usage() {
  cat <<'EOF'
Usage: tools/hw/cad_stack.sh <command> [args...]

Stack CAD/EDA locale intégrée à Kill_LIFE.

Commands:
  up [services...]       Start CAD helper containers
  down                   Stop CAD helper containers
  ps                     Show CAD container status
  build [services...]    Build local CAD images
  doctor                 Print tool versions from the containers
  kicad-cli <args...>    Run kicad-cli with Kill_LIFE mounted as workspace
  freecad-cmd <args...>  Run FreeCADCmd with Kill_LIFE mounted as workspace
  pio <args...>          Run PlatformIO with Kill_LIFE mounted as workspace
  mcp [args...]          Run the KiCad MCP server in stdio mode
  help                   Show this help

Env:
  CAD_WORKSPACE_DIR      Workspace mounted at /workspace (default: Kill_LIFE root)
  CAD_HOST_ROOT          Parent path mounted 1:1 for the MCP container (default: parent of Kill_LIFE)
  KICAD_DOCKER_IMAGE     KiCad v10 image/tag override (default: kicad/kicad:nightly-full)
EOF
}

log() {
  printf '[kill_life:cad] %s\n' "$*"
}

debug() {
  if [ "$VERBOSE" -eq 1 ]; then
    printf '[kill_life:cad][dbg] %s\n' "$*" >&2
  fi
}

die() {
  printf '[kill_life:cad][err] %s\n' "$*" >&2
  exit 1
}

compose() {
  debug "docker compose -f $COMPOSE_FILE $*"
  docker compose -f "$COMPOSE_FILE" "$@"
}

ensure_service_up() {
  local service="$1"
  if ! compose ps --status running --services | grep -qx "$service"; then
    log "Starting $service"
    compose up -d "$service"
  fi
}

run_shell_as_host_user() {
  local service="$1"
  local home_dir="$2"
  shift 2
  local shell_command="$*"
  compose exec -T \
    --user "$(id -u):$(id -g)" \
    -e HOME="$home_dir" \
    "$service" \
    sh -lc "$shell_command"
}

run_tool_as_host_user() {
  local service="$1"
  local home_dir="$2"
  local prelude="$3"
  local binary="$4"
  shift 4
  compose exec -T \
    --user "$(id -u):$(id -g)" \
    -e HOME="$home_dir" \
    "$service" \
    sh -lc 'set -e; mkdir -p "$HOME"; '"$prelude"'; exec "$@"' sh "$binary" "$@"
}

run_shell_in_service_user() {
  local service="$1"
  local home_dir="$2"
  shift 2
  local shell_command="$*"
  compose exec -T \
    -e HOME="$home_dir" \
    "$service" \
    sh -lc "$shell_command"
}

run_tool_in_service_user() {
  local service="$1"
  local home_dir="$2"
  local prelude="$3"
  local binary="$4"
  shift 4
  compose exec -T \
    -e HOME="$home_dir" \
    "$service" \
    sh -lc 'set -e; mkdir -p "$HOME"; '"$prelude"'; exec "$@"' sh "$binary" "$@"
}

build_cmd() {
  local restart_services=()
  if [ "$#" -gt 0 ]; then
    compose build "$@"
    for service in "$@"; do
      case "$service" in
        kicad-headless|freecad-headless|platformio)
          restart_services+=("$service")
          ;;
      esac
    done
  else
    compose build
    restart_services=(kicad-headless freecad-headless platformio)
  fi

  if [ "${#restart_services[@]}" -gt 0 ]; then
    log "Recreating updated services: ${restart_services[*]}"
    compose up -d --force-recreate "${restart_services[@]}"
  fi
}

up_cmd() {
  if [ "$#" -gt 0 ]; then
    compose up -d "$@"
    return
  fi

  compose up -d kicad-headless freecad-headless platformio
}

doctor_cmd() {
  ensure_service_up kicad-headless
  ensure_service_up freecad-headless
  ensure_service_up platformio

  run_shell_as_host_user \
    kicad-headless \
    /workspace/.cad-home/kicad-headless \
    'mkdir -p "$HOME" && kicad-cli version'

  run_shell_in_service_user \
    freecad-headless \
    /workspace/.cad-home/freecad-headless \
    'mkdir -p "$HOME" && freecadcmd -c "import FreeCAD; print(\".\".join(FreeCAD.Version()[:3]))"'

  run_shell_as_host_user \
    platformio \
    /workspace/.cad-home/platformio \
    'mkdir -p "$HOME" "$HOME/.platformio" && export PLATFORMIO_CORE_DIR="$HOME/.platformio" && pio --version'
}

kicad_cli_cmd() {
  ensure_service_up kicad-headless
  run_tool_as_host_user \
    kicad-headless \
    /workspace/.cad-home/kicad-headless \
    ":" \
    kicad-cli \
    "$@"
}

freecad_cmd() {
  ensure_service_up freecad-headless
  run_tool_in_service_user \
    freecad-headless \
    /workspace/.cad-home/freecad-headless \
    ":" \
    freecadcmd \
    "$@"
}

pio_cmd() {
  ensure_service_up platformio
  run_tool_as_host_user \
    platformio \
    /workspace/.cad-home/platformio \
    'mkdir -p "$HOME/.platformio"; export PLATFORMIO_CORE_DIR="$HOME/.platformio"' \
    pio \
    "$@"
}

mcp_cmd() {
  "$ROOT_DIR/tools/hw/run_kicad_mcp.sh" "$@"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -v|--verbose)
      VERBOSE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      break
      ;;
  esac
done

CMD="${1:-help}"
if [ "$#" -gt 0 ]; then
  shift
fi

[ -f "$COMPOSE_FILE" ] || die "CAD compose file not found: $COMPOSE_FILE"
export CAD_WORKSPACE_DIR="${CAD_WORKSPACE_DIR:-$ROOT_DIR}"
export CAD_HOST_ROOT="${CAD_HOST_ROOT:-$(cd "$ROOT_DIR/.." && pwd)}"

if [ "$CMD" = "help" ]; then
  usage
  exit 0
fi

case "$CMD" in
  up|down|ps|build|doctor|kicad-cli|freecad-cmd|pio|mcp)
    ;;
  *)
    usage >&2
    die "unknown command: $CMD"
    ;;
esac

debug "root=$ROOT_DIR"
debug "compose_file=$COMPOSE_FILE"
debug "workspace_dir=$CAD_WORKSPACE_DIR"
debug "command=$CMD"

case "$CMD" in
  up)
    up_cmd "$@"
    ;;
  down)
    compose down
    ;;
  ps)
    compose ps
    ;;
  build)
    build_cmd "$@"
    ;;
  doctor)
    doctor_cmd
    ;;
  kicad-cli)
    if [ "$#" -eq 0 ]; then
      echo "cad_stack.sh kicad-cli: missing arguments" >&2
      exit 2
    fi
    kicad_cli_cmd "$@"
    ;;
  freecad-cmd)
    if [ "$#" -eq 0 ]; then
      echo "cad_stack.sh freecad-cmd: missing arguments" >&2
      exit 2
    fi
    freecad_cmd "$@"
    ;;
  pio)
    if [ "$#" -eq 0 ]; then
      echo "cad_stack.sh pio: missing arguments" >&2
      exit 2
    fi
    pio_cmd "$@"
    ;;
  mcp)
    mcp_cmd "$@"
    ;;
esac
