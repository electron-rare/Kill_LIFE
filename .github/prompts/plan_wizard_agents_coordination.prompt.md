---
name: planWizardAgentsCoordination
description: Génère un plan de coordination multi-agent pour éviter la redondance et optimiser les workflows.
argument-hint: Spécifie les agents canoniques, étapes communes, handoffs, evidence et synchronisation.
---
Génère un plan structuré pour la coordination multi-agent en prenant `specs/contracts/kill_life_agent_catalog.json` comme source de vérité.

## Checklist commune
- Charger `docs/GLOBAL_MULTI_AGENT_CHECKLIST.md`
- Vérifier `owner_repo`, `owner_agent`, `write_set`, `status`, `evidence`
- Valider les gates BMAD et les contrats de handoff
- Documenter la preuve et la synchronisation dans les surfaces canoniques
- Garder les sous-agents comme metadata de lane, jamais comme agents publics

## Étapes de coordination
1. Identifier quels agents canoniques parmi `PM-Mesh`, `Arch-Mesh`, `Docs-Research`, `Runtime-Companion`, `QA-Compliance`, `Embedded-CAD`, `Web-CAD-Platform`, `UX-Lead`, `Firmware`, `SyncOps`, `Schema-Guard`, `KillLife-Bridge` participent au lot.
2. Définir un unique owner top-level par write set et reléguer les sous-agents au rôle de metadata.
3. Référencer les handoffs, gates et evidence obligatoires dans le plan.
4. Organiser la synchronisation sans redondance entre docs, prompts, runtime et contrats.
5. Clore avec le validateur de catalogue, les risques restants et la prochaine action.
