# MCP setup

Last updated: 2026-03-25

Source canonique pour l'usage MCP local de `Kill_LIFE`.

References canoniques:

- spec de perimetre KiCad: `specs/kicad_mcp_scope_spec.md`
- matrice de support: `docs/MCP_SUPPORT_MATRIX.md`
- matrice ecosysteme: `docs/MCP_ECOSYSTEM_MATRIX.md`
- benchmark KiCad adjacent: `docs/KICAD_BENCHMARK_MATRIX.md`
- note de lot provenance: `docs/MCP_CAD_PROVENANCE_2026-03-14.md`
- backlog MCP KiCad: `specs/mcp_tasks.md`
- backlog cible MCP/agentics: `specs/mcp_agentics_target_backlog.md`

## Source de verite et ownership

- `Kill_LIFE` own le lancement, les smokes et la gouvernance documentaire MCP locale
- `mascarade` own l'agregation ops et l'observabilite compagnon
- `specs/` a la racine de `Kill_LIFE` est la source de verite canonique
- `ai-agentic-embedded-base/specs/` n'est qu'un miroir exporte

## Provenance operatoire

- `officiel`: surface publiee par le projet ou l'organisation qui own l'outil, ou referencee via une source officielle
- `community valide`: projet tiers etabli, retenu comme reference ou benchmark
- `custom local`: launcher, wrapper, serveur ou audit maintenu dans `Kill_LIFE` ou `mascarade`
- garde-fou actif: `bash tools/tui/cad_mcp_audit.sh audit` reste obligatoire pour le lot CAD/MCP; au `2026-03-14`, le rapport documente `0 actionable hit`

## Chemins supportes

- `kicad`: `tools/hw/run_kicad_mcp.sh`
- `validate-specs`: `tools/run_validate_specs_mcp.sh`
- `knowledge-base`: `tools/run_knowledge_base_mcp.sh`
- `github-dispatch`: `tools/run_github_dispatch_mcp.sh`
- `freecad`: `tools/run_freecad_mcp.sh`
- `openscad`: `tools/run_openscad_mcp.sh`
- `ngspice`: `tools/run_ngspice_mcp.sh` — simulation SPICE via ngspice-42 (host `/usr/bin/ngspice`)
- `platformio`: `tools/run_platformio_mcp.sh` — build/test firmware ESP32-S3 via pio (`.pio-venv/`)
- `apify`: `tools/run_apify_mcp.sh` — fetch docs Espressif/KiCad/PlatformIO; mode scrape direct si `APIFY_API_KEY` absent
- `huggingface`: `https://huggingface.co/mcp`
- transport supporte: `stdio` local par defaut; l'unique exception versionnee ici est `huggingface` en endpoint `url` distant officiel

## Ce qui est reellement supporte

- `kicad`: runtime MCP CAD canonique, avec `tools`, `resources` et `prompts`
- `validate-specs`: validation repo/specs cote `Kill_LIFE`
- `knowledge-base`: MCP local de compat sur la knowledge base configuree dans `mascarade` (`memos` ou `docmost`)
- `github-dispatch`: MCP local pour workflows GitHub allowlistes
- `freecad`: MCP local headless pour infos runtime, document minimal, export et script Python controle
- `openscad`: MCP local headless pour infos runtime, validation, rendu et export
- `ngspice`: MCP local pour simulation SPICE batch — `run_simulation`, `validate_netlist`, `parse_operating_point`, `get_runtime_info`; circuits de reference dans `spice/`
- `platformio`: MCP local pour build/test firmware — `build`, `run_tests`, `check_code`, `get_metadata`, `install_platformio`; pointe sur `firmware/`; PlatformIO 6.1.19 installe dans `.pio-venv/`
- `apify`: MCP local de fetch documentaire — `fetch_espressif_docs` (12 topics ESP32-S3), `fetch_platformio_registry`, `fetch_kicad_library_info`, `ingest_to_rag`; fonctionne sans cle en mode scrape direct
- `huggingface`: surface MCP distante officielle, optionnelle et hors chaine CAD locale

Les micro-serveurs `kicad_kic_ai` de `mascarade` restent suivis comme surfaces auxiliaires dans `docs/MCP_SUPPORT_MATRIX.md`.

## Prerequis

- le repo compagnon `mascarade` existe en voisin (`../mascarade`) ou via `MASCARADE_DIR`
- les runtimes hote suivants sont auto-detectes si presents:
  - KiCad app macOS avec `kicad-cli`
  - FreeCAD app macOS avec `freecadcmd`
  - OpenSCAD CLI local; si plusieurs binaires existent, le chemin CLI stable est prefere au snapshot `.app`
