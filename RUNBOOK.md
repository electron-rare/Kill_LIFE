# Easter Egg musique concrète

_« Le RUNBOOK est un paysage sonore : chaque étape, chaque evidence pack, chaque gate, compose une symphonie de workflow. »_ — Luc Ferrari
# Runbook opérateur

Voir la version détaillée : `docs/RUNBOOK.md`.

## Flux standard (Issue → PR)
1. Créer une issue (idéalement via un template)
2. Ajouter les labels de triage : `type:*`, `prio:*`, `risk:*`, `scope:*`
3. Ajouter le label `ai:*` adapté :
   - `ai:spec` → spec RFC2119 + AC
   - `ai:plan` → architecture + ADR
   - `ai:tasks` → backlog exécutable
   - `ai:impl` → impl + tests
   - `ai:qa` → durcissement
   - `ai:docs` → docs
4. La CI applique : label enforcement + scope guard + build/tests

## Stop
- Ajouter `ai:hold` sur l’issue/PR

## Workflows métiers
Voir `docs/workflows/README.md`.
