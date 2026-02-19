# Guide Workflow Automated Dependency Update

## Objectif
Maintenir les dépendances à jour et sécurisées via des mises à jour automatisées.

## Outils utilisés
- Dependabot

## Logique du workflow
- Détection automatique des dépendances obsolètes
- Création de PR pour mise à jour
- Validation des mises à jour par CI

## Critères de conformité
- Dépendances à jour
- Evidence pack mis à jour

## Badge dynamique
- Endpoint JSON : docs/badges/dependency_update_badge.json
- Intégration dans README

## Vérification
- Le badge doit afficher le statut des mises à jour
- Les rapports sont accessibles dans les artefacts CI

---

[Retour à la liste des workflows](../badges/)
