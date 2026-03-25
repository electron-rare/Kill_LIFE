#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────
# weekly_benchmark.sh — T-MA-033: Pipeline d'evaluation continue
#
# Runs N prompts from a JSONL template against a Mascarade-compatible
# Ollama endpoint (Tower devstral by default). No paid API calls.
#
# Measures:
#   - latency (ms)
#   - token count (input + output estimated)
#   - quality score (keyword match heuristic 0-10)
#
# Outputs:
#   artifacts/evals/benchmark_YYYYMMDD.json
#
# Usage:
#   bash tools/evals/weekly_benchmark.sh --prompts 10 --provider ollama --model devstral
#   bash tools/evals/weekly_benchmark.sh --prompts 5 --provider ollama --model qwen3.5:9b --host http://localhost:11434
#   bash tools/evals/weekly_benchmark.sh --all
#   bash tools/evals/weekly_benchmark.sh --compare
#
# Contract: cockpit-v1
# Owner: QA + PM-Mesh
# Date: 2026-03-25
# ──────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

PROMPTS_FILE="${SCRIPT_DIR}/prompts/metier_100_template.jsonl"
ARTIFACTS_DIR="${ROOT_DIR}/artifacts/evals"
mkdir -p "${ARTIFACTS_DIR}"

# Defaults — Tower Ollama (devstral), zero API cost
PROVIDER="ollama"
MODEL="devstral"
OLLAMA_HOST="${OLLAMA_HOST:-http://192.168.0.120:11434}"
MAX_PROMPTS=10
MAX_TOKENS=512
TIMEOUT=120
COMPARE_ONLY=0
RUN_ALL=0
VERBOSE=0

STAMP="$(date +%Y%m%d)"
OUTPUT_FILE="${ARTIFACTS_DIR}/benchmark_${STAMP}.json"

usage() {
  cat <<'EOF'
Usage: bash tools/evals/weekly_benchmark.sh [options]

Options:
  --prompts N         Number of prompts to run (default: 10, 0 = all)
  --provider NAME     Provider: ollama (default)
  --model NAME        Model name (default: devstral)
  --host URL          Ollama host URL (default: $OLLAMA_HOST or http://192.168.0.120:11434)
  --max-tokens N      Max output tokens (default: 512)
  --timeout N         Per-request timeout in seconds (default: 120)
  --all               Run all prompts in the template file
  --compare           Compare to previous run only (no new benchmark)
  --output FILE       Override output file path
  --verbose           Print each prompt/response
  --help              Show this help

Examples:
  bash tools/evals/weekly_benchmark.sh --prompts 10 --provider ollama --model devstral
  bash tools/evals/weekly_benchmark.sh --all --model qwen3.5:9b
  bash tools/evals/weekly_benchmark.sh --compare
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompts)    MAX_PROMPTS="${2:-10}"; shift 2 ;;
    --provider)   PROVIDER="${2:-ollama}"; shift 2 ;;
    --model)      MODEL="${2:-devstral}"; shift 2 ;;
    --host)       OLLAMA_HOST="${2:-}"; shift 2 ;;
    --max-tokens) MAX_TOKENS="${2:-512}"; shift 2 ;;
    --timeout)    TIMEOUT="${2:-120}"; shift 2 ;;
    --all)        RUN_ALL=1; shift ;;
    --compare)    COMPARE_ONLY=1; shift ;;
    --output)     OUTPUT_FILE="${2:-}"; shift 2 ;;
    --verbose)    VERBOSE=1; shift ;;
    --help|-h)    usage; exit 0 ;;
    *)            echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ "${RUN_ALL}" -eq 1 ]]; then
  MAX_PROMPTS=0
fi

# ── Compare helper ─────────────────────────────────────────────────────

find_previous_run() {
  local current="$1"
  local prev=""
  for f in "${ARTIFACTS_DIR}"/benchmark_*.json; do
    [[ -f "$f" ]] || continue
    [[ "$f" == "$current" ]] && continue
    if [[ -z "$prev" || "$f" > "$prev" ]]; then
      prev="$f"
    fi
  done
  echo "${prev}"
}

