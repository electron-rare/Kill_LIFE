#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="${ROOT_DIR}/.venv"
PYTHON_BIN="${PYTHON_BIN:-python3}"
BOOTSTRAP=false
SUITE="stable"
LIST_ONLY=false

usage() {
  cat <<'EOF'
Usage: bash tools/test_python.sh [options]

Run the supported Kill_LIFE repo-local Python suites through the repo-local venv.

Options:
  --suite NAME       stable | mcp | all (default: stable)
  --bootstrap        Create/install the venv first if missing
  --python BIN       Python interpreter forwarded to bootstrap if needed
  --venv-dir PATH    Virtualenv directory to use (default: ./.venv)
  --list             Print the covered commands and exit
  -h, --help         Show this help

Suites:
  stable  Repo-local unittest suite without companion runtimes.
  mcp     MCP integration tests that exercise local launchers.
  all     stable + mcp.
EOF
}

run_discover() {
  local start_dir="$1"
  local pattern="$2"
  (
    cd "${ROOT_DIR}"
    "${VENV_DIR}/bin/python" -m unittest discover -s "${start_dir}" -p "${pattern}"
  )
}

print_suite() {
  case "$1" in
    stable)
      cat <<'EOF'
stable:
  test/test_setup_repo_dry_run.py
  test/test_mcp_runtime_status.py
  test/test_openclaw_sanitizer.py
  test/test_apply_safe_patch.py
  test/test_auto_check_ci_cd.py
  test/test_firmware_evidence.py
  test/test_validate_specs.py
  tools/hw/schops/tests/test_*.py
EOF
      ;;
    mcp)
      cat <<'EOF'
mcp:
  test/test_knowledge_base_mcp.py
  test/test_github_dispatch_mcp.py
  test/test_nexar_mcp.py
EOF
      ;;
    all)
      print_suite stable
      print_suite mcp
      ;;
    *)
      echo "Unknown suite: $1" >&2
      return 2
      ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --suite)
      shift
      [[ $# -gt 0 ]] || { echo "Missing value for --suite" >&2; usage >&2; exit 2; }
      SUITE="$1"
      ;;
    --bootstrap)
      BOOTSTRAP=true
      ;;
    --python)
      shift
      [[ $# -gt 0 ]] || { echo "Missing value for --python" >&2; usage >&2; exit 2; }
      PYTHON_BIN="$1"
      ;;
    --venv-dir)
      shift
      [[ $# -gt 0 ]] || { echo "Missing value for --venv-dir" >&2; usage >&2; exit 2; }
      VENV_DIR="$1"
      ;;
    --list)
      LIST_ONLY=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

case "${SUITE}" in
  stable|mcp|all)
    ;;
  *)
    echo "Unknown suite: ${SUITE}" >&2
    usage >&2
    exit 2
    ;;
esac

if [[ "${LIST_ONLY}" == true ]]; then
  print_suite "${SUITE}"
  exit 0
fi

if [[ "${BOOTSTRAP}" == true ]]; then
  bash "${ROOT_DIR}/tools/bootstrap_python_env.sh" --python "${PYTHON_BIN}" --venv-dir "${VENV_DIR}"
elif [[ ! -x "${VENV_DIR}/bin/python" ]]; then
  echo "Missing ${VENV_DIR}. Run: bash tools/bootstrap_python_env.sh --venv-dir ${VENV_DIR}" >&2
  exit 1
fi

export PYTHONPATH="${ROOT_DIR}${PYTHONPATH:+:${PYTHONPATH}}"

if [[ "${SUITE}" == "stable" || "${SUITE}" == "all" ]]; then
  run_discover test 'test_setup_repo_dry_run.py'
  run_discover test 'test_mcp_runtime_status.py'
  run_discover test 'test_openclaw_sanitizer.py'
  run_discover test 'test_apply_safe_patch.py'
  run_discover test 'test_auto_check_ci_cd.py'
  run_discover test 'test_firmware_evidence.py'
  run_discover test 'test_validate_specs.py'
  run_discover tools/hw/schops/tests 'test_*.py'
fi

if [[ "${SUITE}" == "mcp" || "${SUITE}" == "all" ]]; then
  run_discover test 'test_knowledge_base_mcp.py'
  run_discover test 'test_github_dispatch_mcp.py'
  run_discover test 'test_nexar_mcp.py'
fi
