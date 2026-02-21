#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="/Users/cils/Documents/Lelectron_rare/Kill_LIFE"
ART_DIR="${ZEROCLAW_ART_DIR:-$ROOT_DIR/artifacts/zeroclaw}"
ZEROCLAW_BIN="${ZEROCLAW_BIN:-$ROOT_DIR/zeroclaw/target/release/zeroclaw}"
GATEWAY_HOST="${ZEROCLAW_GATEWAY_HOST:-127.0.0.1}"
GATEWAY_PORT="${ZEROCLAW_GATEWAY_PORT:-3000}"
FOLLOW_PORT="${ZEROCLAW_FOLLOW_PORT:-8788}"

GW_PID_FILE="$ART_DIR/gateway.pid"
FW_PID_FILE="$ART_DIR/follow.pid"
GW_LOG="$ART_DIR/gateway.log"
FW_LOG="$ART_DIR/follow.log"
TOKEN_FILE="$ART_DIR/pair_token.txt"
CONVO_FILE="$ART_DIR/conversations.jsonl"
INDEX_FILE="$ART_DIR/index.html"

mkdir -p "$ART_DIR"
touch "$CONVO_FILE"
touch "$GW_LOG"

if [[ ! -x "$ZEROCLAW_BIN" ]]; then
  if command -v zeroclaw >/dev/null 2>&1; then
    ZEROCLAW_BIN="$(command -v zeroclaw)"
  else
    echo "[fail] zeroclaw binary not found." >&2
    exit 1
  fi
fi

is_running() {
  local pid_file="$1"
  [[ -f "$pid_file" ]] || return 1
  local pid
  pid="$(cat "$pid_file" 2>/dev/null || true)"
  [[ -n "$pid" ]] || return 1
  kill -0 "$pid" >/dev/null 2>&1
}

if is_running "$GW_PID_FILE"; then
  echo "[info] gateway already running (pid $(cat "$GW_PID_FILE"))."
else
  nohup "$ZEROCLAW_BIN" gateway --port "$GATEWAY_PORT" --host "$GATEWAY_HOST" >"$GW_LOG" 2>&1 &
  echo "$!" >"$GW_PID_FILE"
fi

if is_running "$FW_PID_FILE"; then
  echo "[info] follow server already running (pid $(cat "$FW_PID_FILE"))."
else
  nohup python3 -m http.server "$FOLLOW_PORT" --bind 127.0.0.1 --directory "$ART_DIR" >"$FW_LOG" 2>&1 &
  echo "$!" >"$FW_PID_FILE"
fi

for _ in $(seq 1 40); do
  if curl -fsS "http://$GATEWAY_HOST:$GATEWAY_PORT/health" >/dev/null 2>&1; then
    break
  fi
  sleep 0.25
done

PAIR_CODE="$(grep -Eo 'X-Pairing-Code: [0-9]{6}' "$GW_LOG" 2>/dev/null | tail -1 | awk '{print $2}' || true)"
if [[ -n "$PAIR_CODE" ]]; then
  PAIR_JSON="$(curl -sS -X POST "http://$GATEWAY_HOST:$GATEWAY_PORT/pair" -H "X-Pairing-Code: $PAIR_CODE" || true)"
  TOKEN="$(printf '%s' "$PAIR_JSON" | python3 -c 'import json,sys
raw=sys.stdin.read().strip()
try:
  obj=json.loads(raw) if raw else {}
except Exception:
  obj={}
print(obj.get("token",""), end="")')"
  if [[ -n "$TOKEN" ]]; then
    printf '%s\n' "$TOKEN" >"$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"
  fi
fi

cat >"$INDEX_FILE" <<EOF
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>ZeroClaw Live Follow</title>
  <style>
    :root {
      --bg: #f7f8fa;
      --panel: #ffffff;
      --ink: #161b22;
      --muted: #5b6270;
      --line: #d7dbe2;
      --accent: #1a4f8b;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: "SF Pro Text", "Segoe UI", Arial, sans-serif;
      background: radial-gradient(circle at top, #ffffff 0%, #f2f4f8 48%, #eceff5 100%);
      color: var(--ink);
    }
    main {
      max-width: 1280px;
      margin: 0 auto;
      padding: 20px 14px 28px;
    }
    h1 {
      margin: 0 0 10px;
      font-size: 24px;
      letter-spacing: 0.2px;
    }
    .meta {
      color: var(--muted);
      font-size: 13px;
      margin-bottom: 12px;
    }
    .links {
      display: flex;
      gap: 8px;
      flex-wrap: wrap;
      margin-bottom: 14px;
    }
    .links a {
      color: var(--accent);
      text-decoration: none;
      border: 1px solid var(--line);
      background: #fff;
      border-radius: 8px;
      padding: 5px 10px;
      font-size: 13px;
    }
    .grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 12px;
    }
    .panel {
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 12px;
      min-height: 420px;
      box-shadow: 0 2px 10px rgba(17, 26, 41, 0.04);
      display: flex;
      flex-direction: column;
      overflow: hidden;
    }
    .panel h2 {
      margin: 0;
      padding: 12px 14px 10px;
      border-bottom: 1px solid var(--line);
      font-size: 16px;
    }
    .panel pre {
      margin: 0;
      padding: 12px 14px;
      overflow: auto;
      white-space: pre-wrap;
      word-break: break-word;
      font-family: ui-monospace, "SFMono-Regular", Menlo, Consolas, monospace;
      font-size: 12px;
      line-height: 1.4;
      flex: 1;
    }
    .status {
      margin-top: 10px;
      color: var(--muted);
      font-size: 12px;
    }
    @media (max-width: 980px) {
      .grid { grid-template-columns: 1fr; }
      .panel { min-height: 320px; }
    }
  </style>
