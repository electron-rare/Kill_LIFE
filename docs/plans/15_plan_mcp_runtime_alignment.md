# 15) Plan d’alignement MCP local

Last updated: 2026-03-07

## Objectif

Faire de `Kill_LIFE` le repo de consommation et de gouvernance MCP, sans maintenir un second serveur MCP concurrent.

## Cible supportée

- serveur: `../mascarade/finetune/kicad_mcp_server`
- launcher local: `tools/hw/run_kicad_mcp.sh`
- config MCP versionnée: `mcp.json`
- transport: `stdio`
- serveur auxiliaire repo/specs: `tools/validate_specs.py --mcp`

## Actions

### 1. Source de vérité

1. Retirer toute promesse de serveur fantôme.
2. Pointer `mcp.json` vers le launcher supporté et les MCP auxiliaires réels.
3. Basculer la doc MCP canonique sur `docs/MCP_SETUP.md`.

### 2. Runtime opérable

1. Faire de `tools/hw/cad_stack.sh mcp` un simple wrapper vers le launcher supporté.
2. Préparer un runtime writable sous `.cad-home/kicad-mcp`.
3. Garder `MASCARADE_DIR` comme override explicite, pas comme dépendance cachée.

### 3. Documentation

1. Transformer les duplications `ai-agentic-embedded-base/docs/*` en pointeurs vers les docs canoniques.
2. Corriger les références à `validate_specs.py`.
3. Garder `stdio only` comme politique MCP locale.

## Critères de sortie

- `mcp.json` ne référence plus de fichier absent
- `tools/hw/run_kicad_mcp.sh --doctor` résout un serveur réel
- `tools/hw/cad_stack.sh mcp` utilise le même chemin que `mcp.json`
- la doc root n’annonce plus `kicad-sch-mcp` comme chemin principal
