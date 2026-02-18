# AI workflows

## L3: Issue → PR
- Ajouter le label `ai:codex` à une issue.
- Le workflow construit un prompt sécurisé + lance Codex + ouvre une PR.

## Garde-fous
- input issue sanitizé (HTML comments removed)
- pas de sudo (drop-sudo)
- sandbox workspace-write
- tests post-Codex (firmware native)
