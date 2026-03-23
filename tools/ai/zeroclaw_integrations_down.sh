#!/usr/bin/env bash
set -euo pipefail

N8N_CONTAINER="${ZEROCLAW_N8N_CONTAINER:-mascarade-n8n}"
YES=0

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

usage() {
  cat <<'EOF'
Usage: bash tools/ai/zeroclaw_integrations_down.sh [options]

Stop the local n8n integration container.

Options:
  --yes        Confirm the stop action
  -h, --help   Show this help

Env overrides:
  ZEROCLAW_N8N_CONTAINER
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes)
      YES=1
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

[[ "${YES}" == "1" ]] || {
  echo "Refusing to stop ${N8N_CONTAINER} without --yes." >&2
  exit 1
}

if ! docker_available; then
  echo "already_stopped=${N8N_CONTAINER}"
  echo "reason=docker_unavailable"
  exit 0
fi

if docker ps --filter "name=^/${N8N_CONTAINER}$" --format '{{.Names}}' | grep -qx "${N8N_CONTAINER}"; then
  docker stop "${N8N_CONTAINER}" >/dev/null
  echo "stopped=${N8N_CONTAINER}"
  exit 0
fi

echo "already_stopped=${N8N_CONTAINER}"
