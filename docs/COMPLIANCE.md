# Politique badge & conformité Kill_LIFE

Ce document décrit la stratégie d’intégration, d’automatisation et de vérification des badges pour garantir la conformité, la sécurité et la traçabilité du projet.

## Objectifs
- Assurer la visibilité de la qualité, sécurité, documentation, SBOM et communauté.
- Automatiser la génération et la publication des badges via CI/CD.
- Centraliser les guides badge dans docs/badges/.
- Vérifier l’actualisation à chaque commit (timestamp ≥ commit).
- Intégrer badges et rapports dans l’evidence pack.
- Planifier un audit badge à chaque release majeure.

## Processus
1. Scripts badge exécutés à chaque CI (push/PR).
2. Fichiers summary JSON générés et publiés.
3. Guides badge accessibles dans docs/badges/.
4. Checklist badge en tête du README.
5. Evidence pack inclut badges et rapports.
6. Audit badge documenté dans specs/04_tasks.md.

## Références
- [docs/badges/](docs/badges/)
- [README.md](../README.md)
- [docs/COMPLIANCE.md](../COMPLIANCE.md)
- [specs/04_tasks.md](../../specs/04_tasks.md)

---

Pour toute évolution badge ou conformité, ouvrir une issue labellisée ai:qa ou ai:docs.
# Easter Egg musique expérimentale

_« La conformité, c’est parfois bruitiste : il faut oser saturer les scripts, comme Zbigniew Karkowski. »_
# Compliance (profiles)

> "La conformité est une question de survie, chaque profil une adaptation à l’environnement, et chaque validation un acte de résilience. (Kim Stanley Robinson, Ministry for the Future)"

Ce repo propose **2 profils** sélectionnables :

- `prototype` : démonstrateur interne (pas de CE/RED)
- `iot_wifi_eu` : produit UE Wi‑Fi/BLE (CE/RED + cyber + RoHS/REACH/WEEE)

## Changer de profil

```bash
python tools/compliance/use_profile.py prototype
python tools/compliance/use_profile.py iot_wifi_eu
```

## Valider

```bash
python tools/compliance/validate.py
```

## Intégration KiCad

Le gate hardware exporte déjà `erc.json` + `drc.json` via `kicad-cli`.
Les paramètres DRC de base peuvent être **générés** depuis le profil :

```bash
python tools/hw/drc/generate_custom_rules.py --profile prototype > artifacts/custom_rules_prototype.kicad_dru
```

⚠️ KiCad gère normalement le fichier `.kicad_dru` automatiquement : on utilise ici un **snippet** à coller/importer via Board Setup → Custom Rules.
