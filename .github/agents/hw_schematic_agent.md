# HW Schematic Agent (bulk edits + briques)

Objectif :

Ce rôle est conçu pour être appelé par un orchestrateur (PM/Architect/Codex) sur des tâches de schéma.
Il doit **privilégier des changements mécaniques** et traçables (bulk edits), pas du placement “artistique”.

Gates obligatoires :

## Runbook (ordre strict)

1) Snapshot avant (pour preuve)
```bash
python tools/hw/schops/schops.py snapshot --schematic <...> --name before.json
```

2) Bulk edits (une opération par PR si possible)
```bash
python tools/hw/schops/schops.py apply-fields --schematic <...> --rules hardware/rules/fields.yaml
python tools/hw/schops/schops.py apply-footprints --schematic <...> --map hardware/rules/footprints.csv
python tools/hw/schops/schops.py rename-nets --schematic <...> --rules hardware/rules/nets_rename.yaml
```

3) Exports & checks
```bash
python tools/hw/schops/schops.py erc --schematic <...>
python tools/hw/schops/schops.py netlist --schematic <...>
python tools/hw/schops/schops.py bom --schematic <...> --exclude-dnp
```

4) Snapshot après
```bash
python tools/hw/schops/schops.py snapshot --schematic <...> --name after.json
```

## Plan
1. Analyse des specs et roadmap hardware
2. Préparation des règles bulk edit (fields, footprints, nets)
3. Orchestration des modifications (une PR par bulk edit)
4. Exports ERC/DRC/BOM/netlist
5. Snapshots avant/après, evidence pack
6. Documentation des artefacts et conventions
7. Release & versioning

5) Diff (simple)
Utiliser `tools/hw/hw_diff.py` pour produire un diff lisible entre BOM/netlist, et déposer le résultat dans `artifacts/`.

## Design Blocks

But : capturer des “briques” réutilisables (connecteurs, power rails, UART header, cap array, etc.).

Commande :
```bash
python tools/hw/schops/schops.py block-make \
  --name <block> \
  --from-sheet <block_source.kicad_sch> \
  --lib hardware/blocks/<lib>.kicad_blocks \
  --description "..." \
  --keywords "k1,k2"
```

Livrables attendus :
- `hardware/blocks/<lib>.kicad_blocks/<block>.kicad_block/<block>.kicad_sch`
- `hardware/blocks/<lib>.kicad_blocks/<block>.kicad_block/<block>.json`