compare_runs() {
  local current="$1"
  local previous="$2"

  if [[ ! -f "$previous" ]]; then
    echo "[compare] No previous run found to compare against."
    return 0
  fi

  python3 - "$current" "$previous" <<'PY'
import json
import sys

def load(path):
    with open(path) as f:
        return json.load(f)

current = load(sys.argv[1])
previous = load(sys.argv[2])

cs = current.get("summary", {})
ps = previous.get("summary", {})

print(f"\n{'='*60}")
print(f"  COMPARISON: {current.get('stamp', '?')} vs {previous.get('stamp', '?')}")
print(f"{'='*60}")

metrics = [
    ("avg_latency_ms", "Avg latency (ms)", True),
    ("avg_quality_score", "Avg quality score", False),
    ("avg_output_tokens", "Avg output tokens", False),
    ("success_count", "Success count", False),
    ("error_count", "Error count", True),
]

for key, label, lower_is_better in metrics:
    cv = cs.get(key, 0)
    pv = ps.get(key, 0)
    if pv > 0:
        delta_pct = ((cv - pv) / pv) * 100
    else:
        delta_pct = 0
    direction = "better" if (lower_is_better and cv < pv) or (not lower_is_better and cv > pv) else "worse" if cv != pv else "same"
    print(f"  {label:<25} {pv:>10.1f} -> {cv:>10.1f}  ({delta_pct:+.1f}% {direction})")

print(f"{'='*60}\n")
PY
}

if [[ "${COMPARE_ONLY}" -eq 1 ]]; then
  if [[ -f "${OUTPUT_FILE}" ]]; then
    prev="$(find_previous_run "${OUTPUT_FILE}")"
    compare_runs "${OUTPUT_FILE}" "${prev}"
  else
    echo "[compare] No current run file found at ${OUTPUT_FILE}"
    # Find the two most recent
    latest=""
    second=""
    for f in "${ARTIFACTS_DIR}"/benchmark_*.json; do
      [[ -f "$f" ]] || continue
      if [[ -z "$latest" || "$f" > "$latest" ]]; then
        second="$latest"
        latest="$f"
      elif [[ -z "$second" || "$f" > "$second" ]]; then
        second="$f"
      fi
    done
    if [[ -n "$latest" && -n "$second" ]]; then
      compare_runs "$latest" "$second"
    else
      echo "[compare] Need at least 2 benchmark files to compare."
      exit 1
    fi
  fi
  exit 0
fi

# ── Benchmark runner ───────────────────────────────────────────────────

echo "Weekly Benchmark — ${STAMP}"
echo "  Provider: ${PROVIDER}"
echo "  Model: ${MODEL}"
echo "  Host: ${OLLAMA_HOST}"
echo "  Prompts file: ${PROMPTS_FILE}"
echo "  Max prompts: ${MAX_PROMPTS} (0 = all)"
echo "  Max tokens: ${MAX_TOKENS}"
echo "  Output: ${OUTPUT_FILE}"
echo ""

if [[ ! -f "${PROMPTS_FILE}" ]]; then
  echo "ERROR: Prompts file not found: ${PROMPTS_FILE}" >&2
  exit 1
fi

python3 - \
  "${PROMPTS_FILE}" \
  "${OUTPUT_FILE}" \
  "${PROVIDER}" \
  "${MODEL}" \
  "${OLLAMA_HOST}" \
  "${MAX_PROMPTS}" \
  "${MAX_TOKENS}" \
  "${TIMEOUT}" \
  "${VERBOSE}" \
  "${STAMP}" \
<<'PYEOF'
import json
import sys
import time
import urllib.request
import urllib.error
import re
from datetime import datetime

prompts_file = sys.argv[1]
output_file = sys.argv[2]
provider = sys.argv[3]
model = sys.argv[4]
ollama_host = sys.argv[5].rstrip("/")
max_prompts = int(sys.argv[6])
max_tokens = int(sys.argv[7])
timeout = int(sys.argv[8])
verbose = sys.argv[9] == "1"
stamp = sys.argv[10]

# ── Load prompts ──────────────────────────────────────────────────────

