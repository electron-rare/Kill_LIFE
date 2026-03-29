---
name: startUxLead
description: Lance le workflow canonique UX-Lead.
argument-hint: Donne la surface UX, shell natif, review center ou recherche design à cadrer.
---
Lance le workflow canonique `UX-Lead` en prenant `specs/contracts/kill_life_agent_catalog.json` comme source de verite.
1. Charger l'entree `UX-Lead`, `agents/ux_lead.md` et les surfaces UX associees.
2. Confirmer `owner_repo`, `owner_agent`, `write_set_roots`, gates et evidence avant toute modification.
3. Utiliser les sous-agents uniquement comme metadata de lane, jamais comme agents API autonomes.
4. Produire une execution ou un handoff strictement contenu dans le write set declare.
5. Finir avec risques restants, gate suivante et evidence mise a jour.
