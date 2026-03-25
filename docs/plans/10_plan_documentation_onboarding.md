# 10) Plan de documentation & onboarding

## Objectif
Maintenir une documentation simple, à jour, orientée exécution (pas marketing) avec exemples.

## Labels recommandés
- `type:docs` + `ai:docs`

## Étapes

### 1. Pages indispensables
- [x] `README.md` (pitch + quickstart) — Delivered: `README.md` exists
- [x] `docs/INSTALL.md` — Delivered: `docs/INSTALL.md` exists
- [x] `docs/RUNBOOK.md` — Delivered: `docs/RUNBOOK.md` exists
- [x] `docs/FAQ.md` — Delivered: `docs/FAQ.md` exists

### 2. Exemples
- [x] “Minimal project” (spec + firmware stub + test native) — Delivered: `specs/00_intake.md` through `specs/04_tasks.md` + `firmware/src/main.cpp` + `firmware/test/test_basic.cpp`
- [ ] “Issue → PR” walkthrough

### 3. Docs auto-générées
- [x] Référencer ce qui est généré et ce qui est manuel — Delivered: `docs/index.md` + `.github/workflows/jekyll-gh-pages.yml`
- [x] Garder la nav cohérente — Delivered: `docs/index.md`

### 4. Qualité docs
- [ ] Liens internes OK
- [ ] Commandes testées
- [x] Aucune info sensible — Delivered: `.github/workflows/secret_scan.yml`

## Gates
- Lint markdown (si activé)
- Review humaine

## Critère de sortie
✅ Un nouveau peut exécuter le workflow en 15 minutes sans aide.

## Références
- `docs/index.md`
- `docs/workflows/README.md`