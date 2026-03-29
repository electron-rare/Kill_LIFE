---
name: planWizardArchMesh
description: Génère un plan canonique pour Arch-Mesh.
argument-hint: Précise les contrats, dépendances, risques et preuves attendues.
---
Génère un plan structuré pour `Arch-Mesh`, aligné sur `specs/contracts/kill_life_agent_catalog.json`.
1. Rappeler la mission, le write set et les sous-agents metadata associés.
2. Identifier préconditions, interfaces publiques, dépendances et risques de compatibilité.
3. Lister les étapes dans l'ordre avec gates, handoffs et preuves de stabilité contractuelle.
4. Vérifier que chaque sortie reste dans le write set canonique.
5. Conclure par la validation attendue, le rollback et la prochaine action.
