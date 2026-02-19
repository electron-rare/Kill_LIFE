# Analyse technique Kill_LIFE

## Scripts clés
- scope_guard.py : enforcement CI, mapping labels → allowlist/denylist, sécurité PR.
- cockpit.py : orchestration agents/gates, automatisation des tâches.
- compliance/validate.py : validation des profils, mapping exigences/evidence.
- hw/schops : bulk edits, exports, checks hardware.
- ai/compose_codex_prompt.py : génération de prompts pour Codex.

## Evidence pack
- Généré à chaque gate, mappé dans compliance/plan.yaml.
- Traçabilité des artefacts, logs, rapports.

## Tests
- firmware/test/ : tests unitaires Unity.
- hardware : ERC, netlist, BOM, DRC.
- CI/CD : validation automatique, enforcement des gates.

## Sécurité
- sanitizer : nettoyage des issues/PR.
- OpenClaw : observateur, actions auditées.

## Automatisation
- bulk edits hardware, orchestration agents, validation compliance.

## Points de friction
- Onboarding dense, passage de gates, gestion des exceptions.

## Robustesse
- Bonne couverture CI/CD, sécurité renforcée, traçabilité exemplaire.

---

Pour chaque script, prévoir des tests unitaires, une documentation d’usage, et une intégration CI.