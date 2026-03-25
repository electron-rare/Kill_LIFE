# Mascarade Agents Documentation

> **T-MA-023** | Plan 23 — Integration Mistral Agents
> **Date**: 2026-03-25
> **Owner**: PM-Mesh + Architect

---

## Overview

Mascarade operates a multi-agent architecture spanning 4 categories, 4 Mistral AI Studio agents, and 18 local Ollama profiles. Agents are dispatched based on domain, task complexity, and host availability across a 5-machine mesh.

**Architecture layers:**
1. **Mistral AI Studio agents** (4) — cloud-hosted, specialized, Beta Conversations API
2. **Mascarade Ollama profiles** (18) — local/mesh, zero-cost, domain-tuned system prompts
3. **Mascarade Tower profiles** (4) — Tower-specific heavy workloads (code, text, research, analysis)

---

## Section 1: Sentinelle (Monitoring & Ops)

Sentinelle handles infrastructure monitoring, incident detection, health diagnostics, and operational triage.

### Mistral AI Studio Agent

| Field | Value |
|-------|-------|
| Name | Sentinelle |
| Agent ID | `ag_019d124c302375a8bf06f9ff8a99fb5f` |
| Model | `mistral-medium-latest` |
| Temperature | 0.1 |
| Builtin tools | Code, Recherche |
| Category | Monitoring & Ops |

**Description**: Low-temperature ops agent producing structured JSON diagnostics. Connected to Mascarade /health, /providers, /metrics endpoints via `sentinelle_connector.py`. Integrates Langfuse traces/scores and Grafana Prometheus queries.

**MCP Tools (7)**:
- `mascarade_health` — Runtime health check
- `mascarade_providers` — Provider status and availability
- `mascarade_metrics` — Performance metrics and latency
- `langfuse_traces` — LLM call tracing
- `langfuse_scores` — Quality scoring and evaluation
- `prometheus_queries` — CPU, RAM, disk via Grafana
- `full_diagnostic` — Combined diagnostic report

**Cron**: `sentinelle_cron.sh` runs daily at 06:00 with webhook alerting.

### Mascarade Ollama Profiles

| Profile ID | Model | Temp | Max Tokens | Use Case |
|-----------|-------|------|------------|----------|
| `ops` | mascarade-power:latest | 0.1 | 850 | Runbooks, incident response, logs, service recovery |
| `analysis` | mascarade-power:latest | 0.15 | 850 | Repo analysis, runtime triage, incident synthesis |
| `security` | qwen2.5:14b | 0.1 | 950 | Threat review, hardening, secret handling |
| `mesh-syncops` | mascarade-power:latest | 0.1 | 900 | Mesh alignment, SSH health, load balancing |
| `fallback-safe` | qwen2.5:7b | 0.1 | 500 | Degraded mode, provider outage, safe continuation |

### API Usage

**Via Mistral Beta Conversations API:**
```bash
curl -X POST https://api.mistral.ai/v1/conversations \
  -H "Authorization: Bearer $MISTRAL_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "agent_id": "ag_019d124c302375a8bf06f9ff8a99fb5f",
    "inputs": [{"role": "user", "content": "Run a full system diagnostic. Output JSON."}]
  }'
```

**Via cockpit:**
```bash
bash tools/cockpit/e2e_agents_test.sh --action sentinelle
bash tools/cockpit/sentinelle_cron.sh
```

**Via dispatch:**
```bash
bash tools/ai/dispatch_to_agent.sh --lot T-XX-001 --domain ops
bash tools/ai/dispatch_to_agent.sh --lot T-XX-001 --domain monitoring --local
```

---

## Section 2: Tower (Knowledge & Content)

Tower handles knowledge management, content production, commercial communications, and research synthesis.

### Mistral AI Studio Agent

| Field | Value |
|-------|-------|
| Name | Tower |
| Agent ID | `ag_019d124e760877359ad3ff5031179ebc` |
| Model | `magistral-medium-latest` |
| Temperature | 0.4 |
| Builtin tools | Recherche, Image |
| Category | Knowledge & Content |

**Description**: Higher-creativity agent for long-form content, email templates, commercial proposals, and documentation. Connected to Outline wiki via `tower_outline_connector.py` with RAG document library planned (MistralLibraryClient).

**MCP Tools (5)**:
- `outline_search` — Full-text search across Outline wiki
- `outline_get_document` — Retrieve specific document
- `outline_product_lookup` — Product documentation lookup
- `outline_training_lookup` — Training material search
- `outline_list_collections` — Browse wiki collections

