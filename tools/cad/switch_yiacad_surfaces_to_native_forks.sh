#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
KICAD_PLUGIN_DIR="${KICAD_PLUGIN_DIR:-${HOME}/Library/Application Support/kicad/scripting/plugins}"
FREECAD_MOD_DIR="${FREECAD_MOD_DIR:-${HOME}/Library/Application Support/FreeCAD/Mod}"
KICAD_SURFACE="${ROOT_DIR}/.runtime-home/cad-ai-native-forks/kicad-ki/scripting/plugins/yiacad_kicad_plugin"
FREECAD_SURFACE="${ROOT_DIR}/.runtime-home/cad-ai-native-forks/freecad-ki/src/Mod/YiACADWorkbench"

mkdir -p "${KICAD_PLUGIN_DIR}" "${FREECAD_MOD_DIR}"
ln -sfn "${KICAD_SURFACE}" "${KICAD_PLUGIN_DIR}/yiacad_kicad_plugin"
ln -sfn "${FREECAD_SURFACE}" "${FREECAD_MOD_DIR}/YiACADWorkbench"

printf 'ROOT_DIR=%s\n' "${ROOT_DIR}"
printf 'KICAD_SURFACE=%s\n' "${KICAD_SURFACE}"
printf 'FREECAD_SURFACE=%s\n' "${FREECAD_SURFACE}"
printf 'KICAD_PLUGIN_DIR=%s\n' "${KICAD_PLUGIN_DIR}"
printf 'FREECAD_MOD_DIR=%s\n' "${FREECAD_MOD_DIR}"
