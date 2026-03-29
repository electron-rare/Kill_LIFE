# Spec CI/CD Multi-cible Hardware-in-the-Loop et YiACAD

## Objectif
Ce workflow doit compiler, tester et valider le firmware sur toutes les cibles (ESP, STM, Linux), générer et publier les artefacts (logs, binaries, rapports de tests), assurer la traçabilité et la reproductibilité (evidence packs), et intégrer la simulation hardware-in-the-loop.

Delta YiACAD `2026-03-29`:

- la lane produit YiACAD ajoute un CI/CD `desktop + web + backend + manufacturing`
- `KiCad >= 10.0` et `FreeCAD >= 1.1` deviennent les floors de smoke desktop
- `KiBot` et `KiAuto` deviennent des lanes Linux/Docker bloquantes pour la fabrication et la validation
- la reference canonique pour YiACAD est `specs/yiacad_plugin_workbench_ci_plan.md`

## Triggers
- Push ou PR sur firmware/, hardware/, specs/
- Modification des scripts d’automatisation (tools/)
- Push ou PR sur web/, tools/cad/, tools/cockpit/, test/, .github/workflows/

## Actions
- Build du firmware pour chaque cible
- Exécution des tests unitaires et hardware-in-the-loop
- Collecte des logs, rapports, binaries
- Génération et publication de l’evidence pack
- Validation des gates (tests, conformité, sécurité)
- Publication des artefacts
- Pour YiACAD:
  - validation des contrats backend
  - build/tests web
  - smoke macOS `KiCad` / `FreeCAD`
  - lanes Linux `KiBot` / `KiAuto`
  - publication des artefacts CAD et du digest evidence

## Gates de sécurité
- Validation des tests sur chaque cible
- Vérification de conformité (absence de secrets, labels PR, artefacts)
- Blocage ou alerte en cas de violation

## Artefacts
- Evidence pack (logs, rapports, binaries, traces)
- Badge de couverture
- Changelog et release notes

## Acceptance Criteria (RFC2119)
- Le firmware MUST compiler sur chaque cible (ESP, STM, Linux)
- Les tests unitaires et hardware-in-the-loop MUST passer
- Un evidence pack MUST être généré et publié
- Les gates de sécurité MUST être validés avant publication
- Les artefacts SHOULD être accessibles dans docs/evidence/ ou compliance/evidence/
- YiACAD MUST valider ses contrats backend, ses smokes desktop et sa lane manufacturing avant release
- YiACAD SHOULD publier un evidence pack lisible par operateur avec `engine_status`, rapports et artefacts

## NFRs
- Latence : le workflow SHOULD s’exécuter en moins de 30 min
- Fiabilité : le workflow MUST détecter et alerter toute anomalie
- Traçabilité : chaque artefact MUST être versionné et lié à la PR
- Reproductibilité : le workflow MUST être idempotent

## Plan de vérification
- Exécution du workflow sur PR/push
- Validation via `python3 tools/validate_specs.py --json`
- Contrôle manuel et badge de couverture

## Glossaire
- Evidence pack : ensemble des artefacts, logs, traces générés lors du workflow
- Hardware-in-the-loop : simulation embarquée pour valider le comportement firmware

---
Ce squelette doit être complété lors de l’implémentation détaillée.

## Delta YiACAD 2026-03-29

Workflows cibles:

- `yiacad-contracts-and-python`
- `yiacad-web-build-and-tests`
- `yiacad-backend-integration`
- `yiacad-cad-smokes`
- `yiacad-manufacturing-bundle`
- `yiacad-evidence-pack`

Separation des runners:

- `macOS` pour les smokes desktop `KiCad` / `FreeCAD`
- `Linux` pour `KiBot`, `KiAuto`, bundles manufacturing, matrices nocturnes

Document canonique associe:

- `specs/yiacad_plugin_workbench_ci_plan.md`
