# Kill_LIFE

Template de projet embarque IA-natif, spec-first, avec gates de qualite, evidence packs et outillage runtime pour firmware, CAD et conformite.

[![CI](https://img.shields.io/github/actions/workflow/status/electron-rare/Kill_LIFE/ci.yml?branch=main&label=CI)](https://github.com/electron-rare/Kill_LIFE/actions)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](licenses/MIT.txt)

## Principe

Kill_LIFE structure un projet embarque autour de specs testables, d'agents specialises, de gates de qualite et d'artefacts verifiables. Le depot couvre trois axes:

- firmware et CI locale/containeurisee
- CAD headless KiCad 10 first
- evidence, compliance et workflows canoniques

## Structure utile

```text
Kill_LIFE/
├── firmware/                    # Code PlatformIO
├── hardware/                    # Assets hardware et blocs
├── specs/                       # Specs et taches canoniques
├── workflows/                   # Workflows JSON canoniques + templates
├── tools/
│   ├── compliance/              # Validation compliance
│   ├── hw/                      # Stack CAD, MCP, exports, smoke
│   ├── mistral/                 # Safe patch et outils Mistral
│   └── ci/                      # Audit CI
├── deploy/cad/                  # Dockerfiles et compose CAD/runtime
├── docs/                        # Docs operateur, bridge, plans, workflows
├── test/                        # Tests Python
├── mcp.json                     # Profil MCP par defaut
└── mkdocs.yml                   # Site docs
```

## Demarrage rapide

### Prerequis

- Python 3.10+
- Docker + `docker compose`
- `gh` pour les operations GitHub
- PlatformIO en natif ou via la stack conteneurisee

### Installation

```bash
git clone https://github.com/electron-rare/Kill_LIFE.git
cd Kill_LIFE
bash install_kill_life.sh
```

### Verifications utiles

```bash
python3 tools/compliance/validate.py --strict
python3 tools/validate_specs.py --json
bash tools/hw/cad_stack.sh doctor
KILL_LIFE_PIO_MODE=container python3 tools/auto_check_ci_cd.py
```

## Workflow catalog

Les workflows editables par `crazy_life` vivent dans [`workflows/`](workflows/) et sont valides contre [`workflows/workflow.schema.json`](workflows/workflow.schema.json).

- `workflows/*.json` : workflows canoniques
- `workflows/templates/*.json` : templates de creation
- `.crazy-life/runs/` : etat des runs locaux
- `.crazy-life/backups/workflows/` : revisions et restores

## CAD et MCP

La stack CAD est documentee dans [`deploy/cad/README.md`](deploy/cad/README.md) et pilotee par [`tools/hw/cad_stack.sh`](tools/hw/cad_stack.sh).

- cible actuelle: KiCad 10 first
- launcher MCP: [`tools/hw/run_kicad_mcp.sh`](tools/hw/run_kicad_mcp.sh)
- configuration MCP: [`docs/MCP_SETUP.md`](docs/MCP_SETUP.md) et [`mcp.json`](mcp.json)

## Ecosysteme

- [`crazy_life`](https://github.com/electron-rare/crazy_life) : frontend + backend web/devops
- [`mascarade`](https://github.com/electron-rare/mascarade) : repo compagnon et bridge historique
- [`docs/MASCARADE_BRIDGE.md`](docs/MASCARADE_BRIDGE.md) : articulation locale entre les depots

## Licence

MIT. Voir [`licenses/MIT.txt`](licenses/MIT.txt).
