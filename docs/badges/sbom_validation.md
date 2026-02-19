# Guide Workflow SBOM Validation

## Objectif
Assurer la transparence et la conformité des dépendances logicielles via la génération et la validation d’un SBOM (Software Bill of Materials).

## Outils utilisés
- CycloneDX
- SPDX
- Trivy
- Snyk

## Logique du workflow
- Génération du SBOM à chaque build
- Analyse de vulnérabilités et conformité des dépendances
- Publication du SBOM et des rapports

## Critères de conformité
- SBOM généré et accessible
- Dépendances sans vulnérabilités critiques
- Evidence pack mis à jour

## Badge dynamique
- Endpoint JSON : docs/badges/sbom_validation_badge.json
- Intégration dans README

## Vérification
- Le badge doit afficher le statut SBOM et vulnérabilités
- Les rapports sont accessibles dans les artefacts CI

---

[Retour à la liste des workflows](../badges/)
