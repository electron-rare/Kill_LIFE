# Audit global YiACAD / Kill_LIFE - refonte exhaustive (2026-03-20)

## Resume executif

`Kill_LIFE` dispose deja d'une colonne vertebrale forte: structure spec-first, cockpit outille, evidence packs, plans vivants, lane CAD IA-native et nombreux scripts d'orchestration. Le point faible principal n'est plus l'absence d'outillage mais la densite du systeme: plusieurs couches coexistent (`Kill_LIFE`, `ai-agentic-embedded-base`, `zeroclaw`, forks CAD, MCP runtime, mesh tri-repo), ce qui augmente le cout de lecture, de priorisation et d'alignement.

YiACAD progresse bien sur les surfaces natives KiCad/FreeCAD, mais le projet reste partiellement fragmente entre shell natif, runner Python local, TUI de coordination, docs historisees par deltas et sous-repos voisins.

## 1. Points forts structurels

- Separation nette des grandes surfaces dans `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/specs`, `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/docs`, `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/tools`, `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/artifacts`, `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/firmware`, `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/hardware`.
- Gouvernance deja explicite dans `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/docs/REFACTOR_MANIFEST_2026-03-20.md`, `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/specs/03_plan.md`, `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/specs/04_tasks.md`, `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/docs/plans/12_plan_gestion_des_agents.md`.
- Couverture outillage forte dans `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/tools/cockpit`, `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/tools/hw`, `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/tools/ai`, `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/tools/compliance`, avec conventions de logs deja presentes.
- Cadre YiACAD deja bien pose dans `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/tools/cad`, `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/docs/CAD_AI_NATIVE_FORK_STRATEGY.md`, `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/docs/CAD_AI_NATIVE_HOOKS_2026-03-20.md`, `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/.runtime-home/cad-ai-native-forks`.
- Documentation operatoire riche dans `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/README.md`, `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/docs/index.md`, `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/docs/RUNBOOK.md`, `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/docs/QUICKSTART.md`.

## 2. Points faibles et risques majeurs

- Superposition de plusieurs coeurs de projet: `/Users/electron/Documents/Lelectron_rare/Kill_LIFE`, `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/ai-agentic-embedded-base`, `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/zeroclaw`, `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/openclaw`, ce qui rend la frontiere canonique moins evidente.
- Multiplication des points d'entree TUI/cockpit dans `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/tools/cockpit` et `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/tools/tui`; l'operateur doit encore connaitre plusieurs scripts pour couvrir un meme lot.
- Dette de cohesion documentaire: de nombreux documents sont bons individuellement, mais la navigation depend encore beaucoup d'ajouts chronologiques et de memorisation implicite.
- Couche YiACAD encore basee sur un runner Python local (`/Users/electron/Documents/Lelectron_rare/Kill_LIFE/tools/cad/yiacad_native_ops.py`) plutot que sur un backend embarque plus robuste.
- `artifacts/*` est riche mais volumineux; sans resume plus agressif et politique de retention centralisee, le bruit operationnel va augmenter.
- Les forks natifs sous `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/.runtime-home/cad-ai-native-forks` ameliorent l'experience, mais introduisent un couplage supplementaire avec le repo principal.

## 3. Opportunites d'amelioration immediates

- Unifier la refonte globale dans une TUI dediee, orientee audit/spec/plan/todo/research/logs, pour eviter de disperser la navigation entre plusieurs scripts.
- Introduire une architecture backend YiACAD explicite: `native shell -> stable service API -> native ops`, au lieu de faire porter la coordination au seul runner Python local.
- Consolider une matrice de proprietaires par write-set pour les zones les plus sensibles: forks CAD, docs canoniques, cockpit, mesh tri-repo, runtime MCP.
- Reduire la surface cognitive du repo principal en clarifiant le statut de `ai-agentic-embedded-base`, `zeroclaw` et `openclaw`: source canonique, dependance, ou sous-projet orchestre.
- Centraliser les cartes de fonctionnalites et audits de refonte sous un bundle unique YiACAD global afin de limiter les documents paralleles a faible discoverabilite.

## 4. Zones deja matures

- Cockpit et orchestration: `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/tools/cockpit`.
- Gouvernance refonte et agentique: `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/docs/REFACTOR_MANIFEST_2026-03-20.md`, `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/docs/plans/12_plan_gestion_des_agents.md`, `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/docs/plans/18_plan_enchainement_autonome_des_lots_utiles.md`.
- Documentation YiACAD UI/UX et CAD native: `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/docs/YIACAD_APPLE_UI_UX_AUDIT_2026-03-20.md`, `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/docs/YIACAD_NATIVE_UI_INSERTION_POINTS_2026-03-20.md`, `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/docs/CAD_AI_NATIVE_GUI_RUNBOOK_2026-03-20.md`.
- Utilities CAD IA-native: `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/tools/cad/yiacad_fusion_lot.sh`, `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/tools/cad/yiacad_native_ops.py`.
- Support MCP et smoke tooling: `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/tools/freecad_mcp.py`, `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/tools/openscad_mcp.py`, `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/tools/github_dispatch_mcp.py`, `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/tools/knowledge_base_mcp.py`.

## 5. Zones encore fragmentees

- Refonte globale versus refonte UI/UX: beaucoup d'elements existent, mais la couche "audit global + lot suivant" n'etait pas encore assemblee en bundle unique.
- Ia-native CAD versus backend profond: les shells natifs existent, mais la couche metier reste decentralisee entre runner, scripts, artifacts et conventions de contexte projet.
- Tri-repo mesh et ZeroClaw: l'intention est documentee, mais la lisibilite operateur reste inferieure a celle de la lane YiACAD.
- README, manifestes, plans et TODOs sont riches mais demandent encore une discipline forte de convergence pour eviter les cartes paralleles.

## 6. Priorites recommandees

### P0

- Ouvrir un lot global de refonte YiACAD avec cockpit dedie, spec, plan, todo, audit et recherche centralises.
- Formaliser le prochain palier backend YiACAD afin de sortir du simple runner Python local.
- Stabiliser le lien entre refonte globale et `T-UX-004` pour que la command palette, le review center et l'inspector persistant deviennent le prochain objectif UX.

### P1

- Rationaliser les points d'entree TUI par domaine.
- Reduire la dette d'indexation documentaire via README + docs/index + TUI.
- Clarifier le statut fonctionnel de chaque sous-repo majeur.

### P2

- Remonter progressivement les integrations YiACAD vers un service plus embarque.
- Ajouter une lecture de maturite par lane avec KPI et resumés d'etat stables.

## 7. Lecture courte priorisee

1. La structure est solide.
2. La complexite vient surtout de l'empilement des couches et du nombre d'entrees.
3. La meilleure amelioration immediate est une couche de pilotage global YiACAD qui unifie audit, plans, recherche, feature map et logs.
