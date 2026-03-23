#!/usr/bin/env bash
set -euo pipefail

# Load optional Kill_LIFE local Mistral governance secrets without touching repo .env files.

MISTRAL_GOVERNANCE_ENV_FILE="${KILL_LIFE_MISTRAL_ENV_FILE:-${HOME}/.kill-life/mistral.env}"

if [[ -f "${MISTRAL_GOVERNANCE_ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  . "${MISTRAL_GOVERNANCE_ENV_FILE}"
fi