- Docker reste le fallback pour `kicad`, `freecad` et `openscad`
- `node` est disponible pour le build/API compagnon
- le venv `mascarade/core/.venv` existe, ou `MASCARADE_CORE_PYTHON` pointe vers un Python avec les dependances knowledge base (`httpx`)
- `KNOWLEDGE_BASE_PROVIDER` selectionne `memos` ou `docmost`
- selon le provider:
  - `memos`: `MEMOS_BASE_URL` et `MEMOS_ACCESS_TOKEN`
  - `docmost`: `DOCMOST_BASE_URL`, `DOCMOST_EMAIL` et `DOCMOST_PASSWORD`
- `KILL_LIFE_GITHUB_TOKEN`, `GITHUB_TOKEN` ou une configuration `GitHub App` est requise pour la validation live de `github-dispatch`

## Diagnostic rapide

Depuis `Kill_LIFE`:

```bash
tools/hw/run_kicad_mcp.sh --doctor
tools/run_knowledge_base_mcp.sh --doctor
tools/run_github_dispatch_mcp.sh --doctor
tools/run_freecad_mcp.sh --doctor
tools/run_openscad_mcp.sh --doctor
tools/run_ngspice_mcp.sh --doctor
tools/run_platformio_mcp.sh --doctor
tools/run_apify_mcp.sh --doctor
python3 tools/validate_specs_mcp_smoke.py --json --quick
python3 tools/knowledge_base_mcp_smoke.py --json --quick
python3 tools/github_dispatch_mcp_smoke.py --json --quick
python3 tools/freecad_mcp_smoke.py --json
python3 tools/openscad_mcp_smoke.py --json
python3 tools/ngspice_mcp_smoke.py --json
python3 tools/platformio_mcp_smoke.py --json
python3 tools/hw/freecad_smoke.py --json
python3 tools/hw/openscad_smoke.py --json
python3 tools/mcp_runtime_status.py --json
```

Sur la machine de reference (`kxkm-ai`, 2026-03-25):

- `kicad`, `validate-specs`, `freecad`, `openscad`, `ngspice`, `platformio` et `apify` sont `ready`
- `huggingface` est `ready` avec `HUGGINGFACE_API_KEY`
- `knowledge-base` est `ready` sur le provider actif `memos` auto-heberge
- `github-dispatch` est `ready`, avec validation live fermee via token GitHub persiste
- `ngspice` valide: ngspice-42 host `/usr/bin/ngspice`, smoke OP passe (V(in)=5V RC circuit)
- `platformio` valide: PlatformIO 6.1.19 dans `.pio-venv/`, envs `esp32s3_waveshare / esp32s3_arduino / native` detectes
- `apify` valide: mode `direct-scrape-fallback`, 12 topics ESP32-S3 preconfigures

## Configuration locale

Le fichier versionne [mcp.json](../mcp.json) pointe vers les serveurs MCP reellement supportes:

```json
{
  "mcpServers": {
    "kicad": {
      "type": "local",
      "command": "bash",
      "args": ["tools/hw/run_kicad_mcp.sh"],
      "tools": ["*"]
    },
    "validate-specs": {
      "type": "local",
      "command": "bash",
      "args": ["tools/run_validate_specs_mcp.sh"],
      "tools": ["*"]
    },
    "knowledge-base": {
      "type": "local",
      "command": "bash",
      "args": ["tools/run_knowledge_base_mcp.sh"],
      "tools": ["*"]
    },
    "github-dispatch": {
      "type": "local",
      "command": "bash",
      "args": ["tools/run_github_dispatch_mcp.sh"],
      "tools": ["*"]
    },
    "freecad": {
      "type": "local",
      "command": "bash",
      "args": ["tools/run_freecad_mcp.sh"],
      "tools": ["*"]
    },
    "openscad": {
      "type": "local",
      "command": "bash",
      "args": ["tools/run_openscad_mcp.sh"],
      "tools": ["*"]
    },
    "ngspice": {
      "type": "local",
      "command": "bash",
      "args": ["tools/run_ngspice_mcp.sh"],
      "tools": ["*"]
    },
    "platformio": {
      "type": "local",
      "command": "bash",
      "args": ["tools/run_platformio_mcp.sh"],
      "tools": ["*"]
    },
    "apify": {
      "type": "local",
      "command": "bash",
      "args": ["tools/run_apify_mcp.sh"],
      "env": { "APIFY_API_KEY": "${APIFY_API_KEY}" },
      "tools": ["*"]
    },
    "huggingface": {
      "type": "url",
      "url": "https://huggingface.co/mcp",
      "headers": {
        "Authorization": "Bearer ${HUGGINGFACE_API_KEY}"
      },
      "note": "Use https://huggingface.co/mcp?login for OAuth browser login instead of token auth"
    }
  }
}
```

## Setup Mac local

Pour un poste Mac operateur, le chemin supporte est maintenant scriptable.

Prerequis:

- `Kill_LIFE` et `mascarade` clones cote a cote sur le Mac
- `codex` installe si tu veux enregistrer directement les serveurs dans Codex
- `node`, `python3` et `docker` disponibles

Bootstrap Codex en dry-run:

