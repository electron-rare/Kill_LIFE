# Compliance (profiles)

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
