---
name: planWizardSyncOps
description: Génère un plan canonique pour SyncOps.
argument-hint: Précise la lane opératoire, les incidents, les probes et les preuves attendues.
---
Génère un plan structuré pour `SyncOps`, aligné sur `specs/contracts/kill_life_agent_catalog.json`.
1. Rappeler la mission, le write set et les sous-agents metadata associés.
2. Identifier dépendances machines, risques réseau, surfaces logs et evidence attendue.
3. Lister les étapes avec checks TUI, SSH, incident registry et handoffs.
4. Vérifier que chaque sortie reste dans le write set canonique.
5. Conclure par l'état attendu, le rollback et la prochaine action.
