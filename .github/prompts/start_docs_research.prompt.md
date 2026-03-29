---
name: startDocsResearch
description: Lance le workflow canonique Docs-Research.
argument-hint: Donne la surface documentaire, la navigation ou la synthèse à mettre à jour.
---
Lance le workflow canonique `Docs-Research` en prenant `specs/contracts/kill_life_agent_catalog.json` comme source de verite.
1. Charger l'entree `Docs-Research`, `agents/docs_research.md` et les docs d'entree associees.
2. Confirmer `owner_repo`, `owner_agent`, `write_set_roots`, gates et evidence avant toute modification.
3. Utiliser les sous-agents uniquement comme metadata de lane, jamais comme agents API autonomes.
4. Produire une execution ou un handoff strictement contenu dans le write set declare.
5. Finir avec risques restants, gate suivante et evidence mise a jour.
