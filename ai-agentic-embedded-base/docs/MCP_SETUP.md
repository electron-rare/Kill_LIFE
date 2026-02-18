# MCP setup (KiCad)

## Option A — Schematic MCP (recommended)
`kicad-sch-api` inclut un serveur MCP : `kicad-sch-mcp`. citeturn0search9

Installation :
```bash
pip install kicad-sch-api
# ou via uv
# uv tool install kicad-sch-mcp
```

Lancer le serveur (dans le repo) :
```bash
kicad-sch-mcp
```

Exemple (Claude Desktop) — à adapter selon ton OS :
```json
{
  "mcpServers": {
    "kicad_schematic": {
      "command": "kicad-sch-mcp",
      "args": []
    }
  }
}
```

## Option B — KiCad “live/PCB” MCP (expérimental)
Il existe des serveurs MCP orientés PCB / IPC API (dépend de ta version KiCad et du serveur choisi). citeturn0search1turn0search16

Dans ce repo, l’approche “robuste” reste :
- bulk edits schéma via `kicad-sch-api`
- exports/DRC via `kicad-cli`
