# AI workflows

## L3: Issue → PR
- Ajouter le label `ai:*` adapte a l'etape voulue (`ai:spec`, `ai:plan`, `ai:tasks`, `ai:impl`, `ai:qa`, `ai:docs`, `ai:hold`).
- Le workflow construit un prompt sécurisé + lance Codex + ouvre une PR.

## Garde-fous
- input issue sanitizé (HTML comments removed)
- pas de sudo (drop-sudo)
- sandbox workspace-write
- tests post-Codex (firmware native)
