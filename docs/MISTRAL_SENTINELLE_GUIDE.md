# Mistral Sentinelle Guide

> How Sentinelle monitors model health in the Kill_LIFE / Mascarade ecosystem

**Agent**: Sentinelle
**Agent ID**: `ag_019d124c302375a8bf06f9ff8a99fb5f`
**Model**: `mistral-medium-latest` (temperature 0.1)
**Domains**: ops, infra, deploy, docker, monitoring, review, audit, quality, health

---

## Overview

Sentinelle is the monitoring and operations agent of the Mascarade mesh.
Its primary responsibilities are:

1. **Daily health checks** of all ecosystem services (Mascarade, Langfuse, Grafana, Authentik, Outline, n8n, Gitea, Uptime Kuma, Portainer)
2. **Weekly model quality audits** via benchmark pipeline
3. **Alerting** on service degradation or model quality regression

Sentinelle operates with low temperature (0.1) for structured, deterministic diagnostics. It prefers JSON output and operates in an ops-monitoring or quality-audit profile depending on the task.

---

## Daily Health Check: `sentinelle_cron.sh`

**Location**: `tools/cockpit/sentinelle_cron.sh`
**Contract**: cockpit-v1
**Lot**: 23 (T-MA-022)

### What it does

1. Probes 9 core services via HTTP (mascarade, langfuse, grafana, authentik, outline, n8n, gitea, uptime-kuma, portainer)
2. Classifies overall status as `healthy`, `degraded`, or `critical` based on the ratio of healthy services
3. Sends the health report to the Sentinelle Mistral agent for AI-powered analysis
4. Fires alerts (webhook or console) when status is degraded or critical
5. Writes a dated JSON report to `/var/log/mascarade/sentinelle-health-YYYYMMDD.json`
6. Auto-cleans reports older than 30 days

### Crontab setup

```cron
# Daily at 06:00 UTC
0 6 * * * /path/to/Kill_LIFE/tools/cockpit/sentinelle_cron.sh >> /var/log/sentinelle-cron.log 2>&1
```

### Environment variables

| Variable | Description | Default |
|----------|-------------|---------|
| `MISTRAL_API_KEY` | Mistral API key for agent calls | (required for analysis) |
| `MISTRAL_GOVERNANCE_API_KEY` | Governance-scoped key (preferred) | falls back to `MISTRAL_API_KEY` |
| `MISTRAL_AGENT_SENTINELLE_ID` | Sentinelle agent ID | `ag_019d124c302375a8bf06f9ff8a99fb5f` |
| `LOG_DIR` | Report output directory | `/var/log/mascarade` |
| `ALERT_WEBHOOK` | Webhook URL (n8n, Slack) | (optional) |
| `ALERT_EMAIL` | Alert recipient email | `c.saillant@gmail.com` |
| `MASCARADE_URL` | Mascarade base URL | `https://mascarade.saillant.cc` |
| `LANGFUSE_URL` | Langfuse base URL | `https://langfuse.saillant.cc` |
| `GRAFANA_URL` | Grafana base URL | `https://grafana.saillant.cc` |

### API fallback strategy

Sentinelle cron uses a two-tier API strategy:
1. **Beta Conversations API** (`POST /v1/conversations`) — preferred, supports agent context
2. **Deprecated Completions API** (`POST /v1/agents/{id}/completions`) — fallback if beta fails

The `sentinelle_api_mode` field in the JSON report indicates which path was used (`beta`, `deprecated`, or `failed`).

### Report format (cockpit-v1)

```json
{
  "contract_version": "cockpit-v1",
  "component": "sentinelle-daily-health",
  "timestamp": "2026-03-25T06:00:00Z",
  "status": "healthy",
  "services_healthy": 9,
  "services_total": 9,
  "uptime_pct": 100,
  "checks": [ ... ],
  "sentinelle_analysis": "All services operational. No issues detected...",
  "sentinelle_api_mode": "beta"
}
```

---

## Weekly Model Quality Audit: `weekly_benchmark.sh`

**Location**: `tools/evals/weekly_benchmark.sh`
**Contract**: cockpit-v1
**Lot**: 23 (T-MA-033)

### What it does

1. Loads prompts from `tools/evals/prompts/metier_100_template.jsonl` (100 prompts across 5 domains: KiCad, SPICE, embedded, IoT, mixed)
2. Runs N prompts against a Mascarade-compatible Ollama endpoint (Tower devstral by default -- zero API cost)
3. Measures per-prompt: latency (ms), token count (input + output), quality score (keyword-match heuristic 0-10)
4. Produces a per-domain breakdown with averages
5. Auto-compares with the previous benchmark run (delta percentages)
6. Writes results to `artifacts/evals/benchmark_YYYYMMDD.json`

