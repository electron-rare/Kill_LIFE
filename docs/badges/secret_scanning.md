# Guide Workflow Secret Scanning

## Objectif
Détecter et prévenir la fuite de secrets (clés, tokens, credentials) dans le code source et les artefacts.

## Outils utilisés
- Gitleaks
- TruffleHog

## Logique du workflow
- Scan automatique du dépôt et des artefacts à chaque push/PR
- Rapport détaillé des secrets détectés
- Blocage du workflow en cas de fuite

## Critères de conformité
- Aucun secret détecté dans le code ou les artefacts
- Rapport accessible dans evidence pack

## Badge dynamique
- Endpoint JSON : docs/badges/secret_scan_badge.json
- Intégration dans README

## Vérification
- Le badge doit afficher le statut du dernier scan
- Les rapports sont accessibles dans les artefacts CI

---

[Retour à la liste des workflows](../badges/)
