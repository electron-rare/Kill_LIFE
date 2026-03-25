# Mistral Forge Guide

> How Forge reviews code in the Kill_LIFE / Mascarade ecosystem

**Agent**: Forge
**Agent ID**: `ag_019d1251023f73258b80ac73f90458f6`
**Model**: `codestral-latest` (temperature 0.21)
**Domains**: finetune, dataset, training, evaluation, benchmark, data

---

## Overview

Forge is the code-oriented fine-tune and data agent of the Mascarade mesh.
Its primary responsibilities are:

1. **Code review** using Codestral for PCB/embedded/SPICE domain code
2. **Dataset validation and pipeline management** for Mistral fine-tune jobs
3. **Fine-tune job orchestration** (upload, configure, launch, monitor)
4. **Benchmark evaluation** of base vs fine-tuned models

Forge operates at temperature 0.21 -- low enough for precise code generation, with enough margin for creative problem-solving in dataset augmentation.

---

## Codestral Code Review Pipeline

### FIM (Fill-in-the-Middle) completions

Codestral supports FIM completions for inline code suggestions, integrated into Mascarade via:

- **Core route**: `/v1/api/providers/codestral/fim`
- **API facade**: `/api/providers/codestral/fim`
- **Endpoint**: `https://codestral.mistral.ai/v1/fim/completions`

This was implemented in T-MS-023 (Lot 24, session 9) directly in the Mascarade active repo at `/Users/electron/Documents/Projets/mascarade`.

### PCB review use case

Forge can review KiCad schematics, SPICE netlists, and embedded firmware through the dispatch system. It uses Codestral's code understanding to:

- Identify design rule violations in KiCad netlists
- Validate SPICE simulation parameters
- Review STM32/ESP32 firmware for common embedded pitfalls
- Check dataset quality for fine-tune pipelines

---

## Fine-tune Pipeline

### Dataset preparation tools

| Tool | Location | Purpose |
|------|----------|---------|
| `merge_datasets.sh` | `tools/mistral/merge_datasets.sh` | Merge and deduplicate JSONL datasets |
| `validate_dataset.py` | `tools/mistral/validate_dataset.py` | Validate ChatML format, count examples |
| `build_datasets.py` | `tools/mistral/build_datasets.py` | Build domain-specific datasets |
| `extract_hypnoled_datasets.py` | `tools/mistral/extract_hypnoled_datasets.py` | Extract HypnoLED-specific training data |

### Dataset domains

| Domain | Source files | Merged output | Status |
|--------|-------------|---------------|--------|
| KiCad | `build_kicad_dataset.py` outputs | `datasets/kicad_merged.jsonl` | Merged + validated |
| SPICE + Embedded | `build_spice_dataset.py` + `build_embedded_dataset.py` + `build_stm32_dataset.py` | `datasets/spice_embedded_merged.jsonl` | Merged + validated |

### Fine-tune pipeline flow

```
1. Build raw datasets
   build_datasets.py -> JSONL per domain

2. Merge and deduplicate
   merge_datasets.sh -> kicad_merged.jsonl, spice_embedded_merged.jsonl

3. Validate format
   validate_dataset.py -> ChatML format check, example count, dedup stats

4. Upload to Mistral
   mistral_studio_tui.sh --files-upload -> File IDs

5. Launch fine-tune job
   mistral_studio_tui.sh --finetune-create -> Job ID
   Hyperparameters: 100 steps, lr=1e-5

6. Monitor progress
   mistral_studio_tui.sh --finetune-list -> Status tracking

7. Validate fine-tuned model
   weekly_benchmark.sh -> Quality comparison vs baseline
```

### Fine-tune targets

| Model | Base | Target name | Domain | Status |
|-------|------|-------------|--------|--------|
| `ft:kicad-v1` | `open-mistral-7b` | KiCad specialist | PCB, schematic, DRC | Pending (T-MS-010) |
| `ft:spice-embedded-v1` | `codestral-latest` | SPICE + Embedded specialist | Analog sim, firmware | Pending (T-MS-011) |

---

## Benchmark Pipeline

### Prompt bank

**Location**: `tools/evals/prompts/metier_100_benchmark.jsonl`

100 domain-specific prompts:
- 20 KiCad prompts (schematic, PCB, DRC, BOM, scripting)
- 20 SPICE prompts (simulation, analysis, modeling)
- 20 Embedded prompts (STM32, ESP32, peripherals, RTOS)
- 20 IoT prompts (protocols, sensors, connectivity)
- 20 Mixed prompts (cross-domain integration)

### Batch benchmark (T-MS-012)

Once fine-tuned models are available:

1. Run full benchmark on base model (`codestral-latest`, `open-mistral-7b`)
2. Run full benchmark on fine-tuned model (`ft:kicad-v1`, `ft:spice-embedded-v1`)
3. Compare quality scores per domain
4. Generate comparative report

```bash
# Base model benchmark
bash tools/evals/weekly_benchmark.sh --all --model codestral-latest

# Fine-tuned model benchmark (once available)
bash tools/evals/weekly_benchmark.sh --all --model ft:kicad-v1

# Compare
bash tools/evals/weekly_benchmark.sh --compare
```

---

## Studio TUI Cockpit

**Location**: `tools/cockpit/mistral_studio_tui.sh` (referenced but created in Lot 24 T-MS-001)

The Studio TUI provides 14 actions for managing Mistral AI Studio resources:

- Agents management
- Files upload/list/delete
- Fine-tune create/list/monitor
- Batch jobs
- OCR (IA Documentaire)
- Audio (STT)
- Codestral (FIM + Chat)
- Logs

---

## Dispatch via `dispatch_to_agent.sh`

**Location**: `tools/ai/dispatch_to_agent.sh`

Forge handles domains: `finetune`, `dataset`, `training`, `evaluation`, `benchmark`, `data`.

```bash
# Fine-tune pipeline task
bash tools/ai/dispatch_to_agent.sh --lot T-MS-010 --domain finetune

# Dataset validation
bash tools/ai/dispatch_to_agent.sh --lot T-MS-002 --domain dataset

# Benchmark evaluation
bash tools/ai/dispatch_to_agent.sh --lot T-MS-012 --domain benchmark

# Local mode (zero cost)
bash tools/ai/dispatch_to_agent.sh --lot T-MS-010 --domain finetune --local
```

---

## Key files

| File | Purpose |
|------|---------|
| `tools/mistral/merge_datasets.sh` | Merge + deduplicate JSONL datasets |
| `tools/mistral/validate_dataset.py` | Validate ChatML format |
| `tools/mistral/build_datasets.py` | Build domain-specific datasets |
| `tools/evals/weekly_benchmark.sh` | Benchmark pipeline |
| `tools/evals/prompts/metier_100_benchmark.jsonl` | 100 domain prompts |
| `tools/ai/dispatch_to_agent.sh` | Agent dispatch (Forge domains) |
| `tools/mistral/beta_api_client.py` | Mistral Beta API client |
| `tools/mistral/mistral_client.py` | Mistral API client |
