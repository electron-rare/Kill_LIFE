# Endpoints des Badges Dynamiques CI/CD

Ce fichier recense les endpoints JSON pour chaque badge de workflow CI/CD, utilisables avec shields.io ou tout service de badge dynamique.

## Utilisation
- Chaque endpoint expose le statut du workflow, la conformité, et les artefacts associés.
- Les badges peuvent être intégrés dans le README ou la documentation.

---

| Domaine                        | Endpoint JSON                                 | Exemple Badge Shields.io |
|-------------------------------|-----------------------------------------------|-------------------------|
| Supply Chain Attestation       | docs/badges/supply_chain_badge.json           | ![badge](https://img.shields.io/endpoint?url=docs/badges/supply_chain_badge.json) |
| Secret Scanning                | docs/badges/secret_scan_badge.json            | ![badge](https://img.shields.io/endpoint?url=docs/badges/secret_scan_badge.json) |
| SBOM Validation                | docs/badges/sbom_validation_badge.json        | ![badge](https://img.shields.io/endpoint?url=docs/badges/sbom_validation_badge.json) |
| Release Signing                | docs/badges/release_signing_badge.json        | ![badge](https://img.shields.io/endpoint?url=docs/badges/release_signing_badge.json) |
| Performance & HIL              | docs/badges/performance_hil_badge.json        | ![badge](https://img.shields.io/endpoint?url=docs/badges/performance_hil_badge.json) |
| Evidence Pack Validation       | docs/badges/evidence_pack_badge.json          | ![badge](https://img.shields.io/endpoint?url=docs/badges/evidence_pack_badge.json) |
| Community & Accessibilité      | docs/badges/community_accessibility_badge.json| ![badge](https://img.shields.io/endpoint?url=docs/badges/community_accessibility_badge.json) |
| Data/Model Validation (IA)     | docs/badges/model_validation_badge.json       | ![badge](https://img.shields.io/endpoint?url=docs/badges/model_validation_badge.json) |
| API Contract & Integration     | docs/badges/api_contract_badge.json           | ![badge](https://img.shields.io/endpoint?url=docs/badges/api_contract_badge.json) |
| Dependency Update              | docs/badges/dependency_update_badge.json      | ![badge](https://img.shields.io/endpoint?url=docs/badges/dependency_update_badge.json) |
| Incident Response & Security   | docs/badges/incident_response_badge.json      | ![badge](https://img.shields.io/endpoint?url=docs/badges/incident_response_badge.json) |

---

## Format JSON attendu

```json
{
  "schemaVersion": 1,
  "label": "<domaine>",
  "message": "<statut>",
  "color": "<couleur>",
  "isValid": true,
  "details": {
    "artefacts": ["<url>", ...],
    "lastRun": "<date>"
  }
}
```

---

Pour chaque domaine, le badge dynamique reflète le statut du dernier run CI/CD, la conformité, et l’accès aux artefacts.

> Ce fichier peut être référencé dans le README ou la documentation pour audit et intégration badge.
