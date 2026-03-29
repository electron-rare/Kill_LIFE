#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
KICAD_SRC="${ROOT_DIR}/tools/cad/integrations/kicad/yiacad_kicad_plugin"
FREECAD_SRC="${ROOT_DIR}/tools/cad/integrations/freecad/YiACADWorkbench"

KICAD_PLUGIN_DIR="${KICAD_PLUGIN_DIR:-${HOME}/Library/Application Support/kicad/scripting/plugins}"
FREECAD_MOD_DIR="${FREECAD_MOD_DIR:-${HOME}/Library/Application Support/FreeCAD/Mod}"

COMMAND="status"

usage() {
  cat <<'EOF'
Usage: bash tools/cad/install_yiacad_native_gui.sh <status|install|uninstall>

Install or inspect the YiACAD native GUI surfaces for KiCad and FreeCAD.

Env overrides:
  KICAD_PLUGIN_DIR
  FREECAD_MOD_DIR
EOF
}

link_target() {
  local link_path="$1"
  if [[ -L "$link_path" ]]; then
    readlink "$link_path"
  elif [[ -e "$link_path" ]]; then
    printf '%s' "<non-symlink>"
  else
    printf '%s' "<missing>"
  fi
}

status() {
  printf 'ROOT_DIR=%s\n' "$ROOT_DIR"
  printf 'KICAD_PLUGIN_DIR=%s\n' "$KICAD_PLUGIN_DIR"
  printf 'FREECAD_MOD_DIR=%s\n' "$FREECAD_MOD_DIR"
  printf 'TRANSPORT=service-first via %s\n' "${ROOT_DIR}/tools/cad/yiacad_backend_client.py"
  printf 'KICAD_LINK=%s\n' "$(link_target "${KICAD_PLUGIN_DIR}/yiacad_kicad_plugin")"
  printf 'FREECAD_LINK=%s\n' "$(link_target "${FREECAD_MOD_DIR}/YiACADWorkbench")"
}

install_links() {
  mkdir -p "$KICAD_PLUGIN_DIR" "$FREECAD_MOD_DIR"
  ln -sfn "$KICAD_SRC" "${KICAD_PLUGIN_DIR}/yiacad_kicad_plugin"
  ln -sfn "$FREECAD_SRC" "${FREECAD_MOD_DIR}/YiACADWorkbench"
  status
}

uninstall_links() {
  rm -f "${KICAD_PLUGIN_DIR}/yiacad_kicad_plugin"
  rm -f "${FREECAD_MOD_DIR}/YiACADWorkbench"
  status
}

if [[ $# -gt 0 ]]; then
  COMMAND="$1"
fi

case "$COMMAND" in
  status)
    status
    ;;
  install)
    install_links
    ;;
  uninstall)
    uninstall_links
    ;;
  -h|--help)
    usage
    ;;
  *)
    echo "Unknown command: $COMMAND" >&2
    usage >&2
    exit 2
    ;;
esac
