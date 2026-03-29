---
name: planWizardWebCadPlatform
description: Génère un plan canonique pour Web-CAD-Platform.
argument-hint: Précise la surface Next.js, GraphQL, Yjs, BullMQ ou review concernée.
---
Génère un plan structuré pour `Web-CAD-Platform`, aligné sur `specs/contracts/kill_life_agent_catalog.json`.
1. Rappeler la mission, le write set et les sous-agents metadata associés.
2. Identifier dépendances web, risques de cohérence, latence, queue et evidence attendue.
3. Lister les étapes avec checkpoints API, realtime, worker et handoffs.
4. Vérifier que chaque sortie reste dans le write set canonique.
5. Conclure par la validation attendue, le fallback et la prochaine action.
