# Mistral Devstral Guide

> How Devstral assists engineering in the Kill_LIFE / Mascarade ecosystem

**Agent**: Devstral
**Agent ID**: `ag_019d125348eb77e880df33acbd395efa`
**Model**: `devstral-latest` (temperature 0.17)
**Domains**: kicad, pcb, cad, eda, firmware, embedded, esp32, stm32, spice, analog, code, dev

---

## Overview

Devstral is the engineering agent of the Mascarade mesh.
Its primary responsibilities are:

1. **PCB routing and KiCad assistance** (schematics, DRC, footprints, BOM generation)
2. **Firmware development** (STM32, ESP32, PlatformIO, RTOS, peripherals)
3. **Analog simulation** (SPICE, power design, EMC)
4. **General code generation** (Python, Bash, C/C++, refactoring, debugging)

Devstral operates at the lowest creative temperature (0.17) of all agents, optimized for precise, deterministic code generation and engineering accuracy.

---

## Access Methods

### Via Mascarade router (production)

Devstral is available as a provider in the Mascarade router:
- **Mascarade base**: `http://192.168.0.120:8042`
- Routes through the standard Mascarade API

### Via Tower Ollama (zero cost, local)

Devstral runs locally on Tower via Ollama:
- **Ollama host**: `http://192.168.0.120:11434`
- **Model**: `devstral`
- Zero API cost -- ideal for benchmarks, development, and high-volume tasks

### Via Mistral API (paid)

Direct Mistral API access:
- **Model**: `devstral-latest`
- **Agent ID**: `ag_019d125348eb77e880df33acbd395efa`
- Note: devstral-latest does not support builtin connectors (Code, Image, Search) -- API error 3004

### Via `dispatch_to_agent.sh`

```bash
# KiCad / PCB task
bash tools/ai/dispatch_to_agent.sh --lot T-RE-204 --domain kicad

# Firmware task
bash tools/ai/dispatch_to_agent.sh --lot T-RE-205 --domain firmware

# SPICE / analog task
bash tools/ai/dispatch_to_agent.sh --lot T-RE-206 --domain spice

# General coding (local Ollama, zero cost)
bash tools/ai/dispatch_to_agent.sh --lot T-RE-207 --domain code --local
```

---

## Engineering Profiles

Devstral adapts its behavior based on the dispatch domain:

### PCB Routing / KiCad (`pcb-routing-kicad`)

Domains: `kicad`, `pcb`, `cad`, `eda`, `freecad`

Specializations:
- KiCad schematic generation and review
- Footprint creation (custom connectors, QFP, BGA)
- DRC rule configuration (impedance control, clearance, thermal relief)
- BOM extraction and management scripts
- Gerber export configuration (JLCPCB, PCBWay)
- Hierarchical design with bus labels and multi-sheet schematics
- Guard rings, stitching vias, EMI shielding zones

### Firmware / Embedded (`coder-firmware`)

Domains: `firmware`, `embedded`, `esp32`, `stm32`, `platformio`, `iot`

Specializations:
- STM32 HAL/LL driver development
- ESP32 IDF and Arduino framework
- Peripheral configuration (SPI, I2C, UART, GPIO, DMA, ADC, PWM)
- RTOS task management (FreeRTOS)
- Bootloader and OTA update flows
- Power management and deep sleep modes

### Analog / Simulation (`coder-analog`)

Domains: `spice`, `analog`, `simulation`, `power`, `dsp`, `emc`

Specializations:
- SPICE netlist generation and simulation setup
- Filter design (Butterworth, Chebyshev, Sallen-Key)
- Power converter design (buck, boost, flyback)
- Amplifier analysis (gain, Bode plots, stability)
- Monte Carlo tolerance analysis
- Thermal modeling

### General Code (`coder-general`)

Domains: `code`, `dev`, `refactor`, `debug`, `python`, `bash`

Specializations:
- Python scripting (data processing, automation)
- Bash tooling (CLI tools, cron scripts)
- Code refactoring and debugging
- API client development

---

## Benchmark Performance

Devstral is the default model for the weekly benchmark pipeline:

```bash
# Run benchmark with devstral on Tower Ollama
bash tools/evals/weekly_benchmark.sh --prompts 10 --provider ollama --model devstral

# Full 100-prompt benchmark
bash tools/evals/weekly_benchmark.sh --all

# Compare with previous run
bash tools/evals/weekly_benchmark.sh --compare
```

The benchmark evaluates Devstral across all 5 domains (KiCad, SPICE, embedded, IoT, mixed) using keyword-match quality scoring (0-10 scale).

Results are stored in `artifacts/evals/benchmark_YYYYMMDD.json`.

---

## Codestral FIM Integration

For fill-in-the-middle (FIM) code completions, Devstral's sibling model Codestral is used:

- **Codestral endpoint**: `https://codestral.mistral.ai/v1/fim/completions`
- **Mascarade route**: `/v1/api/providers/codestral/fim`
- **API facade**: `/api/providers/codestral/fim`

FIM completions are useful for:
- Inline code suggestions in editors (VSCode via Continue/Tabby)
- Function body completion from signature
- Missing parameter filling in API calls
- Boilerplate generation from comments

This integration was completed in T-MS-023 (Lot 24) in the active Mascarade repo.

---

## Machine Deployment

Devstral runs on Tower (the primary compute node):

| Property | Value |
|----------|-------|
| Machine | Tower |
| IP | `192.168.0.120` |
| Ollama port | `11434` |
| Mascarade port | `8042` |
| Model | `devstral` (Ollama) / `devstral-latest` (Mistral API) |

For the 5-machine Mascarade mesh topology, refer to `reference_mascarade_machines.md` in the memory index.

---

## Key files

| File | Purpose |
|------|---------|
| `tools/ai/dispatch_to_agent.sh` | Agent dispatch (Devstral handles 12+ domains) |
| `tools/evals/weekly_benchmark.sh` | Benchmark pipeline (default: devstral on Tower) |
| `tools/evals/prompts/metier_100_benchmark.jsonl` | 100 engineering prompts |
| `tools/mistral/mistral_generate_patch.py` | Mistral-powered patch generation |
| `tools/mistral/apply_safe_patch.py` | Safe patch application |
| `tools/mistral/index_repo.py` | Repository indexing for code search |
| `tools/mistral/search_index.py` | Code search against indexed repo |
