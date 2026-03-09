# Agentic landscape (appliqué à KiCad)

- Spec-driven backbone: Spec Kit citeturn0search2
- Standards injection: Agent OS (standards versionnés + profils) citeturn0search3
- Role workflows + gates: BMAD-METHOD
- Tool-first runtime (local): Agent Zero
- Native operator runtime: ZeroClaw CLI/gateway on the operator machine
- Optional orchestration overlay: LangGraph around ZeroClaw
- Interop tools: MCP local en `stdio` via le runtime `kicad-mcp`

Posture operateur retenue:
- `ZeroClaw` reste un runtime local demarrable a la demande.
- `LangGraph`, `AutoGen` et `n8n` restent des overlays/runbooks autour de ce runtime.
- `zeroclaw.saillant.cc` sert la surface live du runtime natif quand il est demarre.
- `zeroclaw-docs.saillant.cc` et `langgraph.saillant.cc` servent les runbooks operateur derriere le proxy.
- Le fallback provider `OpenRouter` est valide en runtime sur le gateway natif.

Le repo fournit :
- `specs/` pour la source de vérité
- `standards/` pour les conventions hardware/firmware
- `bmad/` pour les gates
- `tools/hw/*` pour une exécution locale reproductible
- `hardware_previews.yml` pour des previews PR et un evidence pack