prompts = []
with open(prompts_file) as f:
    for line in f:
        line = line.strip()
        if line:
            prompts.append(json.loads(line))

if max_prompts > 0:
    prompts = prompts[:max_prompts]

total = len(prompts)
print(f"  Loaded {total} prompts")

# ── Quality score heuristic ───────────────────────────────────────────

DOMAIN_KEYWORDS = {
    "kicad": ["kicad", "pcb", "schematic", "footprint", "netlist", "drc", "eeschema", "pcbnew", "symbol", "copper", "via", "trace", "pad", "silkscreen"],
    "spice": ["spice", "netlist", "simulation", "transistor", "amplifier", "filter", "bode", "gain", "impedance", "capacitor", "inductor", "diode", "mosfet", "opamp"],
    "embedded": ["spi", "i2c", "uart", "gpio", "dma", "interrupt", "register", "firmware", "stm32", "esp32", "hal", "rtos", "timer", "adc", "pwm", "flash", "bootloader"],
    "mixed": ["schematic", "firmware", "pcb", "design", "emc", "emi", "signal", "power", "current", "voltage", "sensor", "protocol", "bus"],
}

def compute_quality_score(prompt_data, response_text):
    """Keyword-match heuristic: 0-10 scale."""
    if not response_text or len(response_text.strip()) < 20:
        return 0.0

    domain = prompt_data.get("domain", "mixed")
    keywords = DOMAIN_KEYWORDS.get(domain, DOMAIN_KEYWORDS["mixed"])
    response_lower = response_text.lower()

    # Base: response length adequacy (0-3 points)
    length = len(response_text)
    if length < 100:
        length_score = 1.0
    elif length < 300:
        length_score = 2.0
    else:
        length_score = 3.0

    # Keyword hits (0-4 points)
    hits = sum(1 for kw in keywords if kw in response_lower)
    keyword_score = min(4.0, (hits / max(len(keywords), 1)) * 8.0)

    # Structure bonus (0-2 points): code blocks, lists, headings
    structure_score = 0.0
    if "```" in response_text:
        structure_score += 1.0
    if re.search(r"^[-*]\s", response_text, re.MULTILINE):
        structure_score += 0.5
    if re.search(r"^#+\s", response_text, re.MULTILINE):
        structure_score += 0.5

    # Penalty for refusal or generic responses
    penalty = 0.0
    refusal_markers = ["i cannot", "je ne peux pas", "as an ai", "en tant qu'ia", "i'm sorry", "je suis desole"]
    for marker in refusal_markers:
        if marker in response_lower:
            penalty += 2.0
            break

    score = min(10.0, max(0.0, length_score + keyword_score + structure_score - penalty))
    return round(score, 1)

# ── Ollama call ───────────────────────────────────────────────────────

def call_ollama(prompt_text, system_text):
    url = f"{ollama_host}/api/chat"
    messages = []
    if system_text:
        messages.append({"role": "system", "content": system_text})
    messages.append({"role": "user", "content": prompt_text})

    payload = json.dumps({
        "model": model,
        "messages": messages,
        "stream": False,
        "options": {
            "num_predict": max_tokens,
        },
    }).encode()

    req = urllib.request.Request(url, data=payload, headers={"Content-Type": "application/json"})
    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = json.loads(resp.read().decode())
        latency_ms = (time.time() - t0) * 1000

        content = body.get("message", {}).get("content", "")
        eval_count = body.get("eval_count", 0)
        prompt_eval_count = body.get("prompt_eval_count", 0)

        return {
            "response": content,
            "latency_ms": round(latency_ms, 1),
            "input_tokens": prompt_eval_count,
            "output_tokens": eval_count,
            "error": None,
        }
    except Exception as e:
        latency_ms = (time.time() - t0) * 1000
        return {
            "response": "",
            "latency_ms": round(latency_ms, 1),
            "input_tokens": 0,
            "output_tokens": 0,
            "error": str(e),
        }

# ── Run benchmark ─────────────────────────────────────────────────────

results = []
success_count = 0
error_count = 0
total_latency = 0.0
total_quality = 0.0
total_output_tokens = 0

