---
name: startSchemaGuard
description: Lance le workflow canonique Schema-Guard.
argument-hint: Donne le schéma, le contrat ou la validation structurelle à durcir.
---
Lance le workflow canonique `Schema-Guard` en prenant `specs/contracts/kill_life_agent_catalog.json` comme source de verite.
1. Charger l'entree `Schema-Guard`, `agents/schema_guard.md` et les contrats associes.
2. Confirmer `owner_repo`, `owner_agent`, `write_set_roots`, gates et evidence avant toute modification.
3. Utiliser les sous-agents uniquement comme metadata de lane, jamais comme agents API autonomes.
4. Produire une execution ou un handoff strictement contenu dans le write set declare.
5. Finir avec risques restants, gate suivante et evidence mise a jour.
