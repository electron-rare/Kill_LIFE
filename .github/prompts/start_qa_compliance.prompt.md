---
name: startQaCompliance
description: Lance le workflow canonique QA-Compliance.
argument-hint: Donne le contrat, la suite de tests, la gate ou la preuve de conformité à valider.
---
Lance le workflow canonique `QA-Compliance` en prenant `specs/contracts/kill_life_agent_catalog.json` comme source de verite.
1. Charger l'entree `QA-Compliance`, `agents/qa_compliance.md` et les surfaces de validation associees.
2. Confirmer `owner_repo`, `owner_agent`, `write_set_roots`, gates et evidence avant toute modification.
3. Utiliser les sous-agents uniquement comme metadata de lane, jamais comme agents API autonomes.
4. Produire une execution ou un handoff strictement contenu dans le write set declare.
5. Finir avec risques restants, gate suivante et evidence mise a jour.
