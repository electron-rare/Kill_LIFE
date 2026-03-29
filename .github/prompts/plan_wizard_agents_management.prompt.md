---
name: planWizardAgentsManagement
description: Génère un plan pour la gestion des agents.
argument-hint: Spécifie catalogue, prompts, write sets, rituels, gates, handoffs et evidence.
---
Génère un plan structuré pour la gestion des agents en prenant `specs/contracts/kill_life_agent_catalog.json` comme source de vérité.
1. Partir de la liste canonique top-level: `PM-Mesh`, `Arch-Mesh`, `Docs-Research`, `Runtime-Companion`, `QA-Compliance`, `Embedded-CAD`, `Web-CAD-Platform`, `UX-Lead`, `Firmware`, `SyncOps`, `Schema-Guard`, `KillLife-Bridge`.
2. Vérifier la parité entre contrat, `agents/`, `.github/agents/`, prompts `start_*` et `plan_wizard_*`, README et matrice.
3. Référencer `docs/GLOBAL_MULTI_AGENT_CHECKLIST.md` pour les étapes communes, handoffs et preuves.
4. Garder les sous-agents comme metadata de gouvernance, jamais comme agents API publics.
5. Conclure par le validateur à exécuter, les preuves attendues et la prochaine action.