### Crontab setup

```cron
# Weekly on Monday at 07:00 UTC
0 7 * * 1 bash /path/to/Kill_LIFE/tools/evals/weekly_benchmark.sh --prompts 10 >> /var/log/weekly-benchmark.log 2>&1
```

### Usage examples

```bash
# Default: 10 prompts, devstral on Tower Ollama
bash tools/evals/weekly_benchmark.sh

# All 100 prompts
bash tools/evals/weekly_benchmark.sh --all

# Different model
bash tools/evals/weekly_benchmark.sh --prompts 20 --model qwen3.5:9b

# Compare last two runs (no new benchmark)
bash tools/evals/weekly_benchmark.sh --compare
```

### Quality scoring heuristic

Scores are computed on a 0-10 scale:
- **Length adequacy** (0-3 points): response length (< 100 chars = 1, < 300 = 2, >= 300 = 3)
- **Keyword hits** (0-4 points): domain-specific keyword matches (KiCad terms, SPICE terms, embedded terms, etc.)
- **Structure bonus** (0-2 points): presence of code blocks, bullet lists, headings
- **Refusal penalty** (-2 points): markers like "I cannot", "As an AI", etc.

### Domain keywords

| Domain | Keywords |
|--------|----------|
| kicad | kicad, pcb, schematic, footprint, netlist, drc, eeschema, pcbnew, symbol, copper, via, trace, pad, silkscreen |
| spice | spice, netlist, simulation, transistor, amplifier, filter, bode, gain, impedance, capacitor, inductor, diode, mosfet, opamp |
| embedded | spi, i2c, uart, gpio, dma, interrupt, register, firmware, stm32, esp32, hal, rtos, timer, adc, pwm, flash, bootloader |
| mixed | schematic, firmware, pcb, design, emc, emi, signal, power, current, voltage, sensor, protocol, bus |

---

## Weekly Cron Model Audit: `cron_model_audit.sh`

**Location**: `tools/mistral/cron_model_audit.sh`
**Contract**: cockpit-v1
**Lot**: 24 (T-MS-033)

A lightweight wrapper around `weekly_benchmark.sh` designed specifically for crontab execution. It runs 10 test prompts per model from `metier_100_benchmark.jsonl`, compares scores to baseline, and alerts if degradation exceeds 5%. See the script for full details.

### Crontab setup

```cron
# Weekly audit — Sunday 03:00 UTC
0 3 * * 0 bash /path/to/Kill_LIFE/tools/mistral/cron_model_audit.sh >> /var/log/model-audit.log 2>&1
```

---

## Integration with `dispatch_to_agent.sh`

**Location**: `tools/ai/dispatch_to_agent.sh`

Sentinelle is reachable via the dispatch system for ad-hoc monitoring tasks:

```bash
# Dispatch an ops task to Sentinelle
bash tools/ai/dispatch_to_agent.sh --lot T-MS-033 --domain ops

# Quality audit dispatch
bash tools/ai/dispatch_to_agent.sh --lot T-MS-033 --domain review

# Local Ollama mode (zero cost)
bash tools/ai/dispatch_to_agent.sh --lot T-MS-033 --domain ops --local
```

Sentinelle handles domains: `ops`, `infra`, `deploy`, `docker`, `monitoring`, `health`, `review`, `audit`, `quality`, `security`.

---

## Alert flow

```
sentinelle_cron.sh (daily 06:00)
  |
  +-> Health checks (HTTP probes)
  +-> Sentinelle agent analysis (Mistral API)
  +-> JSON report -> /var/log/mascarade/
  +-> Alert webhook (n8n / Slack) if degraded/critical
  +-> Console output for cron email

weekly_benchmark.sh (weekly Monday 07:00)
  |
  +-> Run N prompts against Ollama (zero cost)
  +-> Quality scoring + latency measurement
  +-> JSON report -> artifacts/evals/
  +-> Auto-compare with previous run

cron_model_audit.sh (weekly Sunday 03:00)
  |
  +-> Run 10 prompts per model
  +-> Compare to baseline
  +-> Alert if degradation >5%
```

---

## Key files

| File | Purpose |
|------|---------|
| `tools/cockpit/sentinelle_cron.sh` | Daily health check cron |
| `tools/evals/weekly_benchmark.sh` | Weekly benchmark pipeline |
| `tools/mistral/cron_model_audit.sh` | Weekly cron model audit (T-MS-033) |
| `tools/evals/prompts/metier_100_benchmark.jsonl` | 100 domain prompts (KiCad, SPICE, embedded, IoT, mixed) |
| `tools/ai/dispatch_to_agent.sh` | Ad-hoc agent dispatch |
| `tools/cockpit/load_mistral_governance_env.sh` | Environment loader |