```bash
bash tools/bootstrap_mac_mcp.sh codex
```

Application directe sur le Mac cible:

```bash
bash tools/bootstrap_mac_mcp.sh codex --apply
```

Export d'une config JSON `mcpServers` a paths absolus:

```bash
bash tools/bootstrap_mac_mcp.sh json > ~/mcp.kill-life.mac.json
```

Ce bootstrap enregistre:

- `kicad`
- `validate-specs`
- `knowledge-base`
- `github-dispatch`
- `freecad`
- `openscad`
- `huggingface`
- `playwright`

`playwright` utilise le package officiel:

```bash
npx -y @playwright/mcp@latest
```

Le bootstrap ajoute `MASCARADE_DIR` aux launchers qui en ont besoin pour retrouver le repo compagnon depuis le Mac.

Etat de validation courant:

- syntaxe du script validee
- sortie `codex` dry-run validee localement
- sortie `json` validee localement
- bootstrap `codex --apply` execute avec succes sur le Mac operateur reel
- `codex mcp list` contient bien `kicad`, `validate-specs`, `knowledge-base`, `github-dispatch`, `freecad`, `openscad`, `huggingface` et `playwright`
- `Playwright MCP` est valide sur le Mac cible via `npx -y @playwright/mcp@latest --help`
- seul reliquat Mac connu: le worktree `/Users/electron/mascarade` est dirty, donc aucun `git pull` n'a ete force sur ce clone
- execution cible sur le Mac operateur reel validee avec enregistrement effectif des serveurs dans Codex

## Sources hote macOS retenues

- KiCad: application locale macOS detectee dans `/Applications/KiCad/KiCad.app`
- FreeCAD: releases officielles `https://github.com/FreeCAD/FreeCAD/releases`
- OpenSCAD:
  - snapshot app possible via `https://files.openscad.org/snapshots/OpenSCAD-2026.03.07.dmg`
  - pour le runtime MCP local, le binaire CLI `OpenSCAD 2021.01` est prefere quand il est installe et repond correctement en non-interactif

## Usage

Depuis `Kill_LIFE`:

```bash
tools/hw/run_kicad_mcp.sh
tools/run_validate_specs_mcp.sh
tools/run_knowledge_base_mcp.sh
tools/run_github_dispatch_mcp.sh
tools/run_freecad_mcp.sh
tools/run_openscad_mcp.sh
```

Les smokes dedies supplementaires sont:

- `tools/validate_specs_mcp_smoke.py`
- `tools/knowledge_base_mcp_smoke.py`
- `tools/github_dispatch_mcp_smoke.py`
- `tools/freecad_mcp_smoke.py`
- `tools/openscad_mcp_smoke.py`
- `tools/ngspice_mcp_smoke.py` — valide `validate_netlist` + `parse_operating_point` sur circuit RC
- `tools/platformio_mcp_smoke.py` — valide `get_metadata` sur `firmware/` si pio installe

Le chemin d'observabilite synthetique n'est pas fourni par `Kill_LIFE` seul. Si la stack compagnon `mascarade` tourne, `/api/ops/summary` expose un bloc `mcp` agrege qui remonte `kicad`, `validate-specs`, `knowledge-base`, `github-dispatch`, `freecad`, `openscad` et les surfaces distantes suivies par le cockpit.

## Politique de support

- `stdio` reste le seul transport supporte par defaut pour les surfaces locales
- aucun serveur MCP reseau n'est expose par defaut pour ces surfaces locales
- `huggingface` reste la seule surface distante officielle versionnee dans `mcp.json`
- `knowledge-base` et `github-dispatch` sont valides en live sur la machine de reference
- `freecad` et `openscad` sont supportes comme serveurs MCP headless locaux
- `kicad` reste le runtime MCP CAD principal
- les classifications `officiel` / `community valide` / `custom local` sont detaillees dans `docs/MCP_SUPPORT_MATRIX.md` et `deploy/cad/README.md`
- `docs/KICAD_BENCHMARK_MATRIX.md` fixe la decision `K-025`: `KiAuto` reste un appoint opt-in, `kicad-automation-scripts` reste une reference doc-only

## Points encore ouverts

- finir l'observabilite MCP homogene (integrer `ngspice`, `platformio`, `apify` dans `/api/ops/summary`)
- configurer `APIFY_API_KEY` pour activer le mode API Apify (scrape direct suffisant pour l'usage courant)
- requalifier l'ouverture future de `A2A` une fois l'observabilite MCP homogene fermee
- garder `K-012` comme validation host-native optionnelle tant que le runtime KiCad canonique reste le conteneur; `K-014` est valide en live, avec une limite externe de quota Nexar sur le token de reference
- si un futur lot active `KiAuto`, suivre `docs/KICAD_BENCHMARK_MATRIX.md`, rester opt-in et rejouer `bash tools/tui/cad_mcp_audit.sh audit`
