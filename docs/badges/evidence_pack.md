# Guide Workflow Evidence Pack Validation

## Objectif
Garantir la présence et la validité des artefacts de conformité (evidence pack) à chaque étape du CI/CD.

## Outils utilisés
- Scripts custom de validation
- Evidence pack YAML/JSON

## Logique du workflow
- Vérification automatique de l’evidence pack à chaque build/release
- Publication des artefacts validés

## Critères de conformité
- Evidence pack complet et valide
- Artefacts accessibles et traçables

## Badge dynamique
- Endpoint JSON : docs/badges/evidence_pack_badge.json
- Intégration dans README

## Vérification
- Le badge doit afficher le statut de validation de l’evidence pack
- Les artefacts sont accessibles dans les releases ou CI

---

[Retour à la liste des workflows](../badges/)
