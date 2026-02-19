# Guide Workflow API Contract & Integration Testing

## Objectif
Garantir la conformité des API et leur intégration via des tests automatisés.

## Outils utilisés
- Tests d’intégration
- Outils de validation de contrat (OpenAPI, Postman)

## Logique du workflow
- Validation du contrat API à chaque build
- Exécution de tests d’intégration
- Publication des rapports

## Critères de conformité
- Contrat API valide
- Tests d’intégration passés
- Evidence pack mis à jour

## Badge dynamique
- Endpoint JSON : docs/badges/api_contract_badge.json
- Intégration dans README

## Vérification
- Le badge doit afficher le statut de validation API
- Les rapports sont accessibles dans les artefacts CI

---

[Retour à la liste des workflows](../badges/)
