---
name: startWebCadPlatform
description: Lance le workflow canonique Web-CAD-Platform.
argument-hint: Donne la surface web, GraphQL, realtime, queue, review ou artifacts à traiter.
---
Lance le workflow canonique `Web-CAD-Platform` en prenant `specs/contracts/kill_life_agent_catalog.json` comme source de verite.
1. Charger l'entree `Web-CAD-Platform`, `agents/web_cad_platform.md` et les surfaces web associees.
2. Confirmer `owner_repo`, `owner_agent`, `write_set_roots`, gates et evidence avant toute modification.
3. Utiliser les sous-agents uniquement comme metadata de lane, jamais comme agents API autonomes.
4. Produire une execution ou un handoff strictement contenu dans le write set declare.
5. Finir avec risques restants, gate suivante et evidence mise a jour.
