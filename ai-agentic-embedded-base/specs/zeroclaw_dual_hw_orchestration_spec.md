# Spec: ZeroClaw Dual-Repo + Dual-Hardware Orchestration

Last updated: 2026-02-21

## 1) Goal

Run one orchestration layer that can:

- converse against `RTC_BL_PHONE` and `le-mystere-professeur-zacus` independently,
- keep workspace boundaries strict per repo,
- run low-cost autonomous loops with guarded command allowlists,
- enforce upload/flash/serial-monitor loops by default on connected hardware.

## 2) Scope

In scope:

- local ZeroClaw profile bootstrap for both repos,
- deterministic workspace switch (`rtc` vs `zacus`) from one CLI entrypoint,
- hardware discovery/introspection preflight,
- forced-by-default firmware loop (build + upload + monitor) per repo target,
- lightweight CI validation for orchestration scripts/spec.

Out of scope:

- storing provider secrets in git,
- hard-coding serial ports in committed config,
- forcing hardware jobs on GitHub-hosted runners.

## 3) Current Hardware Snapshot (local)

Detected at bootstrap time:

- `CP2102 USB to UART Bridge Controller` (`10c4:ea60`)
- `USB Single Serial` (`1a86:55d3`)

Known candidate ports:

- `/dev/tty.SLAB_USBtoUART`
- `/dev/tty.usbserial-0001`
- `/dev/tty.usbmodem5AB90753301`

## 4) Architecture

### 4.1 Repo-local ZeroClaw profile

Each repo gets:

- `<repo>/.zeroclaw/config.toml`

Runtime workspace selection is done via:

- `ZEROCLAW_WORKSPACE=<repo>`

This keeps `autonomy.workspace_only = true` effective on a per-repo boundary.

### 4.2 Orchestrator scripts

- `tools/ai/zeroclaw_dual_bootstrap.sh`
  - writes/refreshes both repo profiles,
  - archives legacy root `config.toml` + `workspace/` if they match old ZeroClaw layout,
  - validates ZeroClaw binary availability,
  - runs `zeroclaw status` for both workspaces,
  - runs `zeroclaw hardware discover`.
- `tools/ai/zeroclaw_dual_chat.sh`
  - target switch by alias (`rtc`, `zacus`) or absolute path,
  - message mode (`-m`) or interactive mode,
  - `--cheap` mode to prefer local provider routing for low-credit runs,
  - loads local auth env file `~/.zeroclaw/env` when present,
  - provider auto-fallback (`ollama` when local preferred -> `copilot` -> `openai-codex` -> `gemini` -> `openrouter` -> `anthropic` -> `openai`),
  - token sourcing from `gh auth token` at runtime only when `copilot` is selected.
- `tools/ai/zeroclaw_stack_up.sh`
  - starts local gateway and local follow server,
  - reuses existing listeners when ports are already bound (prevents duplicate-start failures),
  - loads local auth env file `~/.zeroclaw/env` when present,
  - auto-aligns gateway provider/model for autonomous cost control:
    - default uses `openai-codex` when auth profile exists (reliable baseline),
    - optionally prefers local `ollama` when `ZEROCLAW_PREFER_LOCAL_AI=1`,
    - otherwise uses `openrouter` when API key exists,
  - writes reliability fallback chain in config (`ollama -> openai-codex -> openrouter` when available),
  - attempts automatic gateway pairing and token refresh,
  - validates bearer token with a malformed webhook probe (`{}` payload) and re-pairs when possible,
  - generates live follow dashboard at `http://127.0.0.1:8788/`,
  - dashboard includes live polling panels for `/conversations.jsonl` and `/gateway.log` (1s polling),
  - preserves direct raw links: `/conversations.jsonl` and `/gateway.log`,
  - starts `tools/ai/zeroclaw_watch_1min.sh` watcher and exposes `/realtime_1min.log`,
  - writes `artifacts/zeroclaw/prometheus.yml` scrape config,
  - supports local Prometheus startup via `ZEROCLAW_PROM_MODE` (`off`, `auto`, `binary`, `docker`) with `auto` fallback `binary -> docker`,
  - on macOS, auto-attempts Docker Desktop startup before Prometheus docker mode,
  - stores pair token in `artifacts/zeroclaw/pair_token.txt`.
- `tools/ai/zeroclaw_stack_down.sh`
  - stops local gateway/follow processes,
  - stops local Prometheus process/container if managed by the stack,
  - stops `tools/ai/zeroclaw_watch_1min.sh` watcher process,
  - confirms logs remain in `artifacts/zeroclaw/`.
- `tools/ai/zeroclaw_watch_1min.sh`
  - supports `start|stop|status|run|once`,
  - appends one status line every 60s by default to `artifacts/zeroclaw/realtime_1min.log`,
  - line format:
    - `<ts> | paired=<...> | uptime=<...> | prom=<...> | convo=<last line> | gateway=<last line>`
- `tools/ai/zeroclaw_hw_firmware_loop.sh`
  - target switch `rtc|zacus`,
  - validates `platformio.ini` env exists before running,
  - forces `build -> upload -> serial monitor` by default,
  - auto-retries with a compatible env when chip mismatch is detected (`ESP32` vs `ESP32-S3`),
  - auto-detects serial port when not specified,
  - on macOS, wraps monitor with `script` pseudo-TTY to avoid `termios` non-interactive failures,
  - monitor timeout default 60s.
- `tools/ai/ollama_local_setup.sh`
  - installs `ollama` via Homebrew when missing,
  - starts local service,
  - optionally pulls/warms a local model,
  - prints zero-credit defaults for stack usage.