for idx, prompt_data in enumerate(prompts, 1):
    pid = prompt_data.get("id", f"P{idx:03d}")
    prompt_text = prompt_data["prompt"]
    system_text = prompt_data.get("system", "")
    domain = prompt_data.get("domain", "unknown")
    difficulty = prompt_data.get("difficulty", "unknown")

    print(f"  [{idx}/{total}] {pid} ({domain}/{difficulty})...", end=" ", flush=True)

    resp = call_ollama(prompt_text, system_text)

    quality = compute_quality_score(prompt_data, resp["response"])

    result = {
        "prompt_id": pid,
        "domain": domain,
        "difficulty": difficulty,
        "provider": provider,
        "model": model,
        "latency_ms": resp["latency_ms"],
        "input_tokens": resp["input_tokens"],
        "output_tokens": resp["output_tokens"],
        "quality_score": quality,
        "error": resp["error"],
        "prompt_preview": prompt_text[:120],
        "response_preview": resp["response"][:200] if resp["response"] else "",
    }
    results.append(result)

    if resp["error"]:
        error_count += 1
        print(f"ERROR: {resp['error'][:60]}")
    else:
        success_count += 1
        total_latency += resp["latency_ms"]
        total_quality += quality
        total_output_tokens += resp["output_tokens"]
        print(f"OK ({resp['latency_ms']:.0f}ms, {resp['output_tokens']} tok, score={quality})")

    if verbose and resp["response"]:
        print(f"    -> {resp['response'][:300]}")

# ── Summary ───────────────────────────────────────────────────────────

summary = {
    "total_prompts": total,
    "success_count": success_count,
    "error_count": error_count,
    "avg_latency_ms": round(total_latency / max(success_count, 1), 1),
    "avg_quality_score": round(total_quality / max(success_count, 1), 2),
    "avg_output_tokens": round(total_output_tokens / max(success_count, 1), 1),
    "total_output_tokens": total_output_tokens,
}

# Per-domain breakdown
domain_stats = {}
for r in results:
    d = r["domain"]
    if d not in domain_stats:
        domain_stats[d] = {"count": 0, "success": 0, "total_latency": 0, "total_quality": 0}
    domain_stats[d]["count"] += 1
    if not r["error"]:
        domain_stats[d]["success"] += 1
        domain_stats[d]["total_latency"] += r["latency_ms"]
        domain_stats[d]["total_quality"] += r["quality_score"]

for d, s in domain_stats.items():
    sc = max(s["success"], 1)
    domain_stats[d] = {
        "count": s["count"],
        "success": s["success"],
        "avg_latency_ms": round(s["total_latency"] / sc, 1),
        "avg_quality_score": round(s["total_quality"] / sc, 2),
    }

# ── Write output ──────────────────────────────────────────────────────

report = {
    "contract": "cockpit-v1",
    "tool": "weekly_benchmark",
    "stamp": stamp,
    "timestamp": datetime.now().isoformat(),
    "provider": provider,
    "model": model,
    "host": ollama_host,
    "max_tokens": max_tokens,
    "summary": summary,
    "domain_breakdown": domain_stats,
    "results": results,
}

with open(output_file, "w") as f:
    json.dump(report, f, indent=2, ensure_ascii=False)

print(f"\n{'='*60}")
print(f"  BENCHMARK COMPLETE — {stamp}")
print(f"{'='*60}")
print(f"  Provider: {provider} / {model}")
print(f"  Prompts:  {total} ({success_count} OK, {error_count} errors)")
print(f"  Avg latency: {summary['avg_latency_ms']:.0f} ms")
print(f"  Avg quality: {summary['avg_quality_score']:.1f} / 10")
print(f"  Avg tokens:  {summary['avg_output_tokens']:.0f}")
print(f"  Output: {output_file}")
print(f"{'='*60}")
PYEOF

# ── Auto-compare with previous run ────────────────────────────────────

prev_file="$(find_previous_run "${OUTPUT_FILE}")"
if [[ -n "${prev_file}" && -f "${prev_file}" ]]; then
  echo ""
  compare_runs "${OUTPUT_FILE}" "${prev_file}"
fi

echo "[weekly_benchmark] Done."