</head>
<body>
  <main>
    <h1>ZeroClaw Live Follow</h1>
    <div class="meta">
      Follow URL: <code>http://127.0.0.1:$FOLLOW_PORT/</code> |
      Polling interval: <code>1s</code> |
      Display cap: <code>500 lines/panel</code>
    </div>
    <div class="links">
      <a href="/conversations.jsonl">/conversations.jsonl</a>
      <a href="/gateway.log">/gateway.log</a>
      <a href="http://$GATEWAY_HOST:$GATEWAY_PORT/health">/health</a>
      <a href="http://$GATEWAY_HOST:$GATEWAY_PORT/metrics">/metrics</a>
    </div>
    <div class="grid">
      <section class="panel">
        <h2>Conversations (JSONL live)</h2>
        <pre id="conversations">Waiting for data...</pre>
      </section>
      <section class="panel">
        <h2>Gateway log (live)</h2>
        <pre id="gateway">Waiting for data...</pre>
      </section>
    </div>
    <div class="status" id="status">Polling started...</div>
  </main>
  <script>
    const MAX_LINES = 500;
    const POLL_MS = 1000;

    let convoCount = 0;
    let gatewayCount = 0;
    let convoBuf = [];
    let gatewayBuf = [];
    let lastOk = null;

    function trimTail(lines) {
      if (lines.length <= MAX_LINES) return lines;
      return lines.slice(lines.length - MAX_LINES);
    }

    function safeText(input) {
      if (input === null || input === undefined) return "";
      return String(input);
    }

    function renderConvo(line) {
      try {
        const obj = JSON.parse(line);
        const ts = safeText(obj.ts || "");
        const repo = safeText(obj.repo_hint || "unknown");
        const msg = safeText(obj.message || "");
        const status = obj.http_status === undefined ? "-" : safeText(obj.http_status);
        const ok = obj.ok === undefined ? "-" : safeText(obj.ok);
        const raw = safeText(obj.response_raw || "");
        return "[" + ts + "] repo=" + repo + " status=" + status + " ok=" + ok + "\n> " + msg + "\n< " + raw;
      } catch (error) {
        return "[raw] " + line;
      }
    }

    function splitLines(text) {
      if (!text) return [];
      const lines = text.replace(/\r/g, "").split("\n");
      if (lines.length > 0 && lines[lines.length - 1] === "") lines.pop();
      return lines;
    }

    async function pollFile(url, kind) {
      const response = await fetch(url + "?t=" + Date.now(), { cache: "no-store" });
      if (!response.ok) {
        throw new Error(kind + " HTTP " + response.status);
      }
      const content = await response.text();
      const lines = splitLines(content);

      if (kind === "conversations") {
        if (lines.length < convoCount) {
          convoCount = 0;
          convoBuf = [];
        }
        const delta = lines.slice(convoCount).map(renderConvo);
        convoCount = lines.length;
        convoBuf = trimTail(convoBuf.concat(delta));
        document.getElementById("conversations").textContent = convoBuf.length ? convoBuf.join("\n\n") : "(empty)";
      } else {
        if (lines.length < gatewayCount) {
          gatewayCount = 0;
          gatewayBuf = [];
        }
        const delta = lines.slice(gatewayCount);
        gatewayCount = lines.length;
        gatewayBuf = trimTail(gatewayBuf.concat(delta));
        document.getElementById("gateway").textContent = gatewayBuf.length ? gatewayBuf.join("\n") : "(empty)";
      }
    }

    function setStatus(message, isError) {
      const now = new Date().toISOString();
      lastOk = !isError;
      const marker = isError ? "error" : "ok";
      document.getElementById("status").textContent = "[" + marker + "] " + message + " | updated " + now;
    }

    async function tick() {
      try {
        await Promise.all([
          pollFile("/conversations.jsonl", "conversations"),
          pollFile("/gateway.log", "gateway"),
        ]);
        setStatus("polling every " + POLL_MS + "ms", false);
      } catch (error) {
        setStatus(error.message, true);
      }
    }

    tick();
    setInterval(tick, POLL_MS);
  </script>
</body>
</html>
EOF

echo "Gateway: http://$GATEWAY_HOST:$GATEWAY_PORT/health"
echo "Follow : http://127.0.0.1:$FOLLOW_PORT/"
echo "Logs   : $GW_LOG"
echo "Token  : $TOKEN_FILE"
