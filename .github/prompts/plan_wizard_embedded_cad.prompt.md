---
name: planWizardEmbeddedCad
description: Génère un plan canonique pour Embedded-CAD.
argument-hint: Précise la surface CAD, les outils indisponibles, les preuves et le rollback.
---
Génère un plan structuré pour `Embedded-CAD`, aligné sur `specs/contracts/kill_life_agent_catalog.json`.
1. Rappeler la mission, le write set et les sous-agents metadata associés.
2. Identifier dépendances toolchain, surfaces fabrication, risques degraded-safe et evidence attendue.
3. Lister les étapes avec checks KiCad/FreeCAD, handoffs et preuves.
4. Vérifier que chaque sortie reste dans le write set canonique.
5. Conclure par le rollback, la validation attendue et la prochaine action.
