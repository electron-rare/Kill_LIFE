# Easter Egg musique concrète

_« Le hardware s’écoute, se manipule, se transforme : comme Bernard Parmegiani, chaque export est une métamorphose électronique. »_
# Hardware quickstart (KiCad)

> "Chaque bloc hardware est une évolution, chaque bulk edit une adaptation, et chaque export une trace laissée pour les générations futures. (Adrian Tchaikovsky, Children of Time)"

## Prérequis
- KiCad 9 installé (inclut `kicad-cli`)
- Python 3.11+
- (optionnel) venv

## Install tools
```bash
python -m venv .venv && source .venv/bin/activate
pip install -r tools/hw/schops/requirements.txt
```

## Checks
```bash
bash tools/hw/hw_check.sh hardware/kicad/<project>/<project>.kicad_sch
```

## Bulk edits

### Champs / propriétés
```bash
python tools/hw/schops/schops.py apply-fields \
  --schematic hardware/kicad/<project>/<project>.kicad_sch \
  --rules hardware/rules/fields.yaml
```

### Footprints
```bash
python tools/hw/schops/schops.py apply-footprints \
  --schematic hardware/kicad/<project>/<project>.kicad_sch \
  --map hardware/rules/footprints.csv
```

### Renommage de nets
```bash
python tools/hw/schops/schops.py rename-nets \
  --schematic hardware/kicad/<project>/<project>.kicad_sch \
  --rules hardware/rules/nets_rename.yaml
```

## Design Blocks (briques)
- stocker sous `hardware/blocks/<lib>.kicad_blocks/`
- créer via `schops block-make ...` (dossier `*.kicad_block` contenant `.kicad_sch` + `.json`)

Exemple :
```bash
python tools/hw/schops/schops.py block-make \
  --name uart_header \
  --from-sheet hardware/kicad/headers/headers.kicad_sch \
  --lib hardware/blocks/connectors.kicad_blocks \
  --description "Header UART (GND/VCC/TX/RX)" \
  --keywords "uart,header,connector"
```
