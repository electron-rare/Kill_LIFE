# MCP support matrix

Last updated: 2026-03-07

Matrice canonique du statut MCP pour `Kill_LIFE`, `mascarade` et les surfaces associees.

Vue plus large de l'ecosysteme:

- `docs/MCP_ECOSYSTEM_MATRIX.md`

## Statuts

- `supporte`: surface officiellement maintenue et validee comme point d'entree operateur
- `supporte avec dependance externe`: surface maintenue dans le workspace, mais dependante d'un runtime, d'un cache, d'un token ou d'un repo compagnon
- `experimental`: surface presente et suivie, mais pas encore validee comme chemin operateur stable
- `non supporte`: ancien chemin, historique ou simple reference documentaire

## Matrice

| Surface | Point d'entree | Ownership | Protocole observe / declare | Statut | Notes |
| --- | --- | --- | --- | --- | --- |
| `kicad` | `tools/hw/run_kicad_mcp.sh` | launcher `Kill_LIFE`, serveur `mascarade/finetune/kicad_mcp_server` | `2025-03-26` observe au smoke | supporte | runtime KiCad canonique; `tools/hw/cad_stack.sh mcp` est un alias supporte |
| `validate-specs` | `python3 tools/validate_specs.py --mcp` | `Kill_LIFE` | `2025-03-26` observe en test | supporte | validation repo/specs; ne remplace pas le runtime KiCad |
| `notion` | `tools/run_notion_mcp.sh` | launcher `Kill_LIFE`, backend `mascarade/core/mascarade/integrations/notion.py` | `2025-03-26` observe en test | supporte avec dependance externe | MCP local branche sur le backend Notion de `mascarade`; requiert `NOTION_API_KEY` et le repo compagnon |
| `github-dispatch` | `tools/run_github_dispatch_mcp.sh` | launcher `Kill_LIFE`, backend `mascarade/core/mascarade/integrations/github_dispatch.py` | `2025-03-26` observe en test | supporte avec dependance externe | MCP local pour workflows allowlistes; requiert `KILL_LIFE_GITHUB_TOKEN` ou `GITHUB_TOKEN` et le repo compagnon |
| `component_database` | `python3 -m mcp_servers.component_db` | `mascarade/finetune/kicad_kic_ai` | `2025-03-26` observe au handshake | supporte avec dependance externe | micro-serveur auxiliaire; depend du repo compagnon `mascarade`, du cache KiCad v10 et d'un index local prechauffe |
| `kicad_tools` | `python3 -m mcp_servers.kicad_tools` | `mascarade/finetune/kicad_kic_ai` | `2025-03-26` observe au handshake | supporte avec dependance externe | micro-serveur auxiliaire; analyses reelles si les fichiers KiCad et dependances associees sont disponibles |
| `nexar_api` | `tools/run_nexar_mcp.sh` | launcher `Kill_LIFE`, serveur `mascarade/finetune/kicad_kic_ai/mcp_servers/nexar.py` | `2025-03-26` observe au handshake | experimental | micro-serveur auxiliaire; sans `NEXAR_TOKEN`, reste en mode demo; validation live encore ouverte |

## Hors chaine supportee

| Surface | Point d'entree | Ownership | Protocole observe / declare | Statut | Notes |
| --- | --- | --- | --- | --- | --- |
| `kicad-sch-mcp` | aucun chemin versionne supporte ici | historique | n/a | non supporte | ancien chemin documentaire, pas un runtime principal de ce workspace |

## Decisions importantes

- `Kill_LIFE` n'own pas de second serveur KiCad concurrent
- `stdio` reste le seul transport supporte par defaut
- le runtime KiCad supporte passe par `Kill_LIFE` pour le lancement et par `mascarade` pour l'implementation
- `notion` et `github-dispatch` sont supportes comme serveurs MCP locaux, mais leur logique applicative reste fournie par `mascarade`
- les micro-serveurs `kicad_kic_ai` sont suivis comme surfaces auxiliaires, pas comme point d'entree operateur `Kill_LIFE`
- le probe synthetique MCP expose cote ops appartient a `mascarade/api/src/routes/ops.ts`; il n'est disponible que si la stack compagnon tourne

## Dettes encore ouvertes

- le chemin host-native avec `pcbnew` n'est pas encore revalide sur une machine qui l'expose reellement
- `nexar_api` doit encore etre valide en mode live avec credentials
- le statut des micro-serveurs auxiliaires doit rester distinct de la surface operateur `kicad`
