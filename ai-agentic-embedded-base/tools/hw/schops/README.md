# schops (Schematic Ops)

CLI local pour :
- ERC/BOM/netlist via `kicad-cli`
- bulk edits via `kicad-sch-api` (si installé)
- Design Blocks KiCad 9 (structure + metadata)

> Philosophie : **bulk edits safe** (backup + report) + exports déterministes (kicad-cli).

## Install (local)
```bash
python -m venv .venv && source .venv/bin/activate
python -m pip install -U pip
python -m pip install -r tools/hw/schops/requirements.txt
```

## Usage
```bash
python tools/hw/schops/schops.py --help
```

## Exports (kicad-cli)
```bash
python tools/hw/schops/schops.py erc --schematic hardware/kicad/<proj>/<proj>.kicad_sch
python tools/hw/schops/schops.py netlist --schematic hardware/kicad/<proj>/<proj>.kicad_sch
python tools/hw/schops/schops.py bom --schematic hardware/kicad/<proj>/<proj>.kicad_sch \
  --fields "Reference,Value,Footprint,${DNP}" \
  --group-by "Value,Footprint" \
  --exclude-dnp
```

Les sorties vont dans `artifacts/hw/<timestamp>/`.

## Bulk edits (kicad-sch-api)

### Champs / propriétés
Applique `hardware/rules/fields.yaml` (defaults + règles) et écrit un rapport JSON.

```bash
python tools/hw/schops/schops.py apply-fields \
  --schematic hardware/kicad/<proj>/<proj>.kicad_sch \
  --rules hardware/rules/fields.yaml

# review-only
python tools/hw/schops/schops.py apply-fields --dry-run --schematic ... --rules ...
```

### Footprints
```bash
python tools/hw/schops/schops.py apply-footprints \
  --schematic hardware/kicad/<proj>/<proj>.kicad_sch \
  --map hardware/rules/footprints.csv
```

### Renommage de nets (labels)
```bash
python tools/hw/schops/schops.py rename-nets \
  --schematic hardware/kicad/<proj>/<proj>.kicad_sch \
  --rules hardware/rules/nets_rename.yaml
```

### Snapshot (pour diff)
```bash
python tools/hw/schops/schops.py snapshot --schematic ... --name before.json
# ... modifications ...
python tools/hw/schops/schops.py snapshot --schematic ... --name after.json
```

## Design Blocks (KiCad 9)
Les design blocks sont des dossiers `*.kicad_block` stockés dans une librairie `*.kicad_blocks`.

```bash
python tools/hw/schops/schops.py block-make \
  --name buck_5v \
  --from-sheet hardware/kicad/buck/buck.kicad_sch \
  --lib hardware/blocks/power.kicad_blocks \
  --description "Buck 5V@2A" \
  --keywords "power,buck,5v"

python tools/hw/schops/schops.py block-ls --lib hardware/blocks/power.kicad_blocks
```
