# 15) Plan d'alignement MCP local

Last updated: 2026-03-14

Ce fichier est le plan MCP canonique cote `Kill_LIFE`.

Sources de verite associees:

- `docs/MCP_SETUP.md`
- `docs/MCP_SUPPORT_MATRIX.md`
- `docs/MCP_ECOSYSTEM_MATRIX.md`
- `docs/KICAD_BENCHMARK_MATRIX.md`
- `docs/MCP_CAD_PROVENANCE_2026-03-14.md`
- `specs/kicad_mcp_scope_spec.md`
- `specs/mcp_tasks.md`

## Objectif

Faire de `Kill_LIFE` le repo de consommation et de gouvernance MCP, sans maintenir un second serveur KiCad concurrent et sans brouiller la provenance des surfaces CAD/MCP.

## Etat actuel

- `mcp.json` pointe vers des launchers MCP reels pour `kicad`, `validate-specs`, `knowledge-base`, `github-dispatch`, `freecad`, `openscad` et `huggingface`
- `tools/hw/run_kicad_mcp.sh` est le point d'entree canonique pour le runtime KiCad
- `tools/hw/cad_stack.sh mcp` est deja aligne sur ce launcher
- `python3 tools/hw/mcp_smoke.py --timeout 30` passe sur la machine auditee via fallback conteneur
- `validate-specs` existe comme CLI et comme serveur MCP `stdio`
- la pile MCP locale converge sur `2025-03-26`
- l'observabilite synthetique MCP est exposee via `/api/ops/summary` si la stack compagnon `mascarade` tourne
- le garde-fou `bash tools/tui/cad_mcp_audit.sh audit` retourne `0 actionable hit` au lot provenance du `2026-03-14`

## Decisions figees

- `Kill_LIFE` ne publie pas de second runtime KiCad host-side concurrent
- `mascarade/finetune/kicad_mcp_server` reste l'implementation serveur KiCad de reference
- `stdio` reste le seul transport supporte par defaut pour les serveurs locaux
- `huggingface` reste l'unique surface MCP distante versionnee dans `mcp.json`
- la matrice de support MCP est centralisee dans `docs/MCP_SUPPORT_MATRIX.md`
- la provenance `officiel` / `community valide` / `custom local` est centralisee dans `docs/MCP_SUPPORT_MATRIX.md` et `deploy/cad/README.md`
- le backlog executable est centralise dans `specs/mcp_tasks.md`
- `specs/` a la racine est la source de verite canonique; `ai-agentic-embedded-base/specs/` reste un miroir exporte

## Travail deja absorbe

1. Retirer les promesses cassees de `mcp.json`
2. Rendre `validate-specs` executable en CLI et en MCP
3. Rendre le launcher KiCad operable avec runtime writable
4. Aligner `cad_stack.sh mcp` sur le launcher supporte
5. Stabiliser le fallback conteneur KiCad v10
6. Ajouter un smoke consommateur versionne
7. Fixer une doc d'usage canonique et une matrice de support
8. Classer la provenance MCP/CAD sans desserrer le garde-fou d'audit

## Travail restant

### Priorite 1 — Alignement protocole

1. Fait
2. Les launchers MCP supportes et les surfaces auxiliaires suivies convergent vers `2025-03-26`.

### Priorite 2 — Observabilite

1. Fait
2. `/api/ops/summary` expose l'etat synthetique MCP quand la stack compagnon `mascarade` est presente.
3. `python3 tools/mcp_runtime_status.py --json` fournit un rapport local synthetique quand la stack compagnon n'est pas disponible ou quand on veut visualiser explicitement les blocages environnementaux.

### Priorite 3 — Validation host-native

1. Rejouer le smoke sur une machine avec `pcbnew` disponible
2. Confirmer que le chemin hote reste coherent avec le fallback conteneur
3. Le helper `python3 tools/hw/kicad_host_mcp_smoke.py --json --quick` est disponible pour qualifier la readiness avant validation live

### Priorite 4 — Classement des surfaces auxiliaires

1. Fait
2. `component_database`, `kicad_tools` et `nexar_api` sont classes `supporte avec dependance externe`.
3. `nexar_api` reste supporte avec dependance externe; la limite live restante est externe au workspace (quota/plan du token), pas un doute sur la surface.
4. Le helper `python3 tools/nexar_mcp_smoke.py --json` qualifie le mode demo; `--live` sert a valider un vrai token.

### Priorite 5 — Provenance et outillage adjacent

1. Fait
2. `docs/MCP_SUPPORT_MATRIX.md`, `docs/MCP_ECOSYSTEM_MATRIX.md`, `docs/MCP_SETUP.md` et `deploy/cad/README.md` classent maintenant `officiel`, `community valide` et `custom local`.
3. `docs/KICAD_BENCHMARK_MATRIX.md` et `tools/tui/kicad_benchmark_review.sh` absorbent `K-025`: `KiAuto` reste un appoint opt-in, `kicad-automation-scripts` reste doc-only, sans remplacer par defaut `kicad-cli` + `kicad-mcp`.
4. Les logs bruts du benchmark vivent sous `.ops/kicad-benchmark/*.log`, puis sont purges apres extraction des conclusions durables; le rapport Markdown peut rester.

## Criteres de sortie

- `Kill_LIFE` publie une seule doc operateur MCP canonique
- la matrice de support ne laisse plus de statut implicite ni de provenance implicite
- les TODOs MCP ne sont plus dupliques entre `docs/plans` et `specs`
- le prochain lecteur sait immediatement:
  - quel serveur lancer
  - quel alias utiliser
  - ce qui est supporte localement
  - ce qui est officiel, communautaire valide ou custom local
  - ce qui depend encore de `mascarade`
  - ce qui reste reellement ouvert
