---
name: startPmMesh
description: Lance le workflow canonique PM-Mesh.
argument-hint: Donne le lot, le write set, les risques et les preuves attendues.
---
Lance le workflow canonique `PM-Mesh` en prenant `specs/contracts/kill_life_agent_catalog.json` comme source de verite.
1. Charger l'entree `PM-Mesh`, `agents/pm_mesh.md` et les surfaces de plan associees.
2. Confirmer `owner_repo`, `owner_agent`, `write_set_roots`, gates et evidence avant toute modification.
3. Utiliser les sous-agents uniquement comme metadata de lane, jamais comme agents API autonomes.
4. Produire une execution ou un handoff strictement contenu dans le write set declare.
5. Finir avec risques restants, gate suivante et evidence mise a jour.
