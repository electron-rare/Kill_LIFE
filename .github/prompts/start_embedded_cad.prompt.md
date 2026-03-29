---
name: startEmbeddedCad
description: Lance le workflow canonique Embedded-CAD.
argument-hint: Donne la lane KiCad, FreeCAD, fabrication ou CAD native à faire avancer.
---
Lance le workflow canonique `Embedded-CAD` en prenant `specs/contracts/kill_life_agent_catalog.json` comme source de verite.
1. Charger l'entree `Embedded-CAD`, `agents/embedded_cad.md` et les surfaces CAD associees.
2. Confirmer `owner_repo`, `owner_agent`, `write_set_roots`, gates et evidence avant toute modification.
3. Utiliser les sous-agents uniquement comme metadata de lane, jamais comme agents API autonomes.
4. Produire une execution ou un handoff strictement contenu dans le write set declare.
5. Finir avec risques restants, gate suivante et evidence mise a jour.
