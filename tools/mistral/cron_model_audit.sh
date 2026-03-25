#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────
# cron_model_audit.sh — T-MS-033: Weekly cron audit of model quality
#
# Runs 10 test prompts per model from metier_100_benchmark.jsonl,
# compares scores to a saved baseline, and alerts if degradation >5%.
# Uses Tower Ollama (zero API cost).
#
# Designed for weekly crontab:
#   0 3 * * 0 bash /path/to/Kill_LIFE/tools/mistral/cron_model_audit.sh >> /var/log/model-audit.log 2>&1
#
# Contract: cockpit-v1
# Owner: QA + Sentinelle
# Lot: 24 (T-MS-033)
# Date: 2026-03-25
# ──────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
BENCHMARK_SCRIPT="${ROOT_DIR}/tools/evals/weekly_benchmark.sh"
ARTIFACTS_DIR="${ROOT_DIR}/artifacts/evals"
BASELINE_DIR="${ARTIFACTS_DIR}/baselines"
AUDIT_LOG_DIR="${ROOT_DIR}/artifacts/evals/audits"

mkdir -p "${ARTIFACTS_DIR}" "${BASELINE_DIR}" "${AUDIT_LOG_DIR}"

# ── Configuration ────────────────────────────────────────────────────────

OLLAMA_HOST="${OLLAMA_HOST:-http://192.168.0.120:11434}"
PROMPTS_PER_MODEL=10
DEGRADATION_THRESHOLD=5  # percent
STAMP="$(date +%Y%m%d)"
AUDIT_FILE="${AUDIT_LOG_DIR}/audit_${STAMP}.json"

# Models to audit — add fine-tuned models here when available
MODELS=(
  "devstral"
  # "ft:kicad-v1"           # uncomment when deployed
  # "ft:spice-embedded-v1"  # uncomment when deployed
)

# Alerting
ALERT_WEBHOOK="${ALERT_WEBHOOK:-}"
ALERT_EMAIL="${ALERT_EMAIL:-c.saillant@gmail.com}"

# ── Functions ────────────────────────────────────────────────────────────

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [model-audit] $*"
}

run_benchmark_for_model() {
  local model="$1"
  local output_file="${ARTIFACTS_DIR}/audit_${model//[:\/]/_}_${STAMP}.json"

  log "Running ${PROMPTS_PER_MODEL} prompts for model: ${model}"

  OLLAMA_HOST="${OLLAMA_HOST}" bash "${BENCHMARK_SCRIPT}" \
    --prompts "${PROMPTS_PER_MODEL}" \
    --provider ollama \
    --model "${model}" \
    --host "${OLLAMA_HOST}" \
    --output "${output_file}" \
    2>&1 | while IFS= read -r line; do echo "  [${model}] ${line}"; done

  echo "${output_file}"
}

extract_avg_quality() {
  local json_file="$1"
  python3 -c "
import json, sys
try:
    with open('${json_file}') as f:
        data = json.load(f)
    print(data.get('summary', {}).get('avg_quality_score', 0))
except:
    print(0)
"
}

extract_summary() {
  local json_file="$1"
  python3 -c "
import json, sys
try:
    with open('${json_file}') as f:
        data = json.load(f)
    s = data.get('summary', {})
    print(json.dumps(s))
except:
    print('{}')
"
}

get_baseline() {
  local model="$1"
  local baseline_file="${BASELINE_DIR}/baseline_${model//[:\/]/_}.json"
  if [[ -f "${baseline_file}" ]]; then
    extract_avg_quality "${baseline_file}"
  else
    echo "0"
  fi
}

save_as_baseline() {
  local model="$1"
  local result_file="$2"
  local baseline_file="${BASELINE_DIR}/baseline_${model//[:\/]/_}.json"
  cp "${result_file}" "${baseline_file}"
  log "Saved new baseline for ${model}: ${baseline_file}"
}

check_degradation() {
  local model="$1"
  local current_score="$2"
  local baseline_score="$3"

  python3 -c "
import sys
current = float('${current_score}')
baseline = float('${baseline_score}')
threshold = float('${DEGRADATION_THRESHOLD}')

if baseline <= 0:
    print('no-baseline')
    sys.exit(0)

delta_pct = ((baseline - current) / baseline) * 100

if delta_pct > threshold:
    print(f'DEGRADED:{delta_pct:.1f}')
else:
    print(f'OK:{delta_pct:.1f}')
"
}

send_alert() {
  local message="$1"

  log "ALERT: ${message}"

  if [[ -n "${ALERT_WEBHOOK}" ]]; then
    curl -s -X POST "${ALERT_WEBHOOK}" \
      -H "Content-Type: application/json" \
      -d "{\"text\": \"[model-audit] ${message}\"}" \
      --max-time 10 2>/dev/null || log "Webhook alert failed"
  fi

  # Console output for cron email
  echo ""
  echo "=== MODEL AUDIT ALERT ==="
  echo "Date: $(date)"
  echo "${message}"
  echo "========================="
}

# ── Main ─────────────────────────────────────────────────────────────────

