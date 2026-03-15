# Agentic landscape (appliqué à KiCad)

- Spec-driven backbone: Spec Kit citeturn0search2
- Standards injection: Agent OS (standards versionnés + profils) citeturn0search3
- Role workflows + gates: BMAD-METHOD
- Tool-first runtime (local): Agent Zero
- Interop tools: MCP local en `stdio` via le runtime `kicad-mcp`

Le repo fournit :
- `specs/` pour la source de vérité
- `standards/` pour les conventions hardware/firmware
- `bmad/` pour les gates
- `tools/hw/*` pour une exécution locale reproductible
- `hardware_previews.yml` pour des previews PR et un evidence pack