**Email Templates (7)**:
- `premier_contact_inbound` — Inbound lead first contact
- `premier_contact_outbound` — Outbound prospecting
- `followup_post_demo` — Post-demo follow-up
- `proposition_commerciale` — Commercial proposal
- `formation_kicad` — KiCad training invitation
- `relance_30j` — 30-day reminder
- `relance_60j` — 60-day reminder

### Mascarade Ollama Profiles

| Profile ID | Model | Temp | Max Tokens | Use Case |
|-----------|-------|------|------------|----------|
| `docs` | qwen3.5:9b | 0.25 | 1000 | README, specs, runbooks, changelogs |
| `docs-specs` | qwen3.5:9b | 0.2 | 1100 | Specifications, Mermaid diagrams, feature maps |
| `web-research` | qwen3.5:9b | 0.1 | 900 | Source review, comparison, evidence summaries |
| `site` | qwen3.5:9b | 0.35 | 650 | Frontend, copy, navigation, content structure |
| `planning` | qwen2.5:14b | 0.2 | 950 | Roadmaps, todo lists, owner mapping |
| `reflection` | qwen2.5:14b | 0.2 | 900 | Tradeoffs, decision support, failure analysis |

### Tower-Specific Profiles (tower host)

| Profile | Model | Temp | Dispatch Class | Use Case |
|---------|-------|------|----------------|----------|
| `tower-code` | CodeV-R1-Qwen-7B (IQ4_XS) | 0.1 | heavy | Heavy code, refactor, integration |
| `tower-text` | mistral:7b | 0.3 | medium | Long text, synthesis, README |
| `tower-research` | llm-compiler-7b | 0.2 | heavy | Research, source analysis |
| `tower-analysis` | llm-compiler-7b | 0.15 | heavy | Structured reasoning, architecture |

### API Usage

**Via Mistral Beta Conversations API:**
```bash
curl -X POST https://api.mistral.ai/v1/conversations \
  -H "Authorization: Bearer $MISTRAL_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "agent_id": "ag_019d124e760877359ad3ff5031179ebc",
    "inputs": [{"role": "user", "content": "Generate a first-contact email for a KiCad prospect."}]
  }'
```

**Via cockpit:**
```bash
bash tools/cockpit/e2e_agents_test.sh --action tower
bash tools/cockpit/mistral_agents_tui.sh  # then select Tower
```

**Via dispatch:**
```bash
bash tools/ai/dispatch_to_agent.sh --lot T-XX-001 --domain docs
bash tools/ai/dispatch_to_agent.sh --lot T-XX-001 --domain email --local
```

---

## Section 3: Forge (Code & Fine-tune Pipeline)

Forge handles dataset quality assessment, fine-tune pipeline management, and code-level evaluation tasks.

### Mistral AI Studio Agent

| Field | Value |
|-------|-------|
| Name | Forge |
| Agent ID | `ag_019d1251023f73258b80ac73f90458f6` |
| Model | `codestral-latest` |
| Temperature | 0.21 |
| Builtin tools | None (codestral does not support builtin connectors, error 3004) |
| Category | Fine-tune & Data |

**Description**: Code-oriented agent focused on dataset validation, training pipeline orchestration, and quality scoring. Works with the 10-domain dataset suite (KiCad, SPICE, FreeCAD, STM32, embedded, IoT, EMC, DSP, power, PlatformIO).

**Datasets Managed (10 domains)**:
| Domain | Builder | Examples |
|--------|---------|----------|
| KiCad | build_datasets.py | 56 |
| SPICE | build_datasets.py | 48 |
| FreeCAD | build_datasets.py | 63 |
| STM32 | build_datasets.py | 51 |
| Embedded | build_datasets.py | 49 |
| IoT | build_datasets.py | 53 |
| EMC | build_datasets.py | 59 |
| DSP | build_datasets.py | 58 |
| Power | build_datasets.py | 63 |
| PlatformIO | build_datasets.py | 49 |

**Pipeline**: `mistral_dataset_pipeline.py` — merge, validate, upload, finetune (3 domains: kicad, spice-embedded, full).

### Mascarade Ollama Profiles

| Profile ID | Model | Temp | Max Tokens | Use Case |
|-----------|-------|------|------------|----------|
| `fine-tune` | qwen3.5:9b | 0.2 | 1050 | Dataset shaping, distillation, LoRA planning, evaluation |
| `code` | mascarade-coder:latest | 0.15 | 700 | Implementation, debug, review, refactor |

### API Usage

