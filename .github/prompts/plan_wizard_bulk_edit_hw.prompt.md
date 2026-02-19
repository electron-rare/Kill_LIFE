---
name: planWizardBulkEditHw
description: Génère un plan pour le bulk edit hardware.
argument-hint: Spécifie bulk edit, exports, snapshots, artefacts.
---
Génère un plan structuré pour le bulk edit hardware :
1. Ouvrir issue ai:hw
2. Orchestrer bulk edit via tools/hw/schops
3. Exporter ERC/DRC/BOM/netlist, snapshot avant/après
4. Archiver artefacts dans artifacts/hw/
5. Documenter les conventions
