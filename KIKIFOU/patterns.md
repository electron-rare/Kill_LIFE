# Patterns d’extension Kill_LIFE

## Ajouter un agent
- Créer un prompt agent (agents/)
- Définir un plan (agents/<agent>_agent.md)
- Intégrer dans BMAD/gates
- Ajouter dans orchestration cockpit

## Ajouter un profil compliance
- Définir dans compliance/active_profile.yaml
- Enrichir compliance/standards_catalog.yaml
- Adapter compliance/plan.yaml
- Ajouter evidence pack spécifique

## Ajouter un block hardware
- Ajouter dans hardware/blocks/
- Documenter dans REGISTRY.md
- Définir metadata .json
- Intégrer dans bulk edits

## Ajouter un gate
- Définir checklist dans bmad/gates/
- Intégrer dans orchestration agents
- Adapter evidence pack

## Ajouter un test
- Ajouter dans firmware/test/ ou hardware
- Intégrer dans CI/CD
- Documenter dans docs/

---

Ces patterns facilitent l’industrialisation, l’extension, et la maintenance du template.