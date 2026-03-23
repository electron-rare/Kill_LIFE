# YiACAD Review Session - 2026-03-21

## Objectif

Poser la première tranche de `T-UX-006`:

- persister la dernière session de revue YiACAD
- la réafficher dans les surfaces Python déjà YiACAD
- la rendre lisible depuis la TUI sans ouvrir les GUI

## Canon

- artefact de session:
  - `artifacts/cad-ai-native/latest_review_session.json`
- artefact d'historique:
  - `artifacts/cad-ai-native/review_history.json`
- lecture TUI:
  - `bash tools/cockpit/yiacad_uiux_tui.sh --action review-session`
  - `bash tools/cockpit/yiacad_uiux_tui.sh --action review-history`
  - `bash tools/cockpit/yiacad_uiux_tui.sh --action review-taxonomy`
  - `bash tools/cockpit/yiacad_uiux_tui.sh --action review-context`

## Ce qui est persistant

- le dernier payload YiACAD structuré reçu par:
  - le plugin KiCad YiACAD
  - le workbench FreeCAD YiACAD
- la persistance reste additive:
  - aucun changement de contrat `yiacad_uiux_output`
  - aucune dépendance à une GUI ouverte
- une taxonomie légère est maintenant calculée à partir de l'action:
  - `review`
  - `analysis`
  - `sync`
  - `status`
  - `artifacts`

## Sources officielles utilisées

- Apple Human Interface Guidelines:
  - Human Interface Guidelines: https://developer.apple.com/design/human-interface-guidelines/
  - Designing for macOS: https://developer.apple.com/design/human-interface-guidelines/designing-for-macos
- Qt Widgets:
  - QMainWindow / saveState / restoreState: https://doc.qt.io/qt-6.8/qmainwindow.html
  - Restoring a Window's Geometry: https://doc.qt.io/qt-6/restoring-geometry.html

## Lecture courte

- la doc Apple recommande de supporter la personnalisation des fenêtres et des vues sous macOS
- Qt documente explicitement la sauvegarde/restauration de l’état des docks et fenêtres
- sur cette tranche, on ne touche pas encore au shell compilé profond:
  - on pose d’abord la persistance de session au niveau des helpers Python déjà stables

## Décision

- `T-UX-006` démarre par la persistance de session, pas par un refactoring profond des docks compilés
- la suite naturelle est:
  - remonter cette session persistante dans les shells compilés quand le write-set sera acceptable
  - enrichir l’inspector persistant avec taxonomie et historique de revue

## Delta 2026-03-21 - T-UX-006D

- le contexte de revue compact est maintenant lisible dans les trois surfaces opératoires déjà ouvertes:
  - bandeau + contexte récent enrichi dans le plugin KiCad
  - trail enrichi avec taxonomie dans le workbench FreeCAD
  - vue opérateur compacte via `review-context` dans la TUI et l’index opérateur
- cette tranche garde le write-set strictement sur les surfaces Python et TUI déjà stabilisées
- la suite naturelle devient:
  - enrichir encore la lecture multi-vues si besoin
  - propager seulement plus tard vers les shells compilés profonds

## Delta 2026-03-21 - T-UX-006E

- `context_ref` retombe maintenant sur un contexte demandé exploitable même quand les fichiers de preuve n'existent pas encore:
  - exemple de preuve: `project:tmp/nonexistent`
- le backend service local a ete relance pour recharger le builder de contexte courant
- la vue `review-context` n'est plus polluee par un header `unknown`, tout en gardant le statut metier `blocked` quand l'entree de preuve reste volontairement invalide

## Delta 2026-03-21 - T-UX-006F

- la preuve utilise maintenant des fixtures de repo stables plutot que des chemins temporaires hors repo
- le `context_ref` recent attendu devient de la forme:
  - `project:yiacad_backend_proof/probe_board`
  - ou `project:yiacad_backend_proof/probe_model`
- la lecture operateur garde donc un contexte plus utile et reproductible

## Delta 2026-03-21 - T-UX-006D contexte de revue

- le review center YiACAD synthétise maintenant un contexte court lisible:
  - session courante
  - taxonomie cumulée
  - trail récent
  - prochaines étapes dédupliquées
- les surfaces Python KiCad et FreeCAD réinjectent ce contexte directement dans leur rendu texte, sans ouvrir les hotspots compilés.
- nouvelle route TUI opérateur:
  - `bash tools/cockpit/yiacad_uiux_tui.sh --action review-context`
  - `bash tools/cockpit/yiacad_operator_index.sh --action review-context`
- repères officiels réutilisés:
  - Apple HIG: https://developer.apple.com/design/human-interface-guidelines/
  - Designing for macOS: https://developer.apple.com/design/human-interface-guidelines/designing-for-macos
  - Qt `QMainWindow`: https://doc.qt.io/qt-6.8/qmainwindow.html
  - Qt restoring geometry/state: https://doc.qt.io/qt-6/restoring-geometry.html
