#!/usr/bin/env bash
set -uo pipefail

# Contract validation tests
# Validates JSON schemas in specs/contracts/ and artifacts in artifacts/ops/

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CONTRACTS_DIR="$ROOT_DIR/specs/contracts"
ARTIFACTS_DIR="$ROOT_DIR/artifacts/ops"

SCHEMA_VALID=0
SCHEMA_INVALID=0
SCHEMA_TOTAL=0
ARTIFACT_VALID=0
ARTIFACT_INVALID=0
ARTIFACT_TOTAL=0

# Colors (disabled if not a terminal)
if [[ -t 1 ]]; then
  GREEN=$'\033[0;32m'
  RED=$'\033[0;31m'
  BOLD=$'\033[1m'
  RESET=$'\033[0m'
else
  GREEN="" RED="" BOLD="" RESET=""
fi

# Require jq
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required but not found in PATH." >&2
  exit 1
fi

echo "${BOLD}Contract Validation Tests${RESET}"
echo "========================="
echo ""

# ---------------------------------------------------------------------------
# Part 1: Validate all .schema.json files parse as valid JSON
# ---------------------------------------------------------------------------
echo "${BOLD}1. JSON Schema Validation${RESET}"
echo "   Directory: $CONTRACTS_DIR"
echo ""

if [[ ! -d "$CONTRACTS_DIR" ]]; then
  echo "   WARNING: contracts directory not found at $CONTRACTS_DIR"
else
  for schema_file in "$CONTRACTS_DIR"/*.schema.json; do
    [[ -f "$schema_file" ]] || continue
    SCHEMA_TOTAL=$((SCHEMA_TOTAL + 1))
    basename="$(basename "$schema_file")"

    if jq empty "$schema_file" 2>/dev/null; then
      SCHEMA_VALID=$((SCHEMA_VALID + 1))
      printf "  ${GREEN}VALID${RESET}   %s\n" "$basename"
    else
      SCHEMA_INVALID=$((SCHEMA_INVALID + 1))
      printf "  ${RED}INVALID${RESET} %s\n" "$basename"
    fi
  done

  if [[ "$SCHEMA_TOTAL" -eq 0 ]]; then
    echo "   No .schema.json files found."
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# Part 2: Validate artifacts in artifacts/ops/*/latest.json
# ---------------------------------------------------------------------------
echo "${BOLD}2. Artifact Validation${RESET}"
echo "   Directory: $ARTIFACTS_DIR"
echo ""

if [[ ! -d "$ARTIFACTS_DIR" ]]; then
  echo "   WARNING: artifacts directory not found at $ARTIFACTS_DIR"
else
  for latest_file in "$ARTIFACTS_DIR"/*/latest.json; do
    [[ -f "$latest_file" ]] || continue
    ARTIFACT_TOTAL=$((ARTIFACT_TOTAL + 1))

    # Extract component directory name
    component_dir="$(basename "$(dirname "$latest_file")")"
    rel_path="$component_dir/latest.json"

    # Check if the file is valid JSON
    if ! jq empty "$latest_file" 2>/dev/null; then
      ARTIFACT_INVALID=$((ARTIFACT_INVALID + 1))
      printf "  ${RED}INVALID${RESET} %s — not valid JSON\n" "$rel_path"
      continue
    fi

    # Check for cockpit-v1 contract structure
    cv="$(jq -r '.contract_version // empty' "$latest_file" 2>/dev/null)"
    status="$(jq -r '.status // empty' "$latest_file" 2>/dev/null)"
    component="$(jq -r '.component // empty' "$latest_file" 2>/dev/null)"

    issues=""
    if [[ -z "$cv" ]]; then
      issues="missing contract_version"
    fi
    if [[ -z "$status" ]]; then
      issues="${issues:+$issues, }missing status"
    fi

    if [[ -n "$issues" ]]; then
      ARTIFACT_INVALID=$((ARTIFACT_INVALID + 1))
      printf "  ${RED}INVALID${RESET} %s — %s\n" "$rel_path" "$issues"
    else
      ARTIFACT_VALID=$((ARTIFACT_VALID + 1))
      printf "  ${GREEN}VALID${RESET}   %s (component=%s, status=%s)\n" "$rel_path" "${component:-n/a}" "$status"
    fi
  done

  if [[ "$ARTIFACT_TOTAL" -eq 0 ]]; then
    echo "   No latest.json artifacts found."
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "========================="
echo "${BOLD}Summary${RESET}"
printf "  Schemas:   %d valid / %d total" "$SCHEMA_VALID" "$SCHEMA_TOTAL"
if [[ "$SCHEMA_INVALID" -gt 0 ]]; then
  printf " (${RED}%d invalid${RESET})" "$SCHEMA_INVALID"
fi
echo ""

printf "  Artifacts: %d valid / %d total" "$ARTIFACT_VALID" "$ARTIFACT_TOTAL"
if [[ "$ARTIFACT_INVALID" -gt 0 ]]; then
  printf " (${RED}%d invalid${RESET})" "$ARTIFACT_INVALID"
fi
echo ""

if [[ "$SCHEMA_INVALID" -gt 0 || "$ARTIFACT_INVALID" -gt 0 ]]; then
  printf "\n${RED}Validation failures detected.${RESET}\n"
  exit 1
else
  printf "\n${GREEN}All validations passed.${RESET}\n"
  exit 0
fi
