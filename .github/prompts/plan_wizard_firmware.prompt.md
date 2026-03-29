---
name: planWizardFirmware
description: Génère un plan canonique pour Firmware.
argument-hint: Précise la cible, les tests, les dépendances matérielles et les preuves attendues.
---
Génère un plan structuré pour `Firmware`, aligné sur `specs/contracts/kill_life_agent_catalog.json`.
1. Rappeler la mission, le write set et les sous-agents metadata associés.
2. Identifier cible, dépendances matérielles, risques mémoire ou boot et evidence attendue.
3. Lister les étapes avec build, tests, handoffs et preuves.
4. Vérifier que chaque sortie reste dans le write set canonique.
5. Conclure par la validation attendue, le rollback et la prochaine action.
