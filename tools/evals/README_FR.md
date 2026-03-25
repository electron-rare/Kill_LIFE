# T-MA-021 — Benchmark Multi-Provider Mascarade

Benchmark comparatif base models vs fine-tuned sur prompts métier électronique.

## Structure

```
evals/
├── benchmark_providers.py    # Runner principal (Mistral, Anthropic, OpenAI)
├── prompts/
│   └── metier_100_template.jsonl  # 20 prompts template (à étendre à 100)
└── results/                  # Résultats des runs (gitignored)
```

## Usage

```bash
# Dry run (pas d'appels API)
python benchmark_providers.py --prompts prompts/metier_100_template.jsonl --dry-run

# Run Mistral uniquement
python benchmark_providers.py --prompts prompts/metier_100_template.jsonl --providers mistral

# Run complet 3 providers
python benchmark_providers.py --prompts prompts/metier_100_template.jsonl --providers mistral,anthropic,openai

# Avec rate limiting adapté au free tier Anthropic (5 RPM)
python benchmark_providers.py --prompts prompts/metier_100_template.jsonl --providers anthropic --rate-limit 13
```

## Format prompts (JSONL)

```json
{"id": "K001", "domain": "kicad", "prompt": "...", "system": "...", "difficulty": "medium"}
```

## Domaines couverts

- **KiCad** (K001-K040): Schéma, PCB, DRC, symboles, empreintes
- **SPICE** (S001-S030): Simulation, netlists, analyse AC/DC/transitoire
- **Embedded** (E001-E020): Firmware STM32/ESP32, drivers, protocoles
- **Mixed** (M001-M010): Architecture hardware+firmware complète

## Env vars

```bash
export MISTRAL_API_KEY="708zM4biF4WjZIAROJh2roFiAPK9O7kG"
export ANTHROPIC_API_KEY="sk-ant-api03-..."
export OPENAI_API_KEY="sk-proj-..."
```

<iframe src="https://github.com/sponsors/electron-rare/card" title="Sponsor electron-rare" height="225" width="600" style="border: 0;"></iframe>
