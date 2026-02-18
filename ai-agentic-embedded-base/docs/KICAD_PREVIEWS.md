# PR previews (SVG) + evidence pack

Ce repo génère automatiquement :
- schéma en SVG (1 fichier / sheet)
- PCB en SVG (layers sélectionnés)
- ERC + DRC en JSON
- BOM + netlist

Via `kicad-cli` (local) ou l’image Docker officielle KiCad. citeturn1view0turn0search3turn0search7

## Local
```bash
bash tools/hw/hw_gate.sh hardware/kicad
# ou
python tools/hw/exports.py --schematic hardware/kicad/<proj>/<proj>.kicad_sch --pcb hardware/kicad/<proj>/<proj>.kicad_pcb
```

## CI
Le workflow `hardware_previews.yml` exporte ces fichiers et les publie en artifacts pour review PR.
