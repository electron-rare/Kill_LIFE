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

### Bootstrap Python repo-local

```bash
bash tools/bootstrap_python_env.sh
```

Options utiles:
- `--venv-dir /tmp/kill-life-venv` pour verifier le bootstrap sur une machine ou un environnement vierge
- `--reinstall` pour recreer proprement le venv cible

Le chemin supporte pour le Python du repo est `./.venv/bin/python`.

### Tests Python repo-local

```bash
bash tools/test_python.sh
```

Ce chemin couvre la suite Python repo-locale stable (`setup_repo`, `mcp_runtime_status`, `openclaw_sanitizer`, `apply_safe_patch`, `validate_specs`, `tools/hw/schops/tests`) sans dependre du `python3` systeme.
Les checks dependants du mirror specs ou des runtimes MCP restent des commandes d'integration separees.

Options utiles:
- `--suite stable` pour le chemin repo-local supporte par defaut
- `--suite mcp` pour les tests MCP locaux (`notion`, `github-dispatch`, `nexar`)
- `--suite all` pour enchainer les deux
- `--bootstrap` pour creer le venv cible avant de lancer les tests
- `--list` pour afficher exactement les commandes couvertes

Exemple de verification sur un venv temporaire:

```bash
bash tools/test_python.sh --bootstrap --venv-dir /tmp/kill-life-venv --suite stable
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

- [`crazy_life`](https://github.com/electron-rare/crazy_life) : repo canonique web/devops
- [`mascarade`](https://github.com/electron-rare/mascarade) : repo compagnon/orchestration et bridge historique optionnel
- [`docs/MASCARADE_BRIDGE.md`](docs/MASCARADE_BRIDGE.md) : articulation locale entre les depots

Contrat multi-repo:
- `crazy_life` publie la surface web/devops et le workflow editor.
- `Kill_LIFE` reste la source de verite pour `workflows/*.json`, le runtime, les evidence packs, le firmware, le CAD et la compliance.
- `mascarade` ne redevient pas la source canonique de release web; le bridge reste un mecanisme de sync seulement.

## CI et release

- `.github/workflows/ci.yml` porte le gate repo-local stable: bootstrap Python + `bash tools/test_python.sh --suite stable`.
- `.github/workflows/release_signing.yml` reste le workflow de release versionnee; il attend un tag `v*` ou un `workflow_dispatch` avec `release_tag` explicite.
- GitHub Pages n'est pas un gate canonique pour la release `Crazy Lane`; les workflows Pages de `Kill_LIFE` restent des surfaces secondaires docs/evidence.

## Licence

MIT. Voir [`licenses/MIT.txt`](licenses/MIT.txt).
