#!/usr/bin/env bash
set -euo pipefail

MODEL="${ZEROCLAW_OLLAMA_MODEL:-llama3.2:1b}"
DO_PULL=1
DO_WARMUP=1
APPLY_MAC_ENV=0

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--model <name>] [--no-pull] [--no-warmup] [--apply-macos-env]

Options:
  --model <name>        Ollama model to pull/warm (default: ${MODEL})
  --no-pull             Skip model pull
  --no-warmup           Skip warmup request
  --apply-macos-env     Apply launchctl env tuning for macOS Ollama service
  -h, --help            Show this help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model)
      MODEL="${2:-}"
      shift 2
      ;;
    --no-pull)
      DO_PULL=0
      shift
      ;;
    --no-warmup)
      DO_WARMUP=0
      shift
      ;;
    --apply-macos-env)
      APPLY_MAC_ENV=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[fail] unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if ! command -v brew >/dev/null 2>&1; then
  echo "[fail] Homebrew is required on macOS for automated Ollama setup." >&2
  exit 1
fi

if ! command -v ollama >/dev/null 2>&1; then
  echo "[step] installing ollama via brew"
  brew install ollama
fi

if [[ "$(uname -s)" == "Darwin" ]]; then
  if [[ "$APPLY_MAC_ENV" == "1" ]]; then
    echo "[step] applying launchctl env tuning for Ollama"
    launchctl setenv OLLAMA_FLASH_ATTENTION "1" || true
    launchctl setenv OLLAMA_KV_CACHE_TYPE "q8_0" || true
    launchctl setenv OLLAMA_MAX_LOADED_MODELS "1" || true
    launchctl setenv OLLAMA_NUM_PARALLEL "1" || true
  fi
  echo "[step] starting ollama service"
  brew services start ollama >/dev/null 2>&1 || true
else
  echo "[step] starting ollama daemon"
  nohup ollama serve >/tmp/ollama-serve.log 2>&1 &
fi

for _ in $(seq 1 20); do
  if ollama list >/dev/null 2>&1; then
    break
  fi
  sleep 0.5
done

if ! ollama list >/dev/null 2>&1; then
  echo "[fail] ollama daemon is not reachable." >&2
  exit 2
fi

if [[ "$DO_PULL" == "1" ]]; then
  echo "[step] pull model: $MODEL"
  ollama pull "$MODEL"
fi

if [[ "$DO_WARMUP" == "1" ]]; then
  echo "[step] warmup model: $MODEL"
  python3 - "$MODEL" <<'PY'
import json
import sys
import urllib.request

model = sys.argv[1]
payload = json.dumps({
    "model": model,
    "prompt": "Reply with exactly: ready",
    "stream": False,
}).encode("utf-8")
req = urllib.request.Request(
    "http://127.0.0.1:11434/api/generate",
    data=payload,
    headers={"Content-Type": "application/json"},
    method="POST",
)
with urllib.request.urlopen(req, timeout=120) as resp:
    body = json.loads(resp.read().decode("utf-8", errors="replace"))
print(body.get("response", "").strip())
PY
fi

echo "[ok] local Ollama setup complete."
echo "[hint] credit-saving defaults:"
echo "  export ZEROCLAW_PREFER_LOCAL_AI=1"
echo "  export ZEROCLAW_OLLAMA_MODEL=\"$MODEL\""
