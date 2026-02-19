# Guide Workflow Release Automation & Signing

## Objectif
Automatiser la création de releases et garantir leur authenticité par signature cryptographique.

## Outils utilisés
- cosign (sigstore)
- softprops/action-gh-release

## Logique du workflow
- Création automatique de release à chaque tag
- Signature des artefacts de release
- Publication des artefacts signés

## Critères de conformité
- Releases signées et vérifiables
- Evidence pack accessible

## Badge dynamique
- Endpoint JSON : docs/badges/release_signing_badge.json
- Intégration dans README

## Vérification
- Le badge doit afficher le statut de la dernière release signée
- Les artefacts signés sont accessibles dans les releases

---

[Retour à la liste des workflows](../badges/)
