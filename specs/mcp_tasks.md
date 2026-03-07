# Tasks MCP local

Last updated: 2026-03-07

Format:

- `[ ]` non fait
- `[x]` fait

## Sprint actif

- [x] K-001 — Rendre `validate-specs` réel ou retirer la promesse
  - AC: aucun chemin absent n’est versionné comme serveur MCP.

- [x] K-002 — Ajouter un launcher supporté `tools/hw/run_kicad_mcp.sh`
  - AC: le launcher résout `mascarade`, prépare un runtime writable et exécute le serveur.

- [x] K-003 — Aligner `tools/hw/cad_stack.sh mcp`
  - AC: la commande `mcp` appelle le même launcher que `mcp.json`.

- [x] K-004 — Désigner `docs/MCP_SETUP.md` comme doc canonique
  - AC: la version miroir renvoie vers la doc racine.

- [x] K-005 — Retirer les références à `tools/validate_specs.py`
  - AC: les docs visibles pointent vers un validateur réellement présent.

## À faire ensuite

- [x] K-006 — Ajouter un smoke test MCP consommateur côté `Kill_LIFE`
  - AC: un script versionné existe pour tester `initialize` et `tools/list`.

- [ ] K-007 — Documenter les prérequis machine minimum pour le runtime MCP
  - AC: Node, KiCad et repo compagnon sont explicitement listés.

- [ ] K-008 — Décider du sort final du service Docker `kicad-mcp` historique
  - AC: soit supprimé, soit rebranché sur le runtime supporté sans drift.

- [ ] K-009 — Faire passer le smoke réel `initialize -> tools/list`
  - AC: `python3 tools/hw/mcp_smoke.py` passe sur une machine avec `pcbnew` disponible.
  - Blocage actuel: le host audité n’expose pas `pcbnew`, donc le runtime KiCad ne peut pas démarrer.