- `tools/ai/zeroclaw_webhook_send.sh`
  - sends webhook by default (no mandatory allow flag),
  - keeps `--allow-model-call` as backward-compatible legacy option,
  - supports `--dry-run` to validate payload/limits without network send,
  - enforces autonomous local quotas with `artifacts/zeroclaw/webhook_budget.json`,
  - supports `--repo-hint <hint>` metadata tagging,
  - appends enriched JSONL traces to `artifacts/zeroclaw/conversations.jsonl`.

### 4.3 Provider/cost strategy

Auto provider selection order in `zeroclaw_dual_chat.sh`:

1. explicit `ZEROCLAW_PROVIDER` override,
2. `ollama` when `ZEROCLAW_PREFER_LOCAL_AI=1` and local model is available,
3. `copilot` when `gh` auth is valid and Copilot billing endpoint is accessible,
4. `openai-codex` when a ZeroClaw auth profile exists,
5. `gemini` when `GEMINI_API_KEY`/`GOOGLE_API_KEY` is present,
6. `openrouter` when `OPENROUTER_API_KEY` is present,
7. `anthropic` when `ANTHROPIC_API_KEY`/`ANTHROPIC_OAUTH_TOKEN` is present,
8. `openai` when `OPENAI_API_KEY` is present.

Gateway bootstrap provider order in `zeroclaw_stack_up.sh`:

1. `openai-codex` when auth profile exists (default mode),
2. `openrouter` when `OPENROUTER_API_KEY` exists,
3. `ollama` only when `ZEROCLAW_PREFER_LOCAL_AI=1` and local model is available.

Observed on current machine:

- GitHub API returned `404` for Copilot billing endpoint (no active Copilot subscription on this token), so fallback path is required for autonomous chat.

## 5) Operations Loop

1. Bootstrap configs and hardware probe.
2. Run one focused prompt in `rtc`.
3. Run one focused prompt in `zacus`.
4. Apply patches/tests per repo.
5. Open small PRs + issue links (one concern per PR).
6. Repeat.

## 6) CI Workflow

Workflow:

- `.github/workflows/zeroclaw_dual_orchestrator.yml`

Behavior:

- path-filtered on orchestration scripts/spec files,
- shellcheck scripts,
- verify spec/todo files exist,
- concurrency enabled to cancel stale runs on same ref.

## 7) External References (optimization decisions)

- GitHub Actions path filters and trigger controls:  
  https://docs.github.com/actions/reference/workflows-and-actions/workflow-syntax
- GitHub Actions concurrency control (cancel stale runs):  
  https://docs.github.com/actions/using-jobs/using-concurrency
- PlatformIO remote unit test runner and local/remote split strategy:  
  https://docs.platformio.org/en/latest/plus/remote/unit-testing.html
- PySerial port metadata usage (`serial.tools.list_ports`) for stable device targeting:  
  https://pyserial.readthedocs.io/en/latest/tools.html

## 8) Live Follow Contract

Follow URL:

- `http://127.0.0.1:8788/` (dashboard)

Raw URLs:

- `http://127.0.0.1:8788/conversations.jsonl`
- `http://127.0.0.1:8788/gateway.log`
- `http://127.0.0.1:8788/realtime_1min.log`
- `http://127.0.0.1:8788/prometheus.yml`

Conversation JSONL line schema (append-only):

- `ts` (ISO UTC)
- `repo_hint` (`rtc`, `zacus`, or custom hint; default `unknown`)
- `message`
- `http_status`
- `ok` (boolean)
- `response_raw`

Compatibility rule:

- viewer tolerates legacy lines that only contain `ts`, `message`, `response_raw`.

Webhook execution and cost controls:

- webhook send is enabled by default.
- `--dry-run` performs validation only (no network call, no execution log append).
- hourly quota and message-size limits are enforced by environment variables:
  - `ZEROCLAW_WEBHOOK_MAX_CALLS_PER_HOUR` (default: `40`)
  - `ZEROCLAW_WEBHOOK_MAX_CHARS` (default: `1200`)
- quota state is stored in `artifacts/zeroclaw/webhook_budget.json`.

## 9) Prometheus Integration

Economical default:

- `ZEROCLAW_PROM_MODE=auto` (try local `prometheus` binary first, then Docker fallback)

Optional modes:

- `ZEROCLAW_PROM_MODE=off` disables Prometheus startup
- `ZEROCLAW_PROM_MODE=binary` requires local `prometheus` binary
- `ZEROCLAW_PROM_MODE=docker` runs `prom/prometheus:latest` locally
- `ZEROCLAW_DOCKER_WAIT_SECS` controls Docker daemon wait timeout (default: `90`)
- `ZEROCLAW_PROM_READY_WAIT_SECS` controls Prometheus readiness wait (default: `15`)

Default local endpoint when running:

- `http://127.0.0.1:9090/targets`

## 10) Local Auth Bootstrap

Recommended local secret file:

- `~/.zeroclaw/env` (permissions `600`)

Suggested contents:

- `OPENROUTER_API_KEY=...`

Behavior:

- `zeroclaw_dual_chat.sh`, `zeroclaw_stack_up.sh`, and `zeroclaw_webhook_send.sh` auto-load this file if present.

## 11) Firmware Loop Defaults (local hardware)

Default execution policy:

- with hardware connected, upload/flash and serial monitor are forced by default.
- if no serial port is detected, loop fails fast (non-zero) instead of silently skipping upload.
- only declared PlatformIO envs are allowed; no `-e native` or `-e test` shortcuts.

Default commands:

- RTC:
  - `tools/ai/zeroclaw_hw_firmware_loop.sh rtc`
- Zacus:
  - `tools/ai/zeroclaw_hw_firmware_loop.sh zacus`
