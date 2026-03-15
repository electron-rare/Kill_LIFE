# Spec conversion MCP GitHub dispatch

Last updated: 2026-03-07

## Objectif

Documenter l'implémentation MCP `github-dispatch` à partir de l'intégration `workflow_dispatch` existante, sans remplacer la voie API existante en V1.

## État actuel

- backend réel dans `mascarade/api/src/lib/killlife.ts` et `crazy_life/api/src/lib/killlife.ts`
- dépendance secrète: `KILL_LIFE_GITHUB_TOKEN` ou `GITHUB_TOKEN`
- contrôle de sécurité actuel:
  - allowlist de workflows
  - sanitation des clés d'input
  - repo et ref par défaut contrôlés

## Surface MCP implémentée

Serveur MCP `github-dispatch` local avec les outils:

- `list_allowlisted_workflows`
- `dispatch_workflow`
- `get_dispatch_status`

## Mapping depuis l'existant

- config allowlist actuelle -> `list_allowlisted_workflows`
- `POST /repos/:repo/actions/workflows/:workflow/dispatches` -> `dispatch_workflow`
- suivi de run et réconciliation locale -> `get_dispatch_status`

## Contraintes

- garder `stdio` comme transport par défaut
- interdire tout dispatch hors allowlist
- ne pas exposer de surface générique GitHub issue/PR/repo en V1
- conserver l'API actuelle tant que les éditeurs de workflow ne consomment pas MCP
- launcher opérateur: `tools/run_github_dispatch_mcp.sh`

## Hors scope V1

- gestion générique GitHub
- mutation libre d'issues, PR, labels ou releases
- changement dynamique du repo cible hors politique versionnée

## Validation minimale

- handshake `initialize -> tools/list` vert
- `dispatch_workflow` refuse un workflow non allowlisté
- erreur structurée si token absent
- `get_dispatch_status` retourne un état exploitable sans lecture manuelle brute de l'API GitHub
