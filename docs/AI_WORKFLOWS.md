# AI workflows

## L3: Issue → PR
- Ajouter le label `ai:*` adapte a l'etape voulue (`ai:spec`, `ai:plan`, `ai:tasks`, `ai:impl`, `ai:qa`, `ai:docs`, `ai:hold`).
- Le workflow construit un prompt sécurisé + lance Codex + ouvre une PR.

## Sequences de reference

- workflow local : `docs/KILL_LIFE_WORKFLOW_LOCAL_SEQUENCE_2026-03-11.md`
- workflow github : `docs/KILL_LIFE_WORKFLOW_GITHUB_SEQUENCE_2026-03-11.md`

Lecture :
- `local` couvre la validation avant dispatch, les checks repo-locaux et les preuves non distantes
- `github` couvre `workflow_dispatch`, statuts, checks CI, artifacts et evidence pack

## Garde-fous
- input issue sanitizé (HTML comments removed)
- pas de sudo (drop-sudo)
- sandbox workspace-write
- tests post-Codex (firmware native)
