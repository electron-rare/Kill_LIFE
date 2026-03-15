# MCP setup

Last updated: 2026-03-14

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
- `huggingface`: `https://huggingface.co/mcp`
- transport supporte: `stdio` local par defaut; l'unique exception versionnee ici est `huggingface` en endpoint `url` distant officiel

## Ce qui est reellement supporte

- `kicad`: runtime MCP CAD canonique, avec `tools`, `resources` et `prompts`
- `validate-specs`: validation repo/specs cote `Kill_LIFE`
- `knowledge-base`: MCP local de compat sur la knowledge base configuree dans `mascarade` (`memos` ou `docmost`)
- `github-dispatch`: MCP local pour workflows GitHub allowlistes
- `freecad`: MCP local headless pour infos runtime, document minimal, export et script Python controle
- `openscad`: MCP local headless pour infos runtime, validation, rendu et export
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
python3 tools/validate_specs_mcp_smoke.py --json --quick
python3 tools/knowledge_base_mcp_smoke.py --json --quick
python3 tools/github_dispatch_mcp_smoke.py --json --quick
python3 tools/freecad_mcp_smoke.py --json
python3 tools/openscad_mcp_smoke.py --json
python3 tools/hw/freecad_smoke.py --json
python3 tools/hw/openscad_smoke.py --json
python3 tools/mcp_runtime_status.py --json
```

Sur la machine de reference:

- `kicad`, `validate-specs`, `freecad`, `openscad` et `huggingface` sont `ready`
- `knowledge-base` est `ready` sur le provider actif `memos` auto-heberge
- `github-dispatch` est `ready`, avec validation live fermee via token GitHub persiste

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

- finir l'observabilite MCP homogene
- requalifier l'ouverture future de `A2A` une fois l'observabilite MCP homogene fermee
- garder `K-012` comme validation host-native optionnelle tant que le runtime KiCad canonique reste le conteneur; `K-014` est valide en live, avec une limite externe de quota Nexar sur le token de reference
- si un futur lot active `KiAuto`, suivre `docs/KICAD_BENCHMARK_MATRIX.md`, rester opt-in et rejouer `bash tools/tui/cad_mcp_audit.sh audit`
