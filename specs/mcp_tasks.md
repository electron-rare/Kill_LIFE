# Tasks MCP local

Last updated: 2026-03-08

Backlog MCP canonique pour `Kill_LIFE`.

Références:

- doc opérateur: `docs/MCP_SETUP.md`
- matrice de support: `docs/MCP_SUPPORT_MATRIX.md`
- spec de périmètre: `specs/kicad_mcp_scope_spec.md`

Format:

- `[ ]` non fait
- `[x]` fait

## État courant

- Etat agrege courant:
  - `kicad`, `validate-specs` et `huggingface` sont `ready`
  - `knowledge-base` est `ready` sur le provider actif `memos`, avec smoke live valide
  - `github-dispatch` est `ready`, avec smoke live valide via token GitHub persiste
  - aucun blocage MCP local actif ne reste sur la machine de reference
  - `nexar_api` est valide en live; le token de reference atteint Nexar mais reste limite par un quota externe (`part limit of 0`)
  - `K-012` est maintenant classe comme validation host-native optionnelle tant que le runtime canonique reste le conteneur MCP KiCad

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
  - Statut: optionnel tant que le runtime canonique reste `container` et valide en production locale.
  - Helper pret: `python3 tools/hw/kicad_host_mcp_smoke.py --json --quick` degrade proprement si `pcbnew` est absent.
  - Derniere verification: `2026-03-08` sur cette machine -> `blocked by host environment`
  - Evidence: `python3 tools/hw/kicad_host_mcp_smoke.py --json --quick`
  - Resultat: `{"status":"degraded","host_pcbnew_import":"missing","error":"pcbnew not importable on host runtime"}`

- [x] K-013 — Décider du statut final des micro-serveurs `kicad_kic_ai`
  - AC: `component_database`, `kicad_tools` et `nexar_api` sont explicitement promus en surfaces auxiliaires supportées.

- [x] K-014 — Valider le mode live de `nexar_api`
  - AC: un run avec `NEXAR_TOKEN` confirme le comportement reel et le distingue du mode demo.
  - Helper pret: `python3 tools/nexar_mcp_smoke.py --json --live` degrade ou echoue proprement tant que le token ou le mode live manquent.
  - Derniere verification: `2026-03-08` sur cette machine -> validation live fermee
  - Evidence: `python3 tools/nexar_mcp_smoke.py --json --live`
  - Resultat: `{"status":"degraded","token_configured":true,"demo_mode":false,"live_validation":"quota_exceeded","error":"You have exceeded your part limit of 0..."}`
  - Note: le chemin live est valide; la limite restante est externe au workspace (quota/plan Nexar du token de reference), pas un fallback en mode demo.

- [x] K-015 — Implémenter le MCP `knowledge-base`
  - AC: `tools/run_knowledge_base_mcp.sh` expose `search_pages`, `read_page`, `append_to_page`, `create_page` sans retirer le bridge HTTP en V1.
  - Resultat: le serveur `knowledge-base` est maintenant un MCP de compat vers `KNOWLEDGE_BASE_PROVIDER=memos|docmost`.

- [x] K-016 — Implémenter le MCP `GitHub dispatch`
  - AC: `tools/run_github_dispatch_mcp.sh` expose `list_allowlisted_workflows`, `dispatch_workflow` et `get_dispatch_status` sans retirer la voie API actuelle en V1.

- [x] K-017 — Ajouter des smokes MCP dedies hors KiCad
  - AC: `validate-specs`, `knowledge-base` et `github-dispatch` ont chacun un smoke versionne avec sortie JSON.

- [x] K-018 — Etendre l'observabilite MCP a plusieurs serveurs
  - AC: `/api/ops/summary` expose un etat agrege et le detail par serveur pour `kicad`, `validate-specs`, `knowledge-base`, `github-dispatch`, `freecad` et `openscad`.

- [x] K-019 — Ajouter un helper de readiness host-native KiCad
  - AC: `python3 tools/hw/kicad_host_mcp_smoke.py --json --quick` retourne `ready` ou `degraded` sans ambiguite.

- [x] K-020 — Ajouter un smoke dedie pour `nexar_api`
  - AC: `python3 tools/nexar_mcp_smoke.py --json` distingue mode demo et mode live.

- [x] K-021 — Ajouter un rapport MCP local synthetique
  - AC: `python3 tools/mcp_runtime_status.py --json` agrege les smokes supportes, traite `K-012` comme chemin host-native optionnel, et rend visible `K-014` comme blocage specialise actif.

- [x] K-022 — Valider la knowledge base active en live via le MCP `knowledge-base`
  - AC: un run avec le provider actif et sa cible de smoke confirme `search_pages` et `read_page`.
  - Resultat: validation live fermee sur le provider actif `memos` auto-heberge, avec `python3 tools/knowledge_base_mcp_smoke.py --json` en `ready`.
  - Variantes supportees:
    - `memos`: `MEMOS_BASE_URL` + `MEMOS_ACCESS_TOKEN` + `KNOWLEDGE_BASE_SMOKE_PAGE_ID` optionnel
    - `docmost`: `DOCMOST_BASE_URL` + `DOCMOST_EMAIL` + `DOCMOST_PASSWORD` + `KNOWLEDGE_BASE_SMOKE_PAGE_ID`

- [x] K-023 — Valider `GitHub dispatch MCP` en live
  - AC: un run avec `KILL_LIFE_GITHUB_TOKEN` ou un `GitHub App` valide confirme `list_allowlisted_workflows` et `dispatch_workflow` sur une cible autorisee.
  - Resultat: validation live fermee via token GitHub persiste dans `runtime-secrets`; le smoke versionne confirme `list_allowlisted_workflows`, `dispatch_workflow` et `get_dispatch_status`.
  - Evidence: `python3 tools/github_dispatch_mcp_smoke.py --json --live`
