#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LANGFUSE_URL="${LANGFUSE_URL:-https://langfuse.saillant.cc}"
ARTIFACT_DIR="${ROOT_DIR}/artifacts/ops/langfuse_health"
OUTPUT_MODE="text"
TIMEOUT_SEC=10

usage() {
  cat <<'EOF'
Usage: langfuse_health.sh [options]

Options:
  --url <langfuse-url>   Langfuse instance URL (default: https://langfuse.saillant.cc)
  --artifact-dir <path>  Artifact directory (default: artifacts/ops/langfuse_health)
  --json                 Emit cockpit-v1 JSON to stdout
  --help                 Show this help
EOF
}

timestamp_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

timestamp_slug() {
  date -u +"%Y%m%dT%H%M%SZ"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --url)
      [[ $# -ge 2 ]] || { echo "Missing value for --url" >&2; exit 2; }
      LANGFUSE_URL="$2"
      shift 2
      ;;
    --artifact-dir)
      [[ $# -ge 2 ]] || { echo "Missing value for --artifact-dir" >&2; exit 2; }
      ARTIFACT_DIR="$2"
      shift 2
      ;;
    --json)
      OUTPUT_MODE="json"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

mkdir -p "$ARTIFACT_DIR"

RUN_ID="$(timestamp_slug)"
RUN_JSON="$ARTIFACT_DIR/$RUN_ID.json"
RUN_AT="$(timestamp_utc)"

HEALTH_STATUS="unknown"
HEALTH_BODY=""
DEGRADED_REASONS=()
NEXT_STEPS=()

# Check Langfuse public health endpoint
HEALTH_BODY="$(curl -s --max-time "$TIMEOUT_SEC" "${LANGFUSE_URL}/api/public/health" 2>/dev/null || true)"

if printf "%s" "$HEALTH_BODY" | grep -qi '"status"\s*:\s*"OK"'; then
  HEALTH_STATUS="ok"
elif [[ -n "$HEALTH_BODY" ]] && printf "%s" "$HEALTH_BODY" | grep -q '{'; then
  HEALTH_STATUS="degraded"
  DEGRADED_REASONS+=("Langfuse health endpoint responded but status is not OK")
  NEXT_STEPS+=("Inspect Langfuse instance at ${LANGFUSE_URL} for service issues.")
else
  HEALTH_STATUS="unreachable"
  DEGRADED_REASONS+=("Langfuse instance at ${LANGFUSE_URL} is unreachable")
  NEXT_STEPS+=("Verify Langfuse is running and accessible at ${LANGFUSE_URL}.")
fi

# Build the cockpit-v1 contract JSON
python3 - \
  "$RUN_AT" \
  "$LANGFUSE_URL" \
  "$HEALTH_STATUS" \
  "$HEALTH_BODY" \
  "$RUN_JSON" \
  --reasons \
  "${DEGRADED_REASONS[@]}" \
  --next-steps \
  "${NEXT_STEPS[@]}" \
  <<'PY' >"$RUN_JSON"
import json
import sys

run_at = sys.argv[1]
langfuse_url = sys.argv[2]
health_status = sys.argv[3]
health_body = sys.argv[4]
run_json = sys.argv[5]
tail = sys.argv[6:]

def split_sections(values):
    reasons = []
    next_steps = []
    mode = None
    for value in values:
        if value == "--reasons":
            mode = "reasons"
            continue
        if value == "--next-steps":
            mode = "next_steps"
            continue
        if mode == "reasons":
            reasons.append(value)
        elif mode == "next_steps":
            next_steps.append(value)
    return reasons, next_steps

degraded_reasons, next_steps = split_sections(tail)

# Parse health body if valid JSON
health_data = {}
try:
    health_data = json.loads(health_body) if health_body else {}
except Exception:
    pass

contract_status = "ok" if health_status == "ok" else ("degraded" if health_status == "degraded" else "error")

payload = {
    "contract_version": "cockpit-v1",
    "component": "langfuse-health",
    "action": "health-check",
    "status": health_status,
    "contract_status": contract_status,
    "checked_at": run_at,
    "langfuse_url": langfuse_url,
    "owner": "Runtime-Companion",
    "health_response": health_data,
    "langfuse_status": health_data.get("status", "unknown"),
    "langfuse_version": health_data.get("version", "unknown"),
    "artifacts": [run_json],
    "degraded_reasons": degraded_reasons,
    "next_steps": next_steps,
    "json_file": run_json,
}

print(json.dumps(payload, ensure_ascii=False, indent=2))
PY

# Copy to latest
cp "$RUN_JSON" "$ARTIFACT_DIR/latest.json"

if [[ "$OUTPUT_MODE" == "json" ]]; then
  cat "$RUN_JSON"
else
  cat <<EOF
Langfuse health
url: $LANGFUSE_URL
status: $HEALTH_STATUS
checked_at: $RUN_AT
artifacts:
  - $RUN_JSON
EOF
  if [[ ${#DEGRADED_REASONS[@]} -gt 0 ]]; then
    printf 'degraded reasons:\n'
    printf '  - %s\n' "${DEGRADED_REASONS[@]}"
  fi
fi
