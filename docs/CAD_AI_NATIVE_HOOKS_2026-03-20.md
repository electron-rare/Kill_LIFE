# CAD AI Native Hooks - 2026-03-20

## Objectif

Basculer les surfaces utilisateur KiCad et FreeCAD de YiACAD vers des hooks directs dans les forks natifs, sans passer par le bridge générique.

## Surfaces natives

- KiCad: `.runtime-home/cad-ai-native-forks/kicad-ki/scripting/plugins/yiacad_kicad_plugin`
- FreeCAD: `.runtime-home/cad-ai-native-forks/freecad-ki/src/Mod/YiACADWorkbench`

## Utilitaires concrets

- `python3 tools/cad/yiacad_native_ops.py kicad-erc-drc --source-path <path>`
- `python3 tools/cad/yiacad_native_ops.py bom-review --source-path <path>`
- `python3 tools/cad/yiacad_native_ops.py ecad-mcad-sync --source-path <path>`
- `python3 tools/cad/yiacad_native_ops.py status`

## Artefacts

- Dossier: `artifacts/cad-ai-native/`
- Chaque exécution génère `summary.md`, `result.json` et les logs stdout/stderr des commandes CAD invoquées.

## Bascule utilisateur

La reliaison des surfaces utilisateur vers les forks natifs se fait avec:

```bash
bash tools/cad/switch_yiacad_surfaces_to_native_forks.sh
```

## Notes de câblage

- KiCad déclenche directement `ERC/DRC`, `BOM Review`, `ECAD/MCAD Sync`, `Status`, `Artifacts`.
- FreeCAD expose les mêmes utilitaires depuis un workbench dédié, en réutilisant le document actif pour retrouver les fichiers KiCad voisins.
- `ECAD/MCAD Sync` exporte les artefacts STEP côté KiCad et tente l’export STEP côté FreeCAD quand un runtime headless est disponible.

## Delta 2026-03-20 - extension KiCad compiled shells
- `KiCad Manager`, `pcbnew` et `eeschema` disposent maintenant chacun d'une entrée native `YiACAD Status`.
- Les premières interactions restent volontairement modestes: affichage de statut via le bridge local, sans divergence backend supplémentaire.
- Ce palier valide l'occupation du chrome compilé KiCad avant la montée vers les workflows IA complets `ERC/DRC`, `BOM review` et `ECAD/MCAD sync`.

## Delta 2026-03-20 - direct native runner
- La première génération de hooks directs YiACAD est désormais en place.
- KiCad et FreeCAD ne s'appuient plus sur `yiacad_ai_bridge.py` pour les surfaces natives principales.
- Le socle d'actions exposé depuis les UIs est homogène entre ECAD et MCAD: `Status`, `ERC/DRC`, `BOM Review`, `ECAD/MCAD Sync`.
- La prochaine étape de refonte porte sur l'expérience d'orchestration et de lecture des résultats, pas sur la simple disponibilité des commandes.
