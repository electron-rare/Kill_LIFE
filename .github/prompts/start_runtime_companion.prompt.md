---
name: startRuntimeCompanion
description: Lance le workflow canonique Runtime-Companion.
argument-hint: Donne la surface runtime, MCP, provider bridge ou dégradation à traiter.
---
Lance le workflow canonique `Runtime-Companion` en prenant `specs/contracts/kill_life_agent_catalog.json` comme source de verite.
1. Charger l'entree `Runtime-Companion`, `agents/runtime_companion.md` et les contrats runtime lies.
2. Confirmer `owner_repo`, `owner_agent`, `write_set_roots`, gates et evidence avant toute modification.
3. Utiliser les sous-agents uniquement comme metadata de lane, jamais comme agents API autonomes.
4. Produire une execution ou un handoff strictement contenu dans le write set declare.
5. Finir avec risques restants, gate suivante et evidence mise a jour.
