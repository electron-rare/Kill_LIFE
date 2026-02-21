#!/usr/bin/env bash
set -euo pipefail

ART_DIR="${ZEROCLAW_ART_DIR:-/Users/cils/Documents/Lelectron_rare/Kill_LIFE/artifacts/zeroclaw}"
HOST="${ZEROCLAW_GATEWAY_HOST:-127.0.0.1}"
PORT="${ZEROCLAW_GATEWAY_PORT:-3000}"
TOKEN_FILE="$ART_DIR/pair_token.txt"
CONVO_FILE="$ART_DIR/conversations.jsonl"

if [[ $# -lt 1 ]]; then
  echo "Usage: $(basename "$0") \"message\"" >&2
  exit 1
fi

MESSAGE="$1"
TOKEN="${ZEROCLAW_BEARER:-}"
if [[ -z "$TOKEN" && -f "$TOKEN_FILE" ]]; then
  TOKEN="$(cat "$TOKEN_FILE")"
fi
if [[ -z "$TOKEN" ]]; then
  echo "[fail] no bearer token found. Start stack first or set ZEROCLAW_BEARER." >&2
  exit 2
fi

PAYLOAD="$(python3 -c 'import json,sys;print(json.dumps({"message":sys.argv[1]}))' "$MESSAGE")"
RESPONSE="$(curl -sS -X POST "http://$HOST:$PORT/webhook" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")"

TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
LINE="$(python3 -c 'import json,sys
ts,msg,resp=sys.argv[1],sys.argv[2],sys.argv[3]
print(json.dumps({"ts":ts,"message":msg,"response_raw":resp},ensure_ascii=False))' "$TS" "$MESSAGE" "$RESPONSE")"
printf '%s\n' "$LINE" >>"$CONVO_FILE"

printf '%s\n' "$RESPONSE"