**Via Mistral Beta Conversations API:**
```bash
curl -X POST https://api.mistral.ai/v1/conversations \
  -H "Authorization: Bearer $MISTRAL_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "agent_id": "ag_019d1251023f73258b80ac73f90458f6",
    "inputs": [{"role": "user", "content": "Evaluate this JSONL dataset: 5700 examples, 12 duplicates, KiCad EDA domain. Score /10."}]
  }'
```

**Via cockpit:**
```bash
bash tools/cockpit/e2e_agents_test.sh --action forge
bash tools/cockpit/dataset_audit_tui.sh --action audit
```

**Via dispatch:**
```bash
bash tools/ai/dispatch_to_agent.sh --lot T-MA-021 --domain finetune
bash tools/ai/dispatch_to_agent.sh --lot T-MA-021 --domain benchmark --local
```

---

## Section 4: Devstral (Embedded & Engineering)

Devstral handles code generation, firmware development, PCB routing, EDA workflows, and engineering tasks.

### Mistral AI Studio Agent

| Field | Value |
|-------|-------|
| Name | Devstral-Code |
| Agent ID | `ag_019d125348eb77e880df33acbd395efa` |
| Model | `devstral-latest` |
| Temperature | 0.17 |
| Builtin tools | None (devstral does not support builtin connectors, error 3004) |
| Category | Code & Engineering |

**Description**: Low-temperature engineering agent for precise code generation, firmware debugging, PCB routing assistance, and SPICE simulation. Primary agent for Kill_LIFE firmware (ESP32/PlatformIO) and YiACAD (KiCad/FreeCAD).

**CI Integration**: `devstral-review.yml` — GitHub Actions PR review workflow, automatic code review on pull requests.

### Mascarade Ollama Profiles

| Profile ID | Model | Temp | Max Tokens | Use Case |
|-----------|-------|------|------------|----------|
| `firmware` | mascarade-platformio:latest | 0.1 | 900 | PlatformIO, ESP32, runtime triage, memory issues |
| `cad` | mascarade-kicad:latest | 0.15 | 950 | KiCad, FreeCAD, MCP tooling, design workflow |
| `kill-life-firmware` | mascarade-platformio:latest | 0.1 | 950 | Kill_LIFE firmware, ESP32, PlatformIO |
| `yiacad-cad` | mascarade-kicad:latest | 0.15 | 1050 | YiACAD, KiCad, FreeCAD, CAD AI native |
| `local-fast` | qwen3:4b | 0.2 | 256 | Triage, short replies, quick checks |

### API Usage

**Via Mistral Beta Conversations API:**
```bash
curl -X POST https://api.mistral.ai/v1/conversations \
  -H "Authorization: Bearer $MISTRAL_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "agent_id": "ag_019d125348eb77e880df33acbd395efa",
    "inputs": [{"role": "user", "content": "Review this SPI driver code and suggest improvements for DMA support."}]
  }'
```

**Via cockpit:**
```bash
bash tools/cockpit/e2e_agents_test.sh --action devstral
bash tools/cockpit/mistral_agents_tui.sh  # then select Devstral
```

**Via dispatch:**
```bash
bash tools/ai/dispatch_to_agent.sh --lot T-RE-204 --domain firmware
bash tools/ai/dispatch_to_agent.sh --lot T-XX-001 --domain kicad --local
```

---

## Cross-Agent Workflows

### Handoff Pattern: Sentinelle -> Devstral

Used for automated incident detection and fix generation:

1. Sentinelle receives a log/error and produces a structured diagnostic
2. Diagnostic is forwarded to Devstral with a fix request
3. Devstral generates a code patch

```bash
# Via cockpit
bash tools/cockpit/e2e_agents_test.sh --action handoff

# Via TUI
bash tools/cockpit/mistral_agents_tui.sh  # action: handoff
```

### Lot Dispatch Pattern

The `dispatch_to_agent.sh` script routes lots to the correct agent based on domain:

```bash
# Cloud API dispatch
bash tools/ai/dispatch_to_agent.sh --lot T-MA-033 --domain docs

# Local Ollama dispatch (zero cost)
bash tools/ai/dispatch_to_agent.sh --lot T-RE-204 --domain firmware --local --local-model devstral

# Dry run
bash tools/ai/dispatch_to_agent.sh --lot T-MA-021 --domain benchmark --dry-run

# List all agent mappings
bash tools/ai/dispatch_to_agent.sh --list-agents
```

### Mascarade Provider Integration

