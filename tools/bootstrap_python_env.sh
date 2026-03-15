#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="${ROOT_DIR}/.venv"
PYTHON_BIN="${PYTHON_BIN:-python3}"
REINSTALL=false
WITH_PLATFORMIO=false
REQ_FILE="${ROOT_DIR}/tools/compliance/requirements.txt"
PIO_REQ_FILE="${ROOT_DIR}/tools/compliance/requirements-platformio.txt"

usage() {
  cat <<'EOF'
Usage: bash tools/bootstrap_python_env.sh [options]

Create or refresh the supported repo-local Python environment for Kill_LIFE.

Options:
  --python BIN       Python interpreter to use (default: PYTHON_BIN or python3)
  --venv-dir PATH    Virtualenv directory to create/reuse (default: ./.venv)
  --reinstall        Remove and recreate the target virtualenv before install
  --with-platformio  Install PlatformIO in the target virtualenv
  -h, --help         Show this help

Notes:
  - The stable repo-local suite uses unittest and a minimal dependency set.
  - PyYAML is installed because tools/validate_specs.py depends on compliance YAML helpers.
  - jsonschema is installed because test_apply_safe_patch exercises tools/mistral/apply_safe_patch.py.

Examples:
  bash tools/bootstrap_python_env.sh
  bash tools/bootstrap_python_env.sh --with-platformio
  bash tools/bootstrap_python_env.sh --venv-dir /tmp/kill-life-venv --reinstall
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
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
    --reinstall)
      REINSTALL=true
      ;;
    --with-platformio)
      WITH_PLATFORMIO=true
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

if ! command -v "${PYTHON_BIN}" >/dev/null 2>&1; then
  echo "Python interpreter not found: ${PYTHON_BIN}" >&2
  exit 1
fi

if [[ "${REINSTALL}" == true && -d "${VENV_DIR}" ]]; then
  echo "[bootstrap-python] removing ${VENV_DIR}"
  rm -rf "${VENV_DIR}"
fi

if [[ ! -x "${VENV_DIR}/bin/python" ]]; then
  echo "[bootstrap-python] creating ${VENV_DIR}"
  "${PYTHON_BIN}" -m venv "${VENV_DIR}"
else
  echo "[bootstrap-python] reusing ${VENV_DIR}"
fi

if ! "${VENV_DIR}/bin/python" -c "import yaml, jsonschema" >/dev/null 2>&1; then
  echo "[bootstrap-python] installing minimal test dependencies"
  "${VENV_DIR}/bin/python" -m pip install --upgrade pip setuptools wheel
  "${VENV_DIR}/bin/python" -m pip install -r "${REQ_FILE}"
  "${VENV_DIR}/bin/python" -m pip install 'jsonschema>=4.21.0'
fi

if [[ "${WITH_PLATFORMIO}" == true ]]; then
  echo "[bootstrap-python] ensuring PlatformIO requirement"
  "${VENV_DIR}/bin/python" -m pip install -r "${PIO_REQ_FILE}"
fi

echo "[bootstrap-python] python: ${VENV_DIR}/bin/python"
echo "[bootstrap-python] test:   bash tools/test_python.sh --venv-dir ${VENV_DIR}"
