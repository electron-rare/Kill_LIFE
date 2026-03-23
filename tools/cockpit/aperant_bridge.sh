#!/usr/bin/env bash
set -euo pipefail
# ─────────────────────────────────────────────────────────────────
#  Aperant ↔ Kill_LIFE Bridge
#  Provides cockpit entry points for the Aperant multi-agent
#  autonomous coding framework (git submodule at tools/aperant).
# ─────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
APERANT_DIR="${ROOT_DIR}/tools/aperant"
WEB_DIR="${ROOT_DIR}/web/aperant"
TOWER_HOST="clems@192.168.0.120"

# ── helpers ──────────────────────────────────────────────────────
_ensure_submodule() {
  if [ ! -f "${APERANT_DIR}/package.json" ]; then
    echo "⚠  Aperant submodule not initialised – running git submodule update …"
    git -C "${ROOT_DIR}" submodule update --init --recursive -- tools/aperant
  fi
}

_require_node() {
  if ! command -v node &>/dev/null; then
    echo "✗ node not found. Aperant requires Node >= 24." >&2
    exit 1
  fi
}

_aperant_version() {
  node -e "console.log(require('${APERANT_DIR}/package.json').version)" 2>/dev/null || echo "unknown"
}

# ── commands ─────────────────────────────────────────────────────

cmd_status() {
  _ensure_submodule
  local ver
  ver=$(_aperant_version)
  local branch
  branch=$(git -C "${APERANT_DIR}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached")
  local sha
  sha=$(git -C "${APERANT_DIR}" rev-parse --short HEAD 2>/dev/null || echo "?")

  echo "┌──────────────────────────────────────┐"
  echo "│  Aperant  v${ver}                    │"
  echo "│  branch : ${branch}                  │"
  echo "│  commit : ${sha}                     │"
  echo "│  path   : tools/aperant              │"
  echo "└──────────────────────────────────────┘"

  # Check if desktop app deps are installed
  if [ -d "${APERANT_DIR}/apps/desktop/node_modules" ]; then
    echo "  deps    : installed ✓"
  else
    echo "  deps    : not installed (run: make aperant-install)"
  fi
}

cmd_install() {
  _ensure_submodule
  _require_node
  echo "── Installing Aperant dependencies …"
  (cd "${APERANT_DIR}" && npm run install:all)
  echo "✓ Aperant dependencies installed."
}

cmd_dev() {
  _ensure_submodule
  _require_node
  echo "── Launching Aperant in dev mode …"
  (cd "${APERANT_DIR}" && npm run dev)
}

cmd_start() {
  _ensure_submodule
  _require_node
  echo "── Building & launching Aperant …"
  (cd "${APERANT_DIR}" && npm start)
}

cmd_build() {
  _ensure_submodule
  _require_node
  echo "── Building Aperant …"
  (cd "${APERANT_DIR}" && npm run build)
}

cmd_test() {
  _ensure_submodule
  _require_node
  echo "── Running Aperant tests …"
  (cd "${APERANT_DIR}" && npm test)
}

cmd_update() {
  _ensure_submodule
  echo "── Pulling latest Aperant (develop) …"
  git -C "${APERANT_DIR}" fetch origin
  git -C "${APERANT_DIR}" checkout develop
  git -C "${APERANT_DIR}" pull --ff-only origin develop
  echo "✓ Aperant updated to $(git -C "${APERANT_DIR}" rev-parse --short HEAD)"
}

# ── web commands ─────────────────────────────────────────────────

cmd_web_install() {
  _ensure_submodule
  _require_node
  echo "── Installing Aperant Web dependencies …"
  (cd "${WEB_DIR}" && npm install)
  echo "✓ Web dependencies installed."
}

cmd_web_dev() {
  _ensure_submodule
  _require_node
  echo "── Launching Aperant Web (UI :5180 + API :5181) …"
  (cd "${WEB_DIR}" && npm run dev)
}

cmd_web_build() {
  _ensure_submodule
  _require_node
  echo "── Building Aperant Web …"
  (cd "${WEB_DIR}" && npm run build)
}

cmd_deploy() {
  _ensure_submodule
  _require_node
  echo "── Deploying Aperant Web → aperant.saillant.cc (tower) …"
  bash "${WEB_DIR}/deploy.sh"
}

cmd_tower_status() {
  echo "── Aperant Web on tower …"
  ssh "${TOWER_HOST}" "pm2 describe aperant-web 2>/dev/null || echo 'not running'"
}

cmd_tower_logs() {
  ssh "${TOWER_HOST}" "pm2 logs aperant-web --lines ${2:-50}"
}

# ── main ─────────────────────────────────────────────────────────

usage() {
  cat <<'EOF'
Usage: bash tools/cockpit/aperant_bridge.sh <command>

Submodule (Electron desktop):
  status       Show Aperant version, branch, and dep state
  install      Install Aperant desktop app dependencies
  dev          Launch Aperant in dev mode (HMR)
  start        Build & launch Aperant desktop app
  build        Build Aperant (no launch)
  test         Run Aperant test suite
  update       Pull latest from Aperant develop branch

Web (aperant.saillant.cc):
  web-install  Install web app dependencies
  web-dev      Launch web UI (:5180) + API (:5181) locally
  web-build    Build web app for production
  deploy       Build + deploy to tower (clems@192.168.0.120)
  tower-status Check PM2 status on tower
  tower-logs   Tail PM2 logs on tower

Aperant is an autonomous multi-agent AI coding framework that
orchestrates Claude Code agents for planning, building, and QA.
EOF
}

case "${1:-}" in
  status)       cmd_status       ;;
  install)      cmd_install      ;;
  dev)          cmd_dev          ;;
  start)        cmd_start        ;;
  build)        cmd_build        ;;
  test)         cmd_test         ;;
  update)       cmd_update       ;;
  web-install)  cmd_web_install  ;;
  web-dev)      cmd_web_dev      ;;
  web-build)    cmd_web_build    ;;
  deploy)       cmd_deploy       ;;
  tower-status) cmd_tower_status ;;
  tower-logs)   cmd_tower_logs   ;;
  -h|--help|"") usage            ;;
  *)
    echo "Unknown command: $1" >&2
    usage >&2
    exit 1
    ;;
esac
