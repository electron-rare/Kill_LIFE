# Tasks MCP local

Last updated: 2026-03-07

Backlog MCP canonique pour `Kill_LIFE`.

Références:

- doc opérateur: `docs/MCP_SETUP.md`
- matrice de support: `docs/MCP_SUPPORT_MATRIX.md`
- spec de périmètre: `specs/kicad_mcp_scope_spec.md`

Format:

- `[ ]` non fait
- `[x]` fait

## État courant

- [x] K-001 — Rendre `validate-specs` réel
  - AC: `mcp.json` ne référence plus de chemin absent.

- [x] K-002 — Ajouter un launcher KiCad supporté
  - AC: `tools/hw/run_kicad_mcp.sh` résout `mascarade`, prépare un runtime writable et exécute le serveur.

- [x] K-003 — Aligner `tools/hw/cad_stack.sh mcp`
  - AC: l'alias opérateur appelle le même launcher que `mcp.json`.

- [x] K-004 — Fixer une doc opérateur canonique
  - AC: `docs/MCP_SETUP.md` décrit le chemin réellement supporté.

- [x] K-005 — Fixer une spec de périmètre canonique
  - AC: `specs/kicad_mcp_scope_spec.md` décrit le contrat MCP KiCad supporté.

- [x] K-006 — Fixer une matrice de support canonique
  - AC: `docs/MCP_SUPPORT_MATRIX.md` classe explicitement les surfaces supportées et les chemins hors chaîne supportée.

- [x] K-007 — Ajouter un smoke test consommateur versionné
  - AC: `python3 tools/hw/mcp_smoke.py --timeout 30` passe sur un environnement supporté.

- [x] K-008 — Documenter les prérequis machine utiles
  - AC: `docs/MCP_SETUP.md` documente `node`, Docker, le repo compagnon et le fallback hôte -> conteneur.

- [x] K-009 — Décider du sort du chemin `cad_stack.sh mcp`
  - AC: ce n'est plus un chemin legacy, mais un alias supporté du launcher canonique.

## À faire ensuite

- [x] K-010 — Aligner la matrice de protocoles MCP
  - AC: le runtime KiCad principal, `validate-specs` et les micro-serveurs auxiliaires exposent une compatibilité documentée et non contradictoire.

- [x] K-011 — Ajouter une observabilité MCP synthétique
  - AC: un état `ready / degraded / failed` est visible sans lecture manuelle des logs.

- [ ] K-012 — Rejouer la validation host-native sur une machine avec `pcbnew`
  - AC: le smoke passe aussi sur le chemin hote, pas seulement via le fallback conteneur.
  - Helper pret: `python3 tools/hw/kicad_host_mcp_smoke.py --json --quick` degrade proprement si `pcbnew` est absent.

- [x] K-013 — Décider du statut final des micro-serveurs `kicad_kic_ai`
  - AC: `component_database`, `kicad_tools` et `nexar_api` sont explicitement promus en surfaces auxiliaires supportées.

- [ ] K-014 — Valider le mode live de `nexar_api`
  - AC: un run avec `NEXAR_TOKEN` confirme le comportement reel et le distingue du mode demo.
  - Helper pret: `python3 tools/nexar_mcp_smoke.py --json --live` degrade ou echoue proprement tant que le token ou le mode live manquent.

- [x] K-015 — Implémenter le MCP `Notion`
  - AC: `tools/run_notion_mcp.sh` expose `search_pages`, `read_page`, `append_to_page`, `create_page` sans retirer le bridge HTTP en V1.

- [x] K-016 — Implémenter le MCP `GitHub dispatch`
  - AC: `tools/run_github_dispatch_mcp.sh` expose `list_allowlisted_workflows`, `dispatch_workflow` et `get_dispatch_status` sans retirer la voie API actuelle en V1.

- [x] K-017 — Ajouter des smokes MCP dedies hors KiCad
  - AC: `validate-specs`, `notion` et `github-dispatch` ont chacun un smoke versionne avec sortie JSON.

- [x] K-018 — Etendre l'observabilite MCP a plusieurs serveurs
  - AC: `/api/ops/summary` expose un etat agrege et le detail par serveur pour `kicad`, `validate-specs`, `notion` et `github-dispatch`.

- [x] K-019 — Ajouter un helper de readiness host-native KiCad
  - AC: `python3 tools/hw/kicad_host_mcp_smoke.py --json --quick` retourne `ready` ou `degraded` sans ambiguite.

- [x] K-020 — Ajouter un smoke dedie pour `nexar_api`
  - AC: `python3 tools/nexar_mcp_smoke.py --json` distingue mode demo et mode live.
