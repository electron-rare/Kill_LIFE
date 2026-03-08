#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="status"
BUNDLE=""

usage() {
  cat <<'EOF'
Usage: bash tools/review_local_change_bundle.sh <bundle> [mode]

Bundles:
  mcp-runtime   Runtime-home, MCP launchers, MCP smokes, docs MCP associees
  python-local  Bootstrap/test Python repo-local et harness associes
  all           Ensemble des lots suivis localement

Modes:
  status        git status cible sur le bundle (default)
  diff          git diff cible sur le bundle
  paths         liste exacte des fichiers du bundle

Examples:
  bash tools/review_local_change_bundle.sh mcp-runtime
  bash tools/review_local_change_bundle.sh python-local diff
  bash tools/review_local_change_bundle.sh all paths
EOF
}

bundle_paths() {
  case "$1" in
    mcp-runtime)
      cat <<'EOF'
.gitignore
ai-agentic-embedded-base/specs/mcp_tasks.md
docs/QUICKSTART.md
docs/index.md
docs/RUNTIME_HOME.md
tools/github_dispatch_mcp_smoke.py
tools/hw/kicad_cli.sh
tools/hw/run_kicad_mcp.sh
tools/lib/runtime_home.sh
tools/notion_mcp.py
tools/notion_mcp_smoke.py
tools/run_github_dispatch_mcp.sh
tools/run_nexar_mcp.sh
tools/run_notion_mcp.sh
EOF
      ;;
    python-local)
      cat <<'EOF'
README.md
test/test_openclaw_sanitizer.py
tools/bootstrap_python_env.sh
tools/hw/schops/tests/test_rules_engine.py
tools/test_python.sh
EOF
      ;;
    all)
      {
        bundle_paths mcp-runtime
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
