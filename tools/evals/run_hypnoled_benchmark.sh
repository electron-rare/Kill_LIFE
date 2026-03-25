#!/usr/bin/env bash
# run_hypnoled_benchmark.sh — T-HP-022: Benchmark 10 Hypnoled prompts via Tower Ollama devstral
# ZERO Mistral API cost — uses local Ollama on Tower (192.168.0.120:8100)
#
# Usage:  bash tools/evals/run_hypnoled_benchmark.sh
# Output: artifacts/evals/hypnoled_benchmark_2026-03-25.json

set -euo pipefail

TOWER_HOST="clems@192.168.0.120"
MASCARADE_URL="http://localhost:8100/send"
PROVIDER="ollama"
MODEL="devstral"
TIMEOUT=90
PROMPTS_FILE="tools/evals/prompts/hypnoled_10_benchmark.jsonl"
OUTPUT_FILE="artifacts/evals/hypnoled_benchmark_2026-03-25.json"

cd "$(git rev-parse --show-toplevel)"

mkdir -p "$(dirname "$OUTPUT_FILE")"

echo "=== Hypnoled Benchmark — Tower Ollama devstral ==="
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Provider: $PROVIDER / $MODEL (local, zero API cost)"
echo ""

results=()
idx=0
total_tokens=0
successes=0
failures=0

while IFS= read -r line; do
    idx=$((idx + 1))
    domain=$(echo "$line" | python3 -c "import sys,json; print(json.load(sys.stdin)['domain'])")
    prompt=$(echo "$line" | python3 -c "import sys,json; print(json.load(sys.stdin)['prompt'])")
    keywords=$(echo "$line" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin)['expected_keywords']))")

    echo "[$idx/10] $domain: ${prompt:0:80}..."

    # Build JSON payload — escape prompt for JSON
    payload=$(python3 -c "
import json
print(json.dumps({
    'messages': [{'role': 'user', 'content': $(echo "$line" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin)['prompt']))")}],
    'provider': '$PROVIDER',
    'model': '$MODEL'
}))
")

    start_ts=$(date +%s)

    # Run on Tower via SSH
    response=$(ssh -o ConnectTimeout=10 "$TOWER_HOST" \
        "curl -s -m $TIMEOUT -X POST $MASCARADE_URL -H 'Content-Type: application/json' -d '$(echo "$payload" | sed "s/'/'\\''/g")'" 2>&1) || {
        echo "  FAIL: SSH/curl error"
        failures=$((failures + 1))
        results+=("{\"idx\":$idx,\"domain\":\"$domain\",\"status\":\"error\",\"error\":\"ssh/curl failure\",\"prompt\":$(echo "$prompt" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))")}")
        continue
    }

    end_ts=$(date +%s)
    elapsed=$((end_ts - start_ts))

    # Parse response
    parsed=$(echo "$response" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    content = d.get('content', d.get('choices', [{}])[0].get('message', {}).get('content', ''))
    usage = d.get('usage', {})
    tok = usage.get('total_tokens', usage.get('prompt_tokens', 0) + usage.get('completion_tokens', 0))
    print(json.dumps({'content': content, 'tokens': tok, 'status': 'ok'}))
except Exception as e:
    print(json.dumps({'content': '', 'tokens': 0, 'status': 'parse_error', 'error': str(e)}))
" 2>&1)

    status=$(echo "$parsed" | python3 -c "import sys,json; print(json.load(sys.stdin)['status'])")
    tokens=$(echo "$parsed" | python3 -c "import sys,json; print(json.load(sys.stdin)['tokens'])")
    content_preview=$(echo "$parsed" | python3 -c "import sys,json; print(json.load(sys.stdin)['content'][:200])")

    if [ "$status" = "ok" ]; then
        successes=$((successes + 1))
        total_tokens=$((total_tokens + tokens))
        echo "  OK — ${tokens} tokens, ${elapsed}s"
        echo "  Preview: ${content_preview:0:120}..."
    else
        failures=$((failures + 1))
        echo "  FAIL: $status"
    fi

    results+=("{\"idx\":$idx,\"domain\":\"$domain\",\"status\":\"$status\",\"tokens\":$tokens,\"elapsed_s\":$elapsed,\"prompt\":$(echo "$prompt" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))"),\"expected_keywords\":$keywords,\"content_preview\":$(echo "$content_preview" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))")}")

done < "$PROMPTS_FILE"

# Build final JSON
cat > "$OUTPUT_FILE" <<ENDJSON
{
  "benchmark": "hypnoled_10",
  "date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "provider": "$PROVIDER",
  "model": "$MODEL",
  "tower_host": "192.168.0.120",
  "api_cost": 0.0,
  "summary": {
    "total_prompts": 10,
    "successes": $successes,
    "failures": $failures,
    "total_tokens": $total_tokens
  },
  "results": [
$(IFS=,; echo "${results[*]}" | sed 's/},{/},\n    {/g' | sed 's/^/    /')
  ]
}
ENDJSON

echo ""
echo "=== Summary ==="
echo "Successes: $successes / 10"
echo "Failures:  $failures / 10"
echo "Total tokens: $total_tokens"
echo "API cost: \$0.00 (Tower Ollama)"
echo "Output: $OUTPUT_FILE"
