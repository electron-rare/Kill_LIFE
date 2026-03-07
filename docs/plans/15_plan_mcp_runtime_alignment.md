# 15) Plan d'alignement MCP local

Last updated: 2026-03-07

Ce fichier est le plan MCP canonique cote `Kill_LIFE`.

Sources de verite associees:

- `docs/MCP_SETUP.md`
- `docs/MCP_SUPPORT_MATRIX.md`
- `specs/kicad_mcp_scope_spec.md`
- `specs/mcp_tasks.md`

## Objectif

Faire de `Kill_LIFE` le repo de consommation et de gouvernance MCP, sans maintenir un second serveur KiCad concurrent.

## Etat actuel

- `mcp.json` pointe vers des launchers MCP reels pour `kicad`, `validate-specs`, `notion` et `github-dispatch`
- `tools/hw/run_kicad_mcp.sh` est le point d'entree canonique pour le runtime KiCad
- `tools/hw/cad_stack.sh mcp` est deja aligne sur ce launcher
- `python3 tools/hw/mcp_smoke.py --timeout 30` passe sur la machine auditee via fallback conteneur
- `validate-specs` existe comme CLI et comme serveur MCP `stdio`
- la pile MCP locale converge sur `2025-03-26`
- l'observabilite synthetique MCP est exposee via `/api/ops/summary` si la stack compagnon `mascarade` tourne

## Decisions figees

- `Kill_LIFE` ne publie pas de second runtime KiCad host-side concurrent
- `mascarade/finetune/kicad_mcp_server` reste l'implementation serveur KiCad de reference
- `stdio` reste le seul transport supporte par defaut
- la matrice de support MCP est centralisee dans `docs/MCP_SUPPORT_MATRIX.md`
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
2. `component_database` et `kicad_tools` sont classes `supporte avec dependance externe`.
3. `nexar_api` reste `experimental` tant qu'il n'est pas valide en mode live.
4. Le helper `python3 tools/nexar_mcp_smoke.py --json` qualifie le mode demo; `--live` sert a valider un vrai token.

## Criteres de sortie

- `Kill_LIFE` publie une seule doc operateur MCP canonique
- la matrice de support ne laisse plus de statut implicite
- les TODOs MCP ne sont plus dupliques entre `docs/plans` et `specs`
- le prochain lecteur sait immediatement:
  - quel serveur lancer
  - quel alias utiliser
  - ce qui est supporte localement
  - ce qui depend encore de `mascarade`
  - ce qui reste reellement ouvert
