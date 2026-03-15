# MCP support matrix

Last updated: 2026-03-14

Matrice canonique du statut MCP pour `Kill_LIFE`, `mascarade` et les surfaces associees.

Vue plus large de l'ecosysteme:

- `docs/MCP_ECOSYSTEM_MATRIX.md`

## Statuts

- `supporte`: surface officiellement maintenue et validee comme point d'entree operateur
- `supporte avec dependance externe`: surface maintenue dans le workspace, mais dependante d'un runtime, d'un cache, d'un token ou d'un repo compagnon
- `experimental`: surface presente et suivie, mais pas encore validee comme chemin operateur stable
- `non supporte`: ancien chemin, historique ou simple reference documentaire

## Provenance

- `officiel`: surface publiee par l'organisation ou le projet qui own l'outil, ou referencee via le registry MCP officiel
- `community valide`: projet tiers etabli, retenu comme reference ou benchmark, sans ownership local direct
- `custom local`: launcher, wrapper, serveur ou audit maintenu dans `Kill_LIFE` ou son repo compagnon

## Matrice

| Surface | Point d'entree | Ownership | Protocole observe / declare | Statut | Provenance | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `kicad` | `tools/hw/run_kicad_mcp.sh` | launcher `Kill_LIFE`, implementation `mascarade/finetune/kicad_mcp_server` | `2025-03-26` observe au smoke | supporte | custom local | runtime KiCad canonique; `tools/hw/cad_stack.sh mcp` est un alias supporte |
| `validate-specs` | `python3 tools/validate_specs.py --mcp` | `Kill_LIFE` | `2025-03-26` observe en test | supporte | custom local | validation repo/specs; ne remplace pas le runtime KiCad |
| `knowledge-base` | `tools/run_knowledge_base_mcp.sh` | launcher `Kill_LIFE`, backend `mascarade/core/mascarade/integrations/knowledge_base.py` | `2025-03-26` observe en test | supporte avec dependance externe | custom local | serveur MCP de compat vers la knowledge base configuree (`memos` ou `docmost`); validation live fermee sur le provider actif `memos` auto-heberge |
| `github-dispatch` | `tools/run_github_dispatch_mcp.sh` | launcher `Kill_LIFE`, backend `mascarade/core/mascarade/integrations/github_dispatch.py` | `2025-03-26` observe en test | supporte avec dependance externe | custom local | serveur local stable; validation live fermee via token GitHub persiste dans `runtime-secrets` |
| `freecad` | `tools/run_freecad_mcp.sh` | runtime `Kill_LIFE`, ops `mascarade` | `2025-03-26` observe au smoke | supporte | custom local | MCP local headless pour infos runtime, creation minimale, export et script controle |
| `openscad` | `tools/run_openscad_mcp.sh` | runtime `Kill_LIFE`, ops `mascarade` | `2025-03-26` observe au smoke | supporte | custom local | MCP local headless stateless pour validation, rendu et export |
| `huggingface` | `https://huggingface.co/mcp` | `Hugging Face` | endpoint `url` versionne dans `mcp.json` | supporte avec dependance externe | officiel | surface MCP distante officielle; hors garde-fou `stdio` local; requiert `HUGGINGFACE_API_KEY` ou login OAuth |
| `component_database` | `python3 -m mcp_servers.component_db` | `mascarade/finetune/kicad_kic_ai` | `2025-03-26` observe au handshake | supporte avec dependance externe | custom local | micro-serveur auxiliaire; depend du cache KiCad v10 et du repo compagnon |
| `kicad_tools` | `python3 -m mcp_servers.kicad_tools` | `mascarade/finetune/kicad_kic_ai` | `2025-03-26` observe au handshake | supporte avec dependance externe | custom local | micro-serveur auxiliaire; analyses reelles si les fichiers KiCad et dependances associees sont disponibles |
| `nexar_api` | `tools/run_nexar_mcp.sh` | launcher `Kill_LIFE`, serveur `mascarade/finetune/kicad_kic_ai/mcp_servers/nexar.py` | `2025-03-26` observe au handshake | supporte avec dependance externe | custom local | micro-serveur auxiliaire; le chemin live est valide avec `Bearer NEXAR_TOKEN`; sur la machine de reference, le token actuel atteint Nexar mais retourne un quota `part limit of 0` |

## Hors chaine supportee

| Surface | Point d'entree | Ownership | Protocole observe / declare | Statut | Provenance | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `kicad-sch-mcp` | aucun chemin versionne supporte ici | historique | n/a | non supporte | community valide | ancien serveur MCP tiers documente seulement; pas retenu comme runtime principal de ce workspace |

## Decisions importantes

- `stdio` reste le seul transport supporte par defaut pour les serveurs locaux; `huggingface` est la seule surface distante versionnee dans `mcp.json`
- `knowledge-base` et `github-dispatch` sont supportes comme serveurs MCP locaux, avec validation live fermee sur la machine de reference
- `freecad` et `openscad` sont des serveurs MCP supportes et sondes par le cockpit ops
- la provenance `custom local` n'assouplit jamais le garde-fou `bash tools/tui/cad_mcp_audit.sh audit`
- la provenance des runtimes CAD sous-jacents est detaillee dans `deploy/cad/README.md`
- `K-025` est absorbe dans `docs/KICAD_BENCHMARK_MATRIX.md`: `KiAuto` reste un appoint opt-in, `kicad-automation-scripts` reste doc-only

## Dettes encore ouvertes

- fermer `K-012` sur une machine avec `pcbnew` host-native
- si un sourcing Nexar live complet est requis, prevoir un token/plan Nexar avec quota de parts non nul
