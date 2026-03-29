---
name: planWizardSchemaGuard
description: Génère un plan canonique pour Schema-Guard.
argument-hint: Précise le schéma, les producteurs, les invariants et les preuves attendues.
---
Génère un plan structuré pour `Schema-Guard`, aligné sur `specs/contracts/kill_life_agent_catalog.json`.
1. Rappeler la mission, le write set et les sous-agents metadata associés.
2. Identifier producteurs, consommateurs, invariants cassables et evidence attendue.
3. Lister les étapes avec mises à jour de schéma, validateurs, tests et handoffs.
4. Vérifier que chaque sortie reste dans le write set canonique.
5. Conclure par la validation attendue, la compatibilité et la prochaine action.