main() {
  log "Starting weekly model quality audit (${STAMP})"
  log "Models: ${MODELS[*]}"
  log "Prompts per model: ${PROMPTS_PER_MODEL}"
  log "Degradation threshold: ${DEGRADATION_THRESHOLD}%"
  log "Ollama host: ${OLLAMA_HOST}"

  local audit_results=()
  local has_alert=0

  for model in "${MODELS[@]}"; do
    log "--- Auditing: ${model} ---"

    # Run benchmark
    local result_file
    result_file="$(run_benchmark_for_model "${model}")"

    if [[ ! -f "${result_file}" ]]; then
      log "ERROR: Benchmark failed for ${model} — no output file"
      audit_results+=("{\"model\":\"${model}\",\"status\":\"error\",\"error\":\"no output file\"}")
      continue
    fi

    # Extract scores
    local current_score
    current_score="$(extract_avg_quality "${result_file}")"
    local baseline_score
    baseline_score="$(get_baseline "${model}")"
    local summary
    summary="$(extract_summary "${result_file}")"

    log "  Current score: ${current_score} | Baseline: ${baseline_score}"

    # Check degradation
    local check_result
    check_result="$(check_degradation "${model}" "${current_score}" "${baseline_score}")"

    local status="ok"
    local delta="0"

    if [[ "${check_result}" == no-baseline ]]; then
      log "  No baseline found for ${model} — saving current as baseline"
      save_as_baseline "${model}" "${result_file}"
      status="new-baseline"
    elif [[ "${check_result}" == DEGRADED:* ]]; then
      delta="${check_result#DEGRADED:}"
      status="degraded"
      has_alert=1
      send_alert "Model ${model} degraded by ${delta}% (current: ${current_score}, baseline: ${baseline_score}, threshold: ${DEGRADATION_THRESHOLD}%)"
    else
      delta="${check_result#OK:}"
      status="ok"
      log "  Status: OK (delta: ${delta}%)"

      # Update baseline if score improved
      if python3 -c "import sys; sys.exit(0 if float('${current_score}') > float('${baseline_score}') else 1)" 2>/dev/null; then
        save_as_baseline "${model}" "${result_file}"
      fi
    fi

    audit_results+=("{\"model\":\"${model}\",\"status\":\"${status}\",\"current_score\":${current_score},\"baseline_score\":${baseline_score},\"delta_pct\":${delta},\"summary\":${summary},\"result_file\":\"${result_file}\"}")
  done

  # Build audit report array
  local results_json=""
  for i in "${!audit_results[@]}"; do
    [[ "$i" -gt 0 ]] && results_json="${results_json},"
    results_json="${results_json}${audit_results[$i]}"
  done

  # Write audit report
  cat <<EOF > "${AUDIT_FILE}"
{
  "contract": "cockpit-v1",
  "tool": "cron_model_audit",
  "stamp": "${STAMP}",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "prompts_per_model": ${PROMPTS_PER_MODEL},
  "degradation_threshold_pct": ${DEGRADATION_THRESHOLD},
  "ollama_host": "${OLLAMA_HOST}",
  "models_audited": ${#MODELS[@]},
  "has_alert": $([ "${has_alert}" -eq 1 ] && echo "true" || echo "false"),
  "results": [${results_json}]
}
EOF

  log "Audit report: ${AUDIT_FILE}"
  log "Weekly model audit complete (alerts: ${has_alert})"

  # Cleanup old audits (keep 90 days)
  find "${AUDIT_LOG_DIR}" -name "audit_*.json" -mtime +90 -delete 2>/dev/null || true

  # Output JSON for cockpit-v1
  cat <<EOF
{
  "contract": "cockpit-v1",
  "component": "cron-model-audit",
  "action": "weekly-audit",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "models_audited": ${#MODELS[@]},
  "has_alert": $([ "${has_alert}" -eq 1 ] && echo "true" || echo "false"),
  "audit_file": "${AUDIT_FILE}"
}
EOF
}

# ── CLI ──────────────────────────────────────────────────────────────────

case "${1:-}" in
  --help|-h)
    cat <<'EOF'
Usage: bash tools/mistral/cron_model_audit.sh [--help]

Weekly cron audit of model quality via Tower Ollama (zero API cost).

Runs 10 test prompts per model from metier_100_benchmark.jsonl,
compares scores to a saved baseline, and alerts if degradation >5%.

Env vars:
  OLLAMA_HOST        Ollama host URL (default: http://192.168.0.120:11434)
  ALERT_WEBHOOK      Webhook URL for alerts (n8n, Slack)
  ALERT_EMAIL        Email for alerts

Crontab example:
  0 3 * * 0 bash /path/to/Kill_LIFE/tools/mistral/cron_model_audit.sh >> /var/log/model-audit.log 2>&1

Files:
  Prompts:    tools/evals/prompts/metier_100_benchmark.jsonl
  Baselines:  artifacts/evals/baselines/baseline_<model>.json
  Audits:     artifacts/evals/audits/audit_YYYYMMDD.json
  Benchmark:  tools/evals/weekly_benchmark.sh
EOF
    ;;
  *)
    main
    ;;
esac