The `MistralAgentsProvider` in the Mascarade runtime routes requests through the Beta Conversations API:

- Provider name: `mistral-agents`
- Config: `MISTRAL_AGENTS_API_MODE` (beta/deprecated)
- Agent IDs: `MISTRAL_AGENT_SENTINELLE_ID`, `MISTRAL_AGENT_TOWER_ID`, `MISTRAL_AGENT_FORGE_ID`, `MISTRAL_AGENT_DEVSTRAL_ID`
- Location: `/Users/electron/Documents/Projets/mascarade/core/mascarade/router/providers/mistral_agents.py`

---

## Mesh Deployment

5-machine mesh with Mascarade runtime:

| Machine | SSH Target | Ollama Port | Role |
|---------|-----------|-------------|------|
| Tower | clems@192.168.0.120 | 11434 | Primary Ollama host, heavy models |
| KXKM-AI | kxkm@kxkm-ai | 11434 | Secondary Ollama, domain profiles |
| Root | root@192.168.0.119 | 11434 | Docker runtime, Mascarade API |
| Cils | cils@100.126.225.111 | 11434 | macOS node, fallback |
| Local | localhost | 11434 | Development machine |

**Mascarade roots per machine:**
- Tower: `/home/clems/mascarade`
- Root: `/root/mascarade-main`
- KXKM-AI: `/home/kxkm/mascarade`
- Cils: `/Users/cils/mascarade-main`

---

## Evaluation & Benchmarks

### Weekly Benchmark (T-MA-033)

```bash
# Run 10 prompts against Tower Ollama devstral
bash tools/evals/weekly_benchmark.sh --prompts 10 --provider ollama --model devstral

# Run all prompts
bash tools/evals/weekly_benchmark.sh --all

# Compare with previous run
bash tools/evals/weekly_benchmark.sh --compare
```

Output: `artifacts/evals/benchmark_YYYYMMDD.json`

### E2E Agent Tests (T-MA-025)

```bash
# Run all agent tests
bash tools/cockpit/e2e_agents_test.sh --action all --json

# Run specific agent
bash tools/cockpit/e2e_agents_test.sh --action sentinelle
```

### Multi-Provider Benchmark (T-MA-021)

```bash
# Full benchmark across Mistral, Anthropic, OpenAI
python tools/evals/benchmark_providers.py --prompts tools/evals/prompts/metier_100_template.jsonl --output results/ --dry-run
```

---

## Configuration Reference

### Environment Variables

| Variable | Purpose | Source |
|----------|---------|--------|
| `MISTRAL_API_KEY` | Mascarade router key | `.env` / Mascarade |
| `MISTRAL_GOVERNANCE_API_KEY` | Kill_LIFE governance key | `~/.kill-life/mistral.env` |
| `MISTRAL_AGENTS_API_KEY` | Agents API key (legacy) | `.env` |
| `MISTRAL_AGENT_SENTINELLE_ID` | Sentinelle agent ID | `.env` |
| `MISTRAL_AGENT_TOWER_ID` | Tower agent ID | `.env` |
| `MISTRAL_AGENT_FORGE_ID` | Forge agent ID | `.env` |
| `MISTRAL_AGENT_DEVSTRAL_ID` | Devstral agent ID | `.env` |
| `MISTRAL_AGENTS_API_MODE` | beta / deprecated | config.py |
| `OLLAMA_HOST` | Local Ollama endpoint | env |
| `OPENAI_API_KEY` | OpenAI provider key | `.env` |
| `ANTHROPIC_API_KEY` | Anthropic provider key | `.env` |

### Key Files

| File | Purpose |
|------|---------|
| `tools/cockpit/e2e_agents_test.sh` | E2E agent test suite |
| `tools/cockpit/sentinelle_cron.sh` | Daily Sentinelle health-check |
| `tools/cockpit/mistral_agents_tui.sh` | Agent TUI (Beta API) |
| `tools/cockpit/mascarade_dispatch_mesh.sh` | Mesh dispatch routing |
| `tools/ai/dispatch_to_agent.sh` | Lot-to-agent dispatch |
| `tools/evals/weekly_benchmark.sh` | Weekly evaluation pipeline |
| `tools/evals/benchmark_providers.py` | Multi-provider benchmark |
| `specs/contracts/mascarade_model_profiles.kxkm_ai.json` | 18 Ollama profiles |
| `specs/contracts/mascarade_model_profiles.tower.json` | 4 Tower profiles |
| `specs/contracts/mascarade_dispatch.mesh.json` | Mesh dispatch rules |
