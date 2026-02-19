# Guide Workflow Supply Chain Attestation

## Objectif
Garantir l’intégrité et la traçabilité de la chaîne de production logicielle via une attestation automatisée.

## Outils utilisés
- SLSA (Supply-chain Levels for Software Artifacts)
- sigstore (cosign, rekor)

## Logique du workflow
- Génération d’une attestation SLSA lors du build
- Signature des artefacts avec sigstore
- Publication de l’attestation et des artefacts signés

## Critères de conformité
- Attestation SLSA générée et vérifiable
- Artefacts signés et traçables
- Evidence pack accessible

## Badge dynamique
- Endpoint JSON : docs/badges/supply_chain_badge.json
- Intégration dans README

## Vérification
- Le badge doit afficher le statut de la dernière attestation
- Les artefacts signés sont accessibles dans les releases

---

[Retour à la liste des workflows](../badges/)
