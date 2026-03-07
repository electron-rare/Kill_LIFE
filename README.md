# Kill_LIFE

Template de projet embarque IA-natif. Architecture agentique spec-first avec gates de qualite, evidence packs et tracabilite complete.

[![CI](https://img.shields.io/github/actions/workflow/status/electron-rare/Kill_LIFE/ci.yml?branch=main&label=CI)](https://github.com/electron-rare/Kill_LIFE/actions)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](licenses/MIT.txt)

## Principe

Kill_LIFE structure un projet embarque autour de **7 agents specialises** et **7 gates de qualite**. Chaque etape produit des artefacts verifiables (evidence packs). Le workflow est concu pour l'embarque multi-cibles (ESP32, STM32, Linux) avec tracabilite et conformite integrees.

## Agents

| Agent | Responsabilite |
|-------|---------------|
| **PM / Spec** | Intention -> specs testables (acceptance criteria, risques) |
| **Architect** | Decoupe modules, interfaces, contraintes (RTOS, memoire, IO) |
| **Firmware** | Implementation multi-cibles, invariants |
| **HW** | Contraintes PCB / alimentation / signaux, checklists hardware |
| **QA / Test** | Tests unitaires + integration + smoke HIL |
| **Doc** | Runbooks, troubleshooting, changelog |
| **Compliance** | Standards, SBOM, versions, evidence pack final |

## Gates

| Gate | Objectif |
|------|----------|
| G0 - Intention | Brief valide, non-goals explicites |
| G1 - Spec | Specs testables, matrice de risques |
| G2 - Architecture | Modules definis, interfaces documentees |
| G3 - Implementation | Code compile, tests unitaires passent |
| G4 - Integration | Tests HIL, smoke tests multi-cibles |
| G5 - Doc & Compliance | Docs completes, SBOM, standards |
| G6 - Release | Evidence pack final, tag, artefacts publies |

## Structure

```
Kill_LIFE/
├── agents/                  # Definitions des agents (markdown)
├── specs/                   # Specifications par feature
├── standards/               # Standards et regles de conformite
├── firmware/                # Code embarque PlatformIO (ESP32, STM32)
├── hardware/                # Schemas KiCad, contraintes PCB
├── tools/
│   ├── ai/                  # Outils IA (generation, review)
│   ├── compliance/          # Verification conformite
│   ├── gates/               # Scripts de validation des gates
│   ├── hw/                  # Outils hardware
│   ├── mistral/             # Integration Mistral AI
│   └── cockpit/             # Dashboard local
├── openclaw/                # Module OpenClaw
├── docs/                    # Documentation, evidence packs
├── test/                    # Tests et validation
├── bmad/                    # Methodologie BMAD
├── .github/
│   ├── workflows/           # 18+ workflows CI/CD
│   ├── agents/              # Prompts agents GitHub
│   └── prompts/             # Templates de prompts
├── mcp.json                 # Configuration MCP server
├── Makefile                 # Commandes principales
└── mkdocs.yml               # Documentation MkDocs
```

## Demarrage rapide

### Prerequis

- Python 3.10+
- PlatformIO (firmware ESP32/STM32)
- KiCad (schemas hardware)

### Installation

```bash
git clone https://github.com/electron-rare/Kill_LIFE.git
cd Kill_LIFE

# Installation complete
bash install_kill_life.sh

# Ou installation minimale
pip install -r requirements-mistral.txt
```

### Commandes

```bash
make help              # Lister les commandes disponibles
make check             # Verifier la conformite
make test              # Lancer les tests
make docs              # Generer la documentation MkDocs
```

## Integration Mistral AI

Kill_LIFE utilise Mistral AI pour la generation de code et la review :

```bash
# Configuration
export MISTRAL_API_KEY=your_key

# Outils dans tools/mistral/
python tools/mistral/generate.py --spec specs/my_feature.md
```

## Ecosysteme

Ce repo fait partie de l'ecosysteme [Mascarade](https://github.com/electron-rare/mascarade) :

- **[mascarade](https://github.com/electron-rare/mascarade)** -- Orchestrateur agentique, LLM routing
- **[mascarade-datasets](https://github.com/electron-rare/mascarade-datasets)** -- Datasets de fine-tuning
- **[mascarade-cockpit](https://github.com/electron-rare/mascarade-cockpit)** -- Console ops
- **[crazy_life](https://github.com/electron-rare/crazy_life)** -- Frontend cockpit
- **[Kill_LIFE](https://github.com/electron-rare/Kill_LIFE)** -- Ce repo

## Licence

MIT -- voir [licenses/MIT.txt](licenses/MIT.txt)
