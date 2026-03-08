# MCP support matrix

Last updated: 2026-03-08

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
| `kicad` | `tools/hw/run_kicad_mcp.sh` | launcher `Kill_LIFE`, implementation `mascarade/finetune/kicad_mcp_server` | `2025-03-26` observe au smoke | supporte | runtime KiCad canonique; `tools/hw/cad_stack.sh mcp` est un alias supporte |
| `validate-specs` | `python3 tools/validate_specs.py --mcp` | `Kill_LIFE` | `2025-03-26` observe en test | supporte | validation repo/specs; ne remplace pas le runtime KiCad |
| `knowledge-base` | `tools/run_knowledge_base_mcp.sh` | launcher `Kill_LIFE`, backend `mascarade/core/mascarade/integrations/knowledge_base.py` | `2025-03-26` observe en test | supporte avec dependance externe | serveur MCP de compat vers la knowledge base configuree (`memos` ou `docmost`); validation live fermee sur le provider actif `memos` auto-heberge |
| `github-dispatch` | `tools/run_github_dispatch_mcp.sh` | launcher `Kill_LIFE`, backend `mascarade/core/mascarade/integrations/github_dispatch.py` | `2025-03-26` observe en test | supporte avec dependance externe | serveur local stable; validation live fermee via token GitHub persiste dans `runtime-secrets` |
| `freecad` | `tools/run_freecad_mcp.sh` | runtime `Kill_LIFE`, ops `mascarade` | `2025-03-26` observe au smoke | supporte | MCP local headless pour infos runtime, creation minimale, export et script controle |
| `openscad` | `tools/run_openscad_mcp.sh` | runtime `Kill_LIFE`, ops `mascarade` | `2025-03-26` observe au smoke | supporte | MCP local headless stateless pour validation, rendu et export |
| `component_database` | `python3 -m mcp_servers.component_db` | `mascarade/finetune/kicad_kic_ai` | `2025-03-26` observe au handshake | supporte avec dependance externe | micro-serveur auxiliaire; depend du cache KiCad v10 et du repo compagnon |
| `kicad_tools` | `python3 -m mcp_servers.kicad_tools` | `mascarade/finetune/kicad_kic_ai` | `2025-03-26` observe au handshake | supporte avec dependance externe | micro-serveur auxiliaire; analyses reelles si les fichiers KiCad et dependances associees sont disponibles |
| `nexar_api` | `tools/run_nexar_mcp.sh` | launcher `Kill_LIFE`, serveur `mascarade/finetune/kicad_kic_ai/mcp_servers/nexar.py` | `2025-03-26` observe au handshake | experimental | micro-serveur auxiliaire; sans `NEXAR_TOKEN`, reste en mode demo; validation live encore ouverte |

## Hors chaine supportee

| Surface | Point d'entree | Ownership | Protocole observe / declare | Statut | Notes |
| --- | --- | --- | --- | --- | --- |
| `kicad-sch-mcp` | aucun chemin versionne supporte ici | historique | n/a | non supporte | ancien chemin documentaire, pas un runtime principal de ce workspace |

## Decisions importantes

- `stdio` reste le seul transport supporte par defaut pour les serveurs locaux
- `knowledge-base` et `github-dispatch` sont supportes comme serveurs MCP locaux, avec validation live fermee sur la machine de reference
- `freecad` et `openscad` sont des serveurs MCP supportes et sondes par le cockpit ops
- le probe synthetique MCP expose cote ops appartient a `mascarade/api/src/routes/ops.ts`

## Dettes encore ouvertes

- fermer `K-012` sur une machine avec `pcbnew` host-native
- fermer `K-014` en mode `nexar_api` live avec credentials
