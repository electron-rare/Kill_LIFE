# MCP setup

Last updated: 2026-03-08

Source canonique pour l'usage MCP local de `Kill_LIFE`.

References canoniques:

- spec de perimetre KiCad: `specs/kicad_mcp_scope_spec.md`
- matrice de support: `docs/MCP_SUPPORT_MATRIX.md`
- matrice ecosysteme: `docs/MCP_ECOSYSTEM_MATRIX.md`
- backlog MCP KiCad: `specs/mcp_tasks.md`
- backlog cible MCP/agentics: `specs/mcp_agentics_target_backlog.md`

## Source de verite et ownership

- `Kill_LIFE` own le lancement, les smokes et la gouvernance documentaire MCP locale
- `mascarade` own l'agregation ops et l'observabilite compagnon
- `specs/` a la racine de `Kill_LIFE` est la source de verite canonique
- `ai-agentic-embedded-base/specs/` n'est qu'un miroir exporte

## Chemins supportes

- `kicad`: `tools/hw/run_kicad_mcp.sh`
- `validate-specs`: `python3 tools/validate_specs.py --mcp`
- `knowledge-base`: `tools/run_knowledge_base_mcp.sh`
- `github-dispatch`: `tools/run_github_dispatch_mcp.sh`
- `freecad`: `tools/run_freecad_mcp.sh`
- `openscad`: `tools/run_openscad_mcp.sh`
- transport supporte: `stdio` local uniquement, sauf surface distante explicitement declaree par le cockpit compagnon

## Ce qui est reellement supporte

- `kicad`: runtime MCP CAD canonique, avec `tools`, `resources` et `prompts`
- `validate-specs`: validation repo/specs cote `Kill_LIFE`
- `knowledge-base`: MCP local de compat sur la knowledge base configuree dans `mascarade` (`memos` ou `docmost`)
- `github-dispatch`: MCP local pour workflows GitHub allowlistes
- `freecad`: MCP local headless pour infos runtime, document minimal, export et script Python controle
- `openscad`: MCP local headless pour infos runtime, validation, rendu et export

Les micro-serveurs `kicad_kic_ai` de `mascarade` restent suivis comme surfaces auxiliaires dans `docs/MCP_SUPPORT_MATRIX.md`.

## Prerequis

- le repo compagnon `mascarade` existe en voisin (`../mascarade`) ou via `MASCARADE_DIR`
- Docker est disponible pour `kicad`, `freecad` et `openscad`
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

- `kicad`, `validate-specs`, `freecad` et `openscad` sont `ready`
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
      "command": "python3",
      "args": ["tools/validate_specs.py", "--mcp"],
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
    }
  }
}
```

## Usage

Depuis `Kill_LIFE`:

```bash
tools/hw/run_kicad_mcp.sh
python3 tools/validate_specs.py --mcp
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

- `stdio` reste le seul transport supporte par defaut
- aucun serveur MCP reseau n'est expose par defaut pour ces surfaces locales
- `knowledge-base` et `github-dispatch` sont valides en live sur la machine de reference
- `freecad` et `openscad` sont supportes comme serveurs MCP headless locaux
- `kicad` reste le runtime MCP CAD principal

## Points encore ouverts

- finir l'observabilite MCP homogene
- requalifier l'ouverture future de `A2A` une fois l'observabilite MCP homogene fermee
- fermer `K-012` sur une machine avec `pcbnew` host-native et `K-014` en mode `nexar_api` live
