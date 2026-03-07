# 15) Plan MCP stack

Last updated: 2026-03-07

## Objectif

Rendre la couche MCP de `Kill_LIFE` cohérente côté config, validation locale et usage opérateur, sans embarquer une promesse cassée.

## Décisions figées

- `mcp.json` publie le launcher KiCad supporté `tools/hw/run_kicad_mcp.sh`.
- `Kill_LIFE` expose aussi `validate-specs` comme serveur/CLI auxiliaire de validation repo.
- Le runtime KiCad côté `Kill_LIFE` est piloté par `mcp.json` et `tools/hw/run_kicad_mcp.sh`.
- `Kill_LIFE` ne publie pas de second serveur KiCad host-side concurrent tant que la convergence n’est pas terminée.

## Implémenté

- [x] Ajouter `tools/validate_specs.py` comme script CLI réel.
- [x] Exposer le même script en serveur MCP `stdio` minimal.
- [x] Garder `mcp.json` sur le launcher KiCad versionné.
- [x] Ajouter des tests sur le mode CLI et le handshake MCP minimal.

## Reste à faire

- [ ] Documenter précisément ce que couvre `validate-specs` et ce qu’il ne couvre pas.
- [ ] Réaligner `tools/hw/cad_stack.sh mcp` sur le launcher supporté ou le déclasser explicitement.
- [ ] Réconcilier `docs/MCP_SETUP.md`, `docs/KICAD_AI_LOCAL.md` et `deploy/cad/README.md`.

## Critères de sortie

- `python3 tools/validate_specs.py` fonctionne sans ambigüité.
- `mcp.json` démarre un serveur MCP KiCad réel.
- La doc `Kill_LIFE` ne présente plus plusieurs vérités contradictoires pour le lancement MCP.
