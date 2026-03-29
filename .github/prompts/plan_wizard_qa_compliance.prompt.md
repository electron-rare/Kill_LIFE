---
name: planWizardQaCompliance
description: Génère un plan canonique pour QA-Compliance.
argument-hint: Précise la gate, les suites ciblées, le contrat et les preuves attendues.
---
Génère un plan structuré pour `QA-Compliance`, aligné sur `specs/contracts/kill_life_agent_catalog.json`.
1. Rappeler la mission, le write set et les sous-agents metadata associés.
2. Identifier suites stables, contrats JSON, risques de régression et preuves attendues.
3. Lister les étapes avec validations, gates et handoffs.
4. Vérifier que chaque sortie reste dans le write set canonique.
5. Conclure par l'état attendu, les écarts restants et la prochaine gate.
