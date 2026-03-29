---
name: startKillLifeBridge
description: Lance le workflow canonique KillLife-Bridge.
argument-hint: Donne le workflow, le bridge tri-repo, l'evidence ou le handoff à stabiliser.
---
Lance le workflow canonique `KillLife-Bridge` en prenant `specs/contracts/kill_life_agent_catalog.json` comme source de verite.
1. Charger l'entree `KillLife-Bridge`, `agents/kill_life_bridge.md` et les surfaces bridge associées.
2. Confirmer `owner_repo`, `owner_agent`, `write_set_roots`, gates et evidence avant toute modification.
3. Utiliser les sous-agents uniquement comme metadata de lane, jamais comme agents API autonomes.
4. Produire une execution ou un handoff strictement contenu dans le write set declare.
5. Finir avec risques restants, gate suivante et evidence mise a jour.
