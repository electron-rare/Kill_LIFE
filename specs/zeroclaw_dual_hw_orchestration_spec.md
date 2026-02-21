# Spec: ZeroClaw Dual-Repo + Dual-Hardware Orchestration

Last updated: 2026-02-21

## 1) Goal

Run one orchestration layer that can:

- converse against `RTC_BL_PHONE` and `le-mystere-professeur-zacus` independently,
- keep workspace boundaries strict per repo,
- run low-cost autonomous loops with guarded command allowlists,
- stay ready for connected hardware checks before any upload/flash action.

## 2) Scope

In scope:

- local ZeroClaw profile bootstrap for both repos,
- deterministic workspace switch (`rtc` vs `zacus`) from one CLI entrypoint,
- hardware discovery/introspection preflight,
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
  - provider auto-fallback (`copilot` -> `openai-codex` -> `openrouter`),
  - token sourcing from `gh auth token` at runtime only when `copilot` is selected.
- `tools/ai/zeroclaw_stack_up.sh`
  - starts local gateway and local follow server,
  - reuses existing listeners when ports are already bound (prevents duplicate-start failures),
  - generates live follow dashboard at `http://127.0.0.1:8788/`,
  - dashboard includes live polling panels for `/conversations.jsonl` and `/gateway.log` (1s polling),
  - preserves direct raw links: `/conversations.jsonl` and `/gateway.log`,
  - writes `artifacts/zeroclaw/prometheus.yml` scrape config,
  - supports local Prometheus startup via `ZEROCLAW_PROM_MODE` (`off`, `auto`, `binary`, `docker`),
  - stores pair token in `artifacts/zeroclaw/pair_token.txt`.
- `tools/ai/zeroclaw_stack_down.sh`
  - stops local gateway/follow processes,
  - stops local Prometheus process/container if managed by the stack,
  - confirms logs remain in `artifacts/zeroclaw/`.
- `tools/ai/zeroclaw_webhook_send.sh`
  - requires `--allow-model-call` before any real webhook send,
  - supports `--repo-hint <hint>` metadata tagging,
  - appends enriched JSONL traces to `artifacts/zeroclaw/conversations.jsonl`.

### 4.3 Provider/cost strategy

Auto provider selection order in `zeroclaw_dual_chat.sh`:

1. explicit `ZEROCLAW_PROVIDER` override,
2. `copilot` when `gh` auth is valid and Copilot billing endpoint is accessible,
3. `openai-codex` when a ZeroClaw auth profile exists,
4. `openrouter` when `OPENROUTER_API_KEY` is present.

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

Credit-protection rule:

- without `--allow-model-call`, `zeroclaw_webhook_send.sh` exits non-zero and does not send/write logs.

## 9) Prometheus Integration

Economical default:

- `ZEROCLAW_PROM_MODE=auto` (start only if local `prometheus` binary exists)

Optional modes:

- `ZEROCLAW_PROM_MODE=off` disables Prometheus startup
- `ZEROCLAW_PROM_MODE=binary` requires local `prometheus` binary
- `ZEROCLAW_PROM_MODE=docker` runs `prom/prometheus:latest` locally

Default local endpoint when running:

- `http://127.0.0.1:9090/targets`
