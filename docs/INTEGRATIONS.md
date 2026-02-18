# Intégrations (V2)

Ce template n'embarque pas de gros framework en dépendance “hard” : il expose des
**interfaces stables** (prompts + scripts + conventions d'artifacts) pour que tu puisses
brancher l'orchestrateur que tu veux.

## agentic-engineer

Idée : l'utiliser comme orchestrateur (plans → exécution) et lui faire appeler :
- les prompts dans `agents/`
- les scripts `tools/` (cockpit, schops, CI local)

Conventions utiles :
- tout ce qui est “preuve” va dans `artifacts/<domain>/<timestamp>/`
- les gates à respecter sont dans `bmad/gates/`

## Spec Kit

- Les specs vivent dans `specs/<feature>/...`
- Un bridge minimal est fourni dans `.specify/` + `tools/ai/specify_init.py`

## Agent OS / Builder Methods

- Standards versionnés dans `standards/`.
- Profils “multi-target” sous `standards/profiles/`.

## KiCad local

- `schops` pour bulk edits + exports
- Option MCP : voir `docs/KICAD_AI_LOCAL.md`
