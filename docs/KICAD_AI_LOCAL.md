# IA & KiCad en local (bulk edits + analyse)

Ce template privilégie **deux couches** complémentaires :

1) **schops** (ce repo) : un CLI simple, traçable, qui fait
   - exports déterministes via `kicad-cli` (ERC / BOM / netlist)
   - bulk edits via `kicad-sch-api` (fields / footprints / labels)
   - packaging de Design Blocks KiCad 10

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

Si ton client IA supporte MCP, le chemin supporté dans ce workspace est le launcher local de `Kill_LIFE`, branché sur le serveur `mascarade/finetune/kicad_mcp_server` :

```bash
tools/hw/run_kicad_mcp.sh --doctor
tools/hw/run_kicad_mcp.sh
```

### Convention d’intégration recommandée

- **Édits mécaniques** → `schops` (backup + report)
- **Création de schéma / placement** (si besoin) → MCP + validation ensuite via `schops` + `kicad-cli`

> Même avec MCP, garde `kicad-cli` en “source de vérité” pour ERC/BOM/netlist.

## 3) Stack locale intégrée Kill_LIFE

`Kill_LIFE` embarque maintenant directement une couche d’exécution locale :

- `kicad-headless` via une image KiCad 10 compatible (`kicad/kicad:nightly` par défaut)
- `kicad-mcp` en `stdio` via le launcher `tools/hw/run_kicad_mcp.sh`
- `freecad-headless` via `FreeCADCmd`
- `platformio` via `pio`

Le point important est le suivant :

- `stdio` reste le bon transport MCP en local
- `Streamable HTTP` ne doit être ajouté que pour un vrai serveur distant

Le détail du pont entre les deux repos est documenté dans [MASCARADE_BRIDGE.md](MASCARADE_BRIDGE.md).

La configuration MCP versionnée est documentée dans [MCP_SETUP.md](MCP_SETUP.md).

Point d’entrée pratique côté `Kill_LIFE` :

```bash
tools/hw/cad_stack.sh doctor
tools/hw/cad_stack.sh kicad-cli version
tools/hw/cad_stack.sh mcp
```
