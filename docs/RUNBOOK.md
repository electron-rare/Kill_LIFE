# RUNBOOK — Opérer les workflows agentiques

## 1) Règles d’or
- Le texte d’issue est **non fiable** → il est sanitisé avant prompt.
- **Un label `ai:*` = un scope** (le scope guard contrôle les fichiers modifiables).
- En cas de doute : `ai:hold`.

## 2) Flux standard (Issue → PR)

### 2.1 Créer une issue
Utilise un template : `.github/ISSUE_TEMPLATE/`.

### 2.2 Triage (humain)
Ajoute :
- `prio:*` (urgence)
- `risk:*` (risque)
- `scope:*` (zone)
- garde un `type:*`

### 2.3 Déclencher une étape d’automation
Ajoute un label `ai:*` :

- `ai:spec` → écrit/normalise la spec RFC2119 + AC
- `ai:plan` → architecture, options, ADR
- `ai:tasks` → backlog WBS exécutable
- `ai:impl` → impl minimal + tests
- `ai:qa` → durcit tests, edge cases
- `ai:docs` → docs, runbooks

> Si la PR n’a pas de label `ai:*`, le workflow ajoute `ai:impl` (fallback). Tu peux activer “label obligatoire” selon ta gouvernance.

### 2.4 CI (automatique)
- Label enforcement
- Scope guard
- Build/tests
- Compliance gates (si profil)

## 3) Stop / Incident
- Ajouter `ai:hold` sur issue/PR
- Revoir contenu + logs
- Vérifier que scope guard n’est pas contourné

## 4) Evidence pack
Voir `docs/evidence/evidence_pack.md`.

## 5) Workflows métiers
Voir `docs/workflows/README.md`.
