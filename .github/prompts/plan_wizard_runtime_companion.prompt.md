---
name: planWizardRuntimeCompanion
description: Génère un plan canonique pour Runtime-Companion.
argument-hint: Précise la surface runtime, les dépendances externes, la dégradation et les preuves.
---
Génère un plan structuré pour `Runtime-Companion`, aligné sur `specs/contracts/kill_life_agent_catalog.json`.
1. Rappeler la mission, le write set et les sous-agents metadata associés.
2. Identifier dépendances externes, conditions degraded-safe, artefacts et risques de latence ou disponibilité.
3. Lister les étapes avec checks runtime, handoffs et evidence obligatoires.
4. Vérifier que chaque sortie reste dans le write set canonique.
5. Conclure par la validation attendue, le fallback et la prochaine action.
