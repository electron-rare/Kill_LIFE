#!/usr/bin/env bash
set -euo pipefail

load_local_env() {
  local env_file="${ZEROCLAW_ENV_FILE:-$HOME/.zeroclaw/env}"
  [[ -f "$env_file" ]] || return 0
  chmod 600 "$env_file" >/dev/null 2>&1 || true
  set -a
  # shellcheck disable=SC1090
  source "$env_file"
  set +a
}

load_local_env

ART_DIR="${ZEROCLAW_ART_DIR:-/Users/cils/Documents/Lelectron_rare/Kill_LIFE/artifacts/zeroclaw}"
HOST="${ZEROCLAW_GATEWAY_HOST:-127.0.0.1}"
PORT="${ZEROCLAW_GATEWAY_PORT:-3000}"
TOKEN_FILE="$ART_DIR/pair_token.txt"
CONVO_FILE="$ART_DIR/conversations.jsonl"
BUDGET_FILE="$ART_DIR/webhook_budget.json"
MAX_CALLS_PER_HOUR="${ZEROCLAW_WEBHOOK_MAX_CALLS_PER_HOUR:-40}"
MAX_CHARS="${ZEROCLAW_WEBHOOK_MAX_CHARS:-1200}"

usage() {
  cat >&2 <<USAGE
Usage:
  $(basename "$0") [--repo-hint <hint>] [--allow-model-call] [--dry-run] "message"

Options:
  --repo-hint <hint>    conversation source hint (e.g. rtc, zacus)
  --allow-model-call    legacy option (no longer required)
  --dry-run             validate payload and limits without network send
  -h, --help            show this help
USAGE
}

REPO_HINT="unknown"
ALLOW_MODEL_CALL=0
DRY_RUN=0
MESSAGE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-hint)
      if [[ $# -lt 2 ]]; then
        echo "[fail] --repo-hint requires a value." >&2
        usage
        exit 1
      fi
      REPO_HINT="$2"
      shift 2
      ;;
    --allow-model-call)
      ALLOW_MODEL_CALL=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      MESSAGE="$*"
      break
      ;;
    -*)
      echo "[fail] unknown option: $1" >&2
      usage
      exit 1
      ;;
    *)
      MESSAGE="$*"
      break
      ;;
  esac
done

if [[ -z "$MESSAGE" ]]; then
  usage
  exit 1
fi

if [[ "$ALLOW_MODEL_CALL" -eq 1 ]]; then
  echo "[info] --allow-model-call accepted (legacy no-op)." >&2
fi

TOKEN="${ZEROCLAW_BEARER:-}"
if [[ -z "$TOKEN" && -f "$TOKEN_FILE" ]]; then
  TOKEN="$(cat "$TOKEN_FILE")"
fi

mkdir -p "$ART_DIR"
touch "$CONVO_FILE"

MESSAGE_CHARS="$(python3 -c 'import sys;print(len(sys.argv[1]))' "$MESSAGE")"
if (( MESSAGE_CHARS > MAX_CHARS )); then
  echo "[budget] message length ${MESSAGE_CHARS} exceeds ZEROCLAW_WEBHOOK_MAX_CHARS=${MAX_CHARS}." >&2
  exit 11
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "[dry-run] payload validated; no network call performed."
  echo "[dry-run] repo_hint=$REPO_HINT chars=$MESSAGE_CHARS"
  exit 0
fi

if [[ -z "$TOKEN" ]]; then
  echo "[fail] no bearer token found. Start stack first or set ZEROCLAW_BEARER." >&2
  exit 2
fi

if ! python3 - "$BUDGET_FILE" "$MAX_CALLS_PER_HOUR" <<'PY'
import json
import os
import sys
import time

path = sys.argv[1]
max_calls = int(sys.argv[2])
now = int(time.time())
window_start = now - 3600

state = {"calls": []}
if os.path.exists(path):
  try:
    with open(path, "r", encoding="utf-8") as f:
      loaded = json.load(f)
    if isinstance(loaded, dict):
      state = loaded
  except Exception:
    state = {"calls": []}

calls = []
for item in state.get("calls", []):
  try:
    ts = int(float(item))
  except Exception:
    continue
  if ts >= window_start:
    calls.append(ts)

if max_calls > 0 and len(calls) >= max_calls:
  print(f"[budget] hourly call limit reached: {len(calls)}/{max_calls}", file=sys.stderr)
  sys.exit(1)

calls.append(now)
tmp_path = path + ".tmp"
with open(tmp_path, "w", encoding="utf-8") as f:
  json.dump({"calls": calls}, f, ensure_ascii=False, indent=2)
os.replace(tmp_path, path)
print(f"[budget] calls in last hour: {len(calls)}/{max_calls}", file=sys.stderr)
PY
then
  exit 12
fi

PAYLOAD="$(python3 -c 'import json,sys;print(json.dumps({"message":sys.argv[1]}))' "$MESSAGE")"
TMP_BODY="$(mktemp)"
HTTP_STATUS="$(curl -sS -o "$TMP_BODY" -w "%{http_code}" -X POST "http://$HOST:$PORT/webhook" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" || true)"
RESPONSE="$(cat "$TMP_BODY" 2>/dev/null || true)"
rm -f "$TMP_BODY"

if [[ "$HTTP_STATUS" =~ ^2[0-9][0-9]$ ]]; then
  OK_BOOL="true"
else
  OK_BOOL="false"
fi

TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
LINE="$(python3 -c 'import json,sys
ts,repo,msg,http_status,ok_bool,resp=sys.argv[1],sys.argv[2],sys.argv[3],sys.argv[4],sys.argv[5],sys.argv[6]
status = int(http_status) if http_status.isdigit() else http_status
ok = ok_bool.lower() == "true"
print(json.dumps({
  "ts": ts,
  "repo_hint": repo,
  "message": msg,
  "http_status": status,
  "ok": ok,
  "response_raw": resp
}, ensure_ascii=False))' "$TS" "$REPO_HINT" "$MESSAGE" "$HTTP_STATUS" "$OK_BOOL" "$RESPONSE")"
printf '%s\n' "$LINE" >>"$CONVO_FILE"

printf '%s\n' "$RESPONSE"

if [[ "$OK_BOOL" != "true" ]]; then
  echo "[warn] webhook failed with HTTP status: $HTTP_STATUS" >&2
  exit 3
fi
