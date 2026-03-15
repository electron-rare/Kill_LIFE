#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="status"
BUNDLE=""

usage() {
  cat <<'EOF'
Usage: bash tools/review_local_change_bundle.sh <bundle> [mode]

Bundles:
  mcp-runtime   Runtime-home, knowledge-base, GitHub dispatch, docs MCP associees
  cad-mcp       Pile CAD/MCP (FreeCAD, OpenSCAD, compose CAD, specs et docs associees)
  python-local  Commande Python repo-locale stable encore dans le delta courant
  all           Ensemble des lots suivis localement

Modes:
  status        git status cible sur le bundle (default)
  diff          git diff cible sur le bundle
  paths         liste exacte des fichiers du bundle

Examples:
  bash tools/review_local_change_bundle.sh mcp-runtime
  bash tools/review_local_change_bundle.sh cad-mcp diff
  bash tools/review_local_change_bundle.sh python-local diff
  bash tools/review_local_change_bundle.sh all paths
EOF
}

bundle_paths() {
  case "$1" in
    mcp-runtime)
      cat <<'EOF'
README.md
ai-agentic-embedded-base/specs/README.md
ai-agentic-embedded-base/specs/mcp_tasks.md
ai-agentic-embedded-base/specs/knowledge_base_mcp_spec.md
ai-agentic-embedded-base/specs/notion_mcp_conversion_spec.md
ai-agentic-embedded-base/specs/zeroclaw_dual_hw_todo.md
docs/LOCAL_CHANGE_BUNDLES_2026-03-08.md
docs/MCP_ECOSYSTEM_MATRIX.md
docs/MCP_SETUP.md
docs/MCP_SUPPORT_MATRIX.md
docs/RUNTIME_HOME.md
docs/plans/15_plan_mcp_runtime_alignment.md
docs/plans/README.md
mcp.json
specs/README.md
specs/knowledge_base_mcp_spec.md
specs/mcp_tasks.md
specs/notion_mcp_conversion_spec.md
test/test_knowledge_base_mcp.py
test/test_notion_mcp.py
tools/github_dispatch_mcp_smoke.py
tools/lib/runtime_home.sh
tools/knowledge_base_mcp.py
tools/knowledge_base_mcp_smoke.py
tools/mcp_runtime_status.py
tools/mcp_smoke_common.py
tools/notion_mcp.py
tools/notion_mcp_smoke.py
tools/review_local_change_bundle.sh
tools/run_github_dispatch_mcp.sh
tools/run_knowledge_base_mcp.sh
tools/run_notion_mcp.sh
EOF
      ;;
    cad-mcp)
      cat <<'EOF'
Makefile
ai-agentic-embedded-base/specs/cad_modeling_tasks.md
ai-agentic-embedded-base/specs/mcp_agentics_target_backlog.md
deploy/cad/README.md
deploy/cad/Dockerfile.openscad-headless
deploy/cad/docker-compose.yml
docs/plans/16_plan_cad_modeling_stack.md
docs/plans/17_plan_target_architecture_mcp_agentics_2028.md
specs/cad_modeling_tasks.md
specs/mcp_agentics_target_backlog.md
test/test_freecad_mcp.py
test/test_openscad_mcp.py
tools/cad_runtime.py
tools/freecad_mcp.py
tools/freecad_mcp_smoke.py
tools/hw/cad_stack.sh
tools/hw/freecad_smoke.py
tools/hw/openscad_smoke.py
tools/mcp_telemetry.py
tools/openscad_mcp.py
tools/openscad_mcp_smoke.py
tools/run_freecad_mcp.sh
tools/run_openscad_mcp.sh
EOF
      ;;
    python-local)
      cat <<'EOF'
tools/test_python.sh
EOF
      ;;
    all)
      {
        bundle_paths mcp-runtime
        bundle_paths cad-mcp
        bundle_paths python-local
      } | awk '!seen[$0]++'
      ;;
    *)
      echo "Unknown bundle: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage >&2
  exit 2
fi

BUNDLE="$1"
if [[ $# -eq 2 ]]; then
  MODE="$2"
fi

mapfile -t PATHS < <(bundle_paths "$BUNDLE")

case "$MODE" in
  status)
    exec git -C "$ROOT_DIR" status --short -- "${PATHS[@]}"
    ;;
  diff)
    exec git -C "$ROOT_DIR" diff -- "${PATHS[@]}"
    ;;
  paths)
    printf '%s\n' "${PATHS[@]}"
    ;;
  *)
    echo "Unknown mode: $MODE" >&2
    usage >&2
    exit 2
    ;;
esac
