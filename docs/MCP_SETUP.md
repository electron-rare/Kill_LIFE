# MCP setup

Source canonique pour l'usage MCP local de `Kill_LIFE`.

References canoniques:

- spec de perimetre: `specs/kicad_mcp_scope_spec.md`
- matrice de support: `docs/MCP_SUPPORT_MATRIX.md`
- matrice ecosysteme: `docs/MCP_ECOSYSTEM_MATRIX.md`
- backlog MCP: `specs/mcp_tasks.md`

## Source de verite et ownership

- `Kill_LIFE` own le lancement, la consommation et la gouvernance documentaire MCP locale
- `mascarade` own l'implementation du serveur KiCad principal et l'observabilite compagnon
- `specs/` a la racine de `Kill_LIFE` est la source de verite canonique
- `ai-agentic-embedded-base/specs/` n'est qu'un miroir exporte

## Chemins supportes

- serveur MCP KiCad supporte: `../mascarade/finetune/kicad_mcp_server`
- launcher supporte cote `Kill_LIFE`: `tools/hw/run_kicad_mcp.sh`
- alias operateur supporte: `tools/hw/cad_stack.sh mcp`
- serveur auxiliaire supporte: `python3 tools/validate_specs.py --mcp`
- serveur MCP Notion supporte: `tools/run_notion_mcp.sh`
- serveur MCP GitHub dispatch supporte: `tools/run_github_dispatch_mcp.sh`
- transport supporte: `stdio` local uniquement

`kicad-sch-mcp` n'est plus un chemin supporte dans ce repo. Il reste un ancien axe documentaire, pas un runtime principal.

## Ce qui est reellement supporte

- `kicad`: runtime MCP KiCad canonique, avec `tools`, `resources` et `prompts`
- `validate-specs`: validation repo/specs cote `Kill_LIFE`, sans role CAD
- `notion`: MCP local sur le backend Notion existant de `mascarade`
- `github-dispatch`: MCP local pour workflows GitHub allowlistes

Les micro-serveurs `kicad_kic_ai` de `mascarade` sont suivis comme surfaces auxiliaires. Ils ne sont pas des points d'entree operateur `Kill_LIFE`, et leur statut doit etre lu avec leurs dependances externes dans `docs/MCP_SUPPORT_MATRIX.md`.

## Prerequis

- le repo compagnon `mascarade` existe en voisin (`../mascarade`) ou via `MASCARADE_DIR`
- `node` est disponible sur la machine
- le serveur est builde dans `mascarade/finetune/kicad_mcp_server/dist/index.js`
- le venv `mascarade/core/.venv` existe, ou `MASCARADE_CORE_PYTHON` pointe vers un Python avec `notion-client` et `httpx`
- Docker est disponible pour le fallback conteneur KiCad v10
- `pcbnew` cote hote est optionnel: s'il est absent, le launcher bascule vers le conteneur supporte
- `NOTION_API_KEY` est requis pour les outils `notion`
- `KILL_LIFE_GITHUB_TOKEN` ou `GITHUB_TOKEN` est requis pour `dispatch_workflow`

Le runtime prepare un environnement writable sous `.cad-home/kicad-mcp/` et exporte `KICAD_MCP_DATA_DIR` pour eviter les ecritures dans un prefixe immuable.

## Diagnostic rapide

Depuis `Kill_LIFE`:

```bash
tools/hw/run_kicad_mcp.sh --doctor
tools/hw/cad_stack.sh mcp --doctor
tools/run_notion_mcp.sh --doctor
tools/run_github_dispatch_mcp.sh --doctor
python3 tools/validate_specs_mcp_smoke.py --json --quick
python3 tools/notion_mcp_smoke.py --json --quick
python3 tools/github_dispatch_mcp_smoke.py --json --quick
python3 tools/hw/mcp_smoke.py --json --quick --timeout 30
python3 tools/hw/mcp_smoke.py --timeout 30
python3 tools/validate_specs.py --json
```

Sur cette machine auditee, le smoke KiCad passe via le fallback conteneur:

- `HOST_PCBNEW_IMPORT=missing`
- `CONTAINER_STATUS=available`
- `python3 tools/hw/mcp_smoke.py --timeout 30` passe
- `python3 tools/notion_mcp_smoke.py --json --quick` retourne `degraded` tant que `NOTION_API_KEY` est absent
- `python3 tools/github_dispatch_mcp_smoke.py --json --quick` retourne `degraded` tant que le token GitHub est absent

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
    "notion": {
      "type": "local",
      "command": "bash",
      "args": ["tools/run_notion_mcp.sh"],
      "tools": ["*"]
    },
    "github-dispatch": {
      "type": "local",
      "command": "bash",
      "args": ["tools/run_github_dispatch_mcp.sh"],
      "tools": ["*"]
    }
  }
}
```

## Usage

Depuis `Kill_LIFE`:

```bash
tools/hw/run_kicad_mcp.sh
tools/hw/cad_stack.sh mcp
python3 tools/validate_specs.py --mcp
tools/run_notion_mcp.sh
tools/run_github_dispatch_mcp.sh
```

Le smoke `tools/hw/mcp_smoke.py` valide actuellement la surface cible suivante:

- `initialize`
- `tools/list`
- `resources/list`
- `prompts/list`
- creation de projet
- lecture de resources stables
- lecture d'un prompt stable

Les smokes dedies supplementaires sont:

- `tools/validate_specs_mcp_smoke.py`: handshake MCP de `validate-specs`
- `tools/notion_mcp_smoke.py`: handshake MCP de `notion`, puis validation live si le secret est disponible
- `tools/github_dispatch_mcp_smoke.py`: handshake MCP de `github-dispatch`, puis validation allowlist et live optionnelle

Le chemin d'observabilite synthetique n'est pas fourni par `Kill_LIFE` seul. Si la stack compagnon `mascarade` tourne, `/api/ops/summary` expose un bloc `mcp` qui remonte le statut, le runtime reellement choisi, la version de protocole et les compteurs de surface.

## Outils auxiliaires

- `tools/hw/sync_kicad_v10_libs.sh` est un helper auxiliaire optionnel, hors chemin operateur principal, pour prechauffer les libs/cache KiCad v10 des micro-serveurs auxiliaires
- ce helper depend:
  - d'une image Docker locale `kill_life_cad-kicad-mcp:latest`
  - du repo compagnon `mascarade`
- ce helper n'est pas requis pour lancer le runtime `kicad` canonique

## Politique de support

- `stdio` reste le seul transport supporte par defaut
- aucun serveur MCP reseau n'est expose par defaut
- `tools/hw/cad_stack.sh mcp` est un alias supporte du launcher canonique
- le runtime KiCad canonique est celui de `mascarade/finetune/kicad_mcp_server`
- `validate-specs` reste un MCP auxiliaire repo/specs, pas un runtime CAD
- `notion` et `github-dispatch` restent en `stdio` local et reutilisent les backends existants
- les micro-serveurs `kicad_kic_ai` sont des surfaces auxiliaires suivies, mais restent hors chemin operateur `Kill_LIFE`

## Points encore ouverts

- le chemin host-native avec `pcbnew` doit encore etre revalide sur une machine qui expose reellement KiCad Python
- `nexar_api` doit encore etre valide en mode live avec `NEXAR_TOKEN`
