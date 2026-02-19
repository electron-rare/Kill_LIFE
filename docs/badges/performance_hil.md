# Guide Workflow Performance & HIL

## Objectif
Valider les performances et la robustesse du firmware via des benchmarks et tests Hardware-In-the-Loop (HIL).

## Outils utilisés
- Benchmarks custom
- Émulateur hardware cloud

## Logique du workflow
- Exécution de benchmarks à chaque build
- Tests HIL sur émulateur ou hardware cloud
- Publication des résultats

## Critères de conformité
- Benchmarks passés sans régression
- Tests HIL validés
- Evidence pack mis à jour

## Badge dynamique
- Endpoint JSON : docs/badges/performance_hil_badge.json
- Intégration dans README

## Vérification
- Le badge doit afficher le statut des benchmarks et tests HIL
- Les rapports sont accessibles dans les artefacts CI

---

[Retour à la liste des workflows](../badges/)
