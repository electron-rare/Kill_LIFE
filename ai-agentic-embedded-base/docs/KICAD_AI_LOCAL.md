# IA & KiCad en local (bulk edits + analyse)

Ce template privilégie **deux couches** complémentaires :

1) **schops** (ce repo) : un CLI simple, traçable, qui fait
   - exports déterministes via `kicad-cli` (ERC / BOM / netlist)
   - bulk edits via `kicad-sch-api` (fields / footprints / labels)
   - packaging de Design Blocks KiCad 9

2) **MCP (optionnel)** : si tu utilises un client IA compatible MCP, tu peux exposer
   des opérations KiCad comme un “tool server” local.

## 1) schops

Install :
```bash
python -m venv .venv && source .venv/bin/activate
pip install -r tools/hw/schops/requirements.txt
```

Workflow typique :
```bash
python tools/hw/schops/schops.py snapshot --schematic <...> --name before.json
python tools/hw/schops/schops.py apply-fields --schematic <...> --rules hardware/rules/fields.yaml
python tools/hw/schops/schops.py apply-footprints --schematic <...> --map hardware/rules/footprints.csv
python tools/hw/schops/schops.py rename-nets --schematic <...> --rules hardware/rules/nets_rename.yaml
python tools/hw/schops/schops.py erc --schematic <...>
python tools/hw/schops/schops.py bom --schematic <...> --exclude-dnp
python tools/hw/schops/schops.py netlist --schematic <...>
python tools/hw/schops/schops.py snapshot --schematic <...> --name after.json
```

Tous les rapports vont dans `artifacts/hw/<timestamp>/`.

## 2) MCP KiCad (optionnel)

Si ton client IA supporte MCP, installe un serveur MCP KiCad basé sur `kicad-sch-api` :

```bash
pip install kicad-sch-api kicad-sch-mcp

# démarre le serveur (stdio)
kicad-sch-mcp
```

### Convention d’intégration recommandée

- **Édits mécaniques** → `schops` (backup + report)
- **Création de schéma / placement** (si besoin) → MCP + validation ensuite via `schops` + `kicad-cli`

> Même avec MCP, garde `kicad-cli` en “source de vérité” pour ERC/BOM/netlist.
