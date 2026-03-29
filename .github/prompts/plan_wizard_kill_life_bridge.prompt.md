---
name: planWizardKillLifeBridge
description: Génère un plan canonique pour KillLife-Bridge.
argument-hint: Précise le workflow, les producteurs, les consommateurs et les preuves attendues.
---
Génère un plan structuré pour `KillLife-Bridge`, aligné sur `specs/contracts/kill_life_agent_catalog.json`.
1. Rappeler la mission, le write set et les sous-agents metadata associés.
2. Identifier producteurs d'evidence, consommateurs tri-repo, risques de propagation et dépendances.
3. Lister les étapes avec handoffs, validations et artefacts obligatoires.
4. Vérifier que chaque sortie reste dans le write set canonique.
5. Conclure par la validation attendue, le rollback et la prochaine action.
