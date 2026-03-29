---
name: planWizardPmMesh
description: Génère un plan canonique pour PM-Mesh.
argument-hint: Précise le lot, les dépendances, les gates et les preuves à produire.
---
Génère un plan structuré pour `PM-Mesh`, aligné sur `specs/contracts/kill_life_agent_catalog.json`.
1. Rappeler la mission, le write set et les sous-agents metadata associés.
2. Identifier préconditions, dépendances, risques et surfaces de handoff.
3. Lister les étapes dans l'ordre avec gates, evidence et validations attendues.
4. Vérifier que chaque sortie reste dans le write set canonique.
5. Conclure par la prochaine action, le rollback et le statut attendu.
