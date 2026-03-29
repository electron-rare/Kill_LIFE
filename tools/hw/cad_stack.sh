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
  doctor-mcp             Print MCP runtime homes and run quick MCP smokes
  kicad-cli <args...>    Run kicad-cli with Kill_LIFE mounted as workspace
  freecad-cmd <args...>  Run FreeCADCmd with Kill_LIFE mounted as workspace
  openscad <args...>     Run OpenSCAD with Kill_LIFE mounted as workspace
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

docker_available() {
  command -v docker >/dev/null 2>&1 || return 1
  if [[ -n "${DOCKER_HOST:-}" ]]; then
    if [[ "$DOCKER_HOST" == unix://* ]]; then
      local socket_path
      socket_path="${DOCKER_HOST#unix://}"
      [ -S "$socket_path" ] || return 1
    fi
    return 0
  fi

  [ -S "/Users/electron/.docker/run/docker.sock" ] || [ -S "/var/run/docker.sock" ] || [ -S "${HOME}/.docker/run/docker.sock" ] || return 1
}

compose() {
  docker_available || die "Docker is required for this operation (compose unavailable)"
  debug "docker compose -f $COMPOSE_FILE $*"
  docker compose -f "$COMPOSE_FILE" "$@"
}

resolve_host_kicad_cli() {
  if [ -n "${KICAD_CLI:-}" ] && [ -x "${KICAD_CLI}" ]; then
    printf '%s' "$KICAD_CLI"
    return 0
  fi
  if [ -x /Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli ]; then
    printf '%s' /Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli
    return 0
  fi
  command -v kicad-cli 2>/dev/null || true
}

resolve_host_freecad_cmd() {
  local -a candidates=()
  local candidate=""

  if [ -n "${FREECAD_CMD:-}" ] && [ -x "${FREECAD_CMD}" ]; then
    candidates+=("${FREECAD_CMD}")
  fi
  if [ -x /Applications/FreeCAD.app/Contents/Resources/bin/freecadcmd ]; then
    candidates+=(/Applications/FreeCAD.app/Contents/Resources/bin/freecadcmd)
  fi
  if command -v freecadcmd >/dev/null 2>&1; then
    candidates+=("$(command -v freecadcmd)")
  fi
  if command -v FreeCADCmd >/dev/null 2>&1; then
    candidates+=("$(command -v FreeCADCmd)")
  fi

  for candidate in "${candidates[@]}"; do
    if ( "$candidate" -c 'import FreeCAD; print(".".join(FreeCAD.Version()[:3]))' >/dev/null 2>&1 ) 2>/dev/null; then
      printf '%s' "$candidate"
      return 0
    fi
  done

  return 0
}

resolve_host_openscad() {
  local -a candidates=()
  local candidate=""

  if [ -n "${OPENSCAD_BIN:-}" ] && [ -x "${OPENSCAD_BIN}" ]; then
    candidates+=("${OPENSCAD_BIN}")
  fi
  if command -v openscad >/dev/null 2>&1; then
    candidates+=("$(command -v openscad)")
  fi
  if [ -x /Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD ]; then
    candidates+=(/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD)
  fi

  for candidate in "${candidates[@]}"; do
    if "$candidate" --version >/dev/null 2>&1; then
      printf '%s' "$candidate"
      return 0
    fi
  done

  return 0
}

ensure_service_up() {
  local service="$1"
  if ! docker_available; then
    return 1
  fi

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
        kicad-headless|freecad-headless|openscad-headless|platformio)
          restart_services+=("$service")
          ;;
      esac
    done
  else
    compose build
    restart_services=(kicad-headless freecad-headless openscad-headless platformio)
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

  compose up -d kicad-headless freecad-headless openscad-headless platformio
}

doctor_cmd() {
  local host_kicad=""
  local host_freecad=""
  local host_openscad=""
  local host_platformio=""
  local degraded=0

  host_kicad="$(resolve_host_kicad_cli)"
  host_freecad="$(resolve_host_freecad_cmd)"
  host_openscad="$(resolve_host_openscad)"
  host_platformio="$(command -v platformio 2>/dev/null || true)"

  if [ -z "$host_kicad" ]; then
    if docker_available; then
      ensure_service_up kicad-headless
    else
      log "WARN: kicad-cli non trouvé et docker indisponible, check kicad ignoré"
      degraded=1
    fi
  fi
  if [ -z "$host_freecad" ]; then
    if docker_available; then
      ensure_service_up freecad-headless
    else
      log "WARN: freecadcmd non trouvé et docker indisponible, check freecad ignoré"
      degraded=1
    fi
  fi
  if [ -z "$host_openscad" ]; then
    if docker_available; then
      ensure_service_up openscad-headless
    else
      log "WARN: openscad non trouvé et docker indisponible, check openscad ignoré"
      degraded=1
    fi
  fi

  if [ -n "$host_kicad" ]; then
    "$host_kicad" version
  elif docker_available; then
    run_shell_as_host_user \
      kicad-headless \
      /workspace/.cad-home/kicad-headless \
      'mkdir -p "$HOME" && kicad-cli version'
  fi

  if [ -n "$host_freecad" ]; then
    "$host_freecad" -c 'import FreeCAD; print(".".join(FreeCAD.Version()[:3]))'
  elif docker_available; then
    run_shell_in_service_user \
      freecad-headless \
      /workspace/.cad-home/freecad-headless \
      'mkdir -p "$HOME" && freecadcmd -c "import FreeCAD; print(\".\".join(FreeCAD.Version()[:3]))"'
  fi

  if [ -n "$host_openscad" ]; then
    "$host_openscad" --version
  elif docker_available; then
    run_shell_as_host_user \
      openscad-headless \
      /workspace/.cad-home/openscad-headless \
      'mkdir -p "$HOME" && openscad --version'
  fi

  if [ -n "$host_platformio" ]; then
    "$host_platformio" --version
  elif docker_available; then
    ensure_service_up platformio
    run_shell_as_host_user \
      platformio \
      /workspace/.cad-home/platformio \
      'mkdir -p "$HOME" "$HOME/.platformio" && export PLATFORMIO_CORE_DIR="$HOME/.platformio" && pio --version'
  else
    log "WARN: platformio non trouvé et docker indisponible, check platformio ignoré"
    degraded=1
  fi

  if [ "$degraded" -eq 0 ]; then
    log "OK: CAD doctor checks executed successfully."
  else
    log "DEGRADED: CAD doctor fallback host-only for unavailable container runtime."
  fi
}

doctor_mcp_cmd() {
  "$ROOT_DIR/tools/run_freecad_mcp.sh" --doctor
  "$ROOT_DIR/tools/run_openscad_mcp.sh" --doctor
  (
    cd "$ROOT_DIR"
    python3 tools/freecad_mcp_smoke.py --json --quick
    python3 tools/openscad_mcp_smoke.py --json --quick
  )
}

kicad_cli_cmd() {
  local host_kicad=""
  host_kicad="$(resolve_host_kicad_cli)"
  if [ -n "$host_kicad" ]; then
    "$host_kicad" "$@"
    return
  fi
  ensure_service_up kicad-headless
  run_tool_as_host_user \
    kicad-headless \
    /workspace/.cad-home/kicad-headless \
    ":" \
    kicad-cli \
    "$@"
}

freecad_cmd() {
  local host_freecad=""
  host_freecad="$(resolve_host_freecad_cmd)"
  if [ -n "$host_freecad" ]; then
    "$host_freecad" "$@"
    return
  fi
  ensure_service_up freecad-headless
  run_tool_in_service_user \
    freecad-headless \
    /workspace/.cad-home/freecad-headless \
    ":" \
    freecadcmd \
    "$@"
}

openscad_cmd() {
  local host_openscad=""
  host_openscad="$(resolve_host_openscad)"
  if [ -n "$host_openscad" ]; then
    "$host_openscad" "$@"
    return
  fi
  ensure_service_up openscad-headless
  run_tool_as_host_user \
    openscad-headless \
    /workspace/.cad-home/openscad-headless \
    ":" \
    openscad \
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
  up|down|ps|build|doctor|doctor-mcp|kicad-cli|freecad-cmd|openscad|pio|mcp)
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
  doctor-mcp)
    doctor_mcp_cmd
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
  openscad)
    if [ "$#" -eq 0 ]; then
      echo "cad_stack.sh openscad: missing arguments" >&2
      exit 2
    fi
    openscad_cmd "$@"
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
