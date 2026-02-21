#!/usr/bin/env bash
set -euo pipefail

ART_DIR="${ZEROCLAW_ART_DIR:-/Users/cils/Documents/Lelectron_rare/Kill_LIFE/artifacts/zeroclaw}"
HOST="${ZEROCLAW_GATEWAY_HOST:-127.0.0.1}"
PORT="${ZEROCLAW_GATEWAY_PORT:-3000}"
TOKEN_FILE="$ART_DIR/pair_token.txt"
CONVO_FILE="$ART_DIR/conversations.jsonl"

usage() {
  cat >&2 <<USAGE
Usage:
  $(basename "$0") [--repo-hint <hint>] [--allow-model-call] "message"

Options:
  --repo-hint <hint>    conversation source hint (e.g. rtc, zacus)
  --allow-model-call    required to actually send webhook requests
  -h, --help            show this help
USAGE
}

REPO_HINT="unknown"
ALLOW_MODEL_CALL=0
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

if [[ "$ALLOW_MODEL_CALL" -ne 1 ]]; then
  echo "[guard] dry guard / credit protection: add --allow-model-call to send." >&2
  exit 10
fi

TOKEN="${ZEROCLAW_BEARER:-}"
if [[ -z "$TOKEN" && -f "$TOKEN_FILE" ]]; then
  TOKEN="$(cat "$TOKEN_FILE")"
fi
if [[ -z "$TOKEN" ]]; then
  echo "[fail] no bearer token found. Start stack first or set ZEROCLAW_BEARER." >&2
  exit 2
fi

mkdir -p "$ART_DIR"
touch "$CONVO_FILE"

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
