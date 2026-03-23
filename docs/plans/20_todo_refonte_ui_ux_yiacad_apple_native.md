# 20) TODO - Refonte UI/UX YiACAD Apple-native

Last updated: 2026-03-21 CET

## P0

- [x] `T-UX-001` Publier l’audit UI/UX Apple-native.
- [x] `T-UX-001` Publier la recherche Apple + OSS.
- [x] `T-UX-001` Publier la feature map dédiée.
- [x] `T-UX-002` Poser la spec UI/UX Apple-native.
- [x] `T-UX-002` Installer les surfaces utilisateur KiCad/FreeCAD.
- [x] `T-UX-002` Brancher les surfaces sur `ERC/DRC`, `BOM Review`, `ECAD/MCAD Sync`, `Status`, `Artifacts`.
- [x] `T-UX-002` Basculer les répertoires utilisateur vers les hooks directs dans les forks natifs.
- [x] `Support UI/UX Ops` Publier la TUI UI/UX avec logs et purge contrôlée.
- [x] `Support UI/UX Ops` Étendre la TUI UI/UX avec `logs-list` et `logs-latest` pour lecture opératoire.

## P1

- [x] `T-UX-004` Ajouter une command palette unifiée dans les surfaces KiCad/FreeCAD déjà contrôlées par YiACAD.
- [x] `T-UX-005` Construire le `review center` avec regroupement par sévérité et provenance.
- [x] `T-UX-006` Ajouter un inspector contextuel pour détails + explications IA.
- [x] `T-UX-006` Ajouter une taxonomie visuelle stable pour `review`, `sync`, `status`, `artifacts`.

## Actif

- [x] `T-UX-003` Première montée native compilée de YiACAD dans les forks `kicad-ki` et `freecad-ki`.
- [x] `T-UX-004` Lot sûr: normaliser `command palette / inspector / review center` dans le workbench FreeCAD et le plugin KiCad, sans ouvrir les hotspots compilés.
- [x] Raccorder les docs d’entrée et runbooks à la lane YiACAD UI/UX.

## Sous-lots actifs

- [x] `T-UX-003A` Regrouper les actions YiACAD dans les toolbars shell KiCad `pcbnew` et `eeschema`.
- [x] `T-UX-003B` Stabiliser le dock workbench FreeCAD `YiACAD Inspector`.
- [x] `T-UX-003C` Unifier les helpers control-layer KiCad et documenter la symetrie PCB/SCH.
  - Resultat: resolution Python YiACAD, appel direct a `yiacad_native_ops.py` et symetrie PCB/SCH alignees sur le plus petit write-set natif.
- [x] `T-UX-003D` Preparer la montee shell FreeCAD via `MainWindow.cpp` seul, sans ouvrir `DockWindowManager.cpp` ni `ComboView.cpp`.
  - Avancement 2026-03-20 23:22 CET: ancrage shell compile `Std_YiACADShellView` cree dans `MainWindow.cpp`, cache par defaut, avec une premiere carte shell alignee sur le contrat YiACAD.
- [x] `T-UX-004A` Poser la palette legere et le review center dans les surfaces deja YiACAD.
- [x] `T-UX-004B` Normaliser le contrat de sortie UX commun (`done|degraded|blocked`, severite, next_steps, artifacts`).
- [x] `Support UI/UX Ops` Exposer la lane active, les owners et les preuves dans la TUI YiACAD.

## Delta 2026-03-20 16:50 CET

- `T-UX-003`: KiCad Manager expose `YiACAD Status` en menu/toolbar natifs.
- `T-UX-003`: FreeCAD expose un `YiACAD Inspector` dockable côté workbench.
- reste à faire sur `T-UX-003`: `pcbnew`, `eeschema`, palette/inspector plus profonds côté shells natifs.
- `T-UX-004`: démarrer par les surfaces déjà YiACAD avant `MainWindow.cpp`, `DockWindowManager.cpp` et `webview_panel.h`.
- `T-UX-003`: `pcbnew` et `eeschema` exposent maintenant un groupe shell `YiACAD Review` dans leurs toolbars natives.

## Delta 2026-03-20 16:10 CET

- la lane `yiacad-fusion` a validé `prepare`, `FreeCAD MCP` et `OpenSCAD MCP`
- le blocage opératoire reste `KiCad MCP host smoke`
- cause actuelle documentée: `mascarade-main` ne contient pas encore `finetune/kicad_mcp_server/dist/index.js`
- effet utile: le doctor KiCad auto retombe maintenant en `container`, mais la montée hôte native complète reste incomplète côté shells KiCad
- impact immédiat:
  - `T-UX-003` reste actif tant que la smoke YiACAD n’est pas totalement verte
  - `T-UX-004` à `T-UX-006` ne doivent pas absorber ce blocage et restent découplés côté UI

## P2

- [ ] `T-UX-007` Identifier puis intégrer les points d’ancrage compilés dans les forks `kicad-ki` et `freecad-ki`.
- [ ] `T-UX-007` Faire converger la toolbar sémantique native côté KiCad et FreeCAD.
- [ ] `T-UX-008` Étudier l’exposition des actions YiACAD via `App Intents`/automatisation locale.
- [ ] `T-UX-008` Qualifier l’usage d’un modèle local/on-device pour assistance de review.

## Delta 2026-03-20 - avancement T-UX-003
- [x] Exposer `YiACAD Status` dans `KiCad Manager`
- [x] Exposer `YiACAD Status` dans `pcbnew`
- [x] Exposer `YiACAD Status` dans `eeschema`
- [x] Raccorder les handlers natifs aux control layers KiCad
- [x] Remplacer le bridge local par des hooks backend YiACAD directs
- [x] Étendre les actions natives vers `ERC/DRC`, `BOM review`, `ECAD/MCAD sync`
- [x] Ouvrir `T-UX-004` avec palette de commandes et inspector persistant multi-surface

## Delta 2026-03-20 - runner natif direct
- [x] Remplacer `yiacad_ai_bridge.py` par `yiacad_native_ops.py` dans `KiCad Manager`
- [x] Remplacer `yiacad_ai_bridge.py` par `yiacad_native_ops.py` dans `pcbnew`
- [x] Remplacer `yiacad_ai_bridge.py` par `yiacad_native_ops.py` dans `eeschema`
- [x] Brancher `YiACAD Status`, `YiACAD ERC/DRC`, `YiACAD BOM Review`, `YiACAD ECAD/MCAD Sync` dans les surfaces KiCad natives
- [x] Brancher les mêmes actions sur le workbench FreeCAD via appel direct au runner YiACAD
- [ ] Remplacer le runner Python local par un backend YiACAD pleinement intégré
- [ ] Ouvrir `T-UX-004` pour palette de commandes, review center et inspector persistant multi-surface

- 2026-03-20 17:10 +0100 - lane parallele `yiacad-uiux-apple-native` activee. Explorateur `T-UX-003` assigne aux points d insertion natifs KiCad/FreeCAD; explorateur `T-UX-004` assigne a la command palette et a l inspector persistant.
- 2026-03-20 17:18 +0100 - normalisation canonique: `T-UX-003` couvre la montee native shell/workbench; la TUI UI/UX reste un support ops deja livre.
- 2026-03-20 17:18 +0100 - lot sur `T-UX-004` ouvert dans les surfaces deja YiACAD (`yiacad_freecad_gui.py`, `yiacad_action.py`) pour preparer palette, inspector et review center sans toucher aux hotspots compiles.
- 2026-03-20 18:12 +0100 - `T-UX-003` pousse un increment shell sur KiCad: regroupement des actions natives dans `pcbnew` et `eeschema` sous `YiACAD Review`.
- 2026-03-20 18:12 +0100 - agents du lot: `CAD-UX / KiCad-Shell`, `CAD-UX / FreeCAD-Shell`, `Doc-Research / OSS-Watch`.
- 2026-03-20 18:18 +0100 - garde-fou `T-UX-003`: `common/eda_base_frame.cpp` reste hors write-set; seules les surfaces editor-locales `toolbars_*` et `*_editor_control.*` sont canoniques pour ce lot.
- 2026-03-20 18:18 +0100 - risque de lot documente: runners shell KiCad synchrones et dupliques entre PCB/SCH, donc toute extension doit rester strictement symetrique.
- 2026-03-20 18:20 +0100 - garde-fou FreeCAD: write-set sûr = `yiacad_freecad_gui.py`; write-set shell compile minimal suivant = `MainWindow.cpp` seul.
- 2026-03-20 18:20 +0100 - `DockWindowManager.cpp` et `ComboView.cpp` restent hors write-set pour eviter double ownership du dock YiACAD et regression globale du shell FreeCAD.
- 2026-03-20 18:35 +0100 - sous-lots explicites ouverts: `T-UX-003A/B/C/D`, `T-UX-004A/B`, `Support UI/UX Ops`.
- 2026-03-20 18:35 +0100 - owners de tranche confirms: `KiCad-Shell`, `FreeCAD-Shell`, `KiCad-Native`, `FreeCAD-Native`, `TUI-Ops`, `OSS-Watch`.
- 2026-03-20 18:52 +0100 - `T-UX-003C` progresse avec une premiere symetrie reelle sur `board_editor_control.cpp` et `sch_editor_control.cpp`, sans ouvrir `EDA_BASE_FRAME`.
- 2026-03-20 22:46 +0100 - `Support UI/UX Ops` ferme: `yiacad_uiux_tui.sh` expose `lane-status`, `owners`, `proofs`, `logs-summary`, `logs-latest`, avec lecture operatoire rejouee.
- 2026-03-20 22:49 +0100 - `T-UX-004B` ferme: contrat de sortie UX YiACAD publie dans `docs/` + `specs/contracts/` et expose dans `yiacad_uiux_tui.sh --action proofs`.
- 2026-03-20 23:06 +0100 - `T-UX-003D` progresse: `MainWindow.cpp` cree un dock shell `Std_YiACADShellView` cache par defaut, sans ouvrir `DockWindowManager.cpp` ni `ComboView.cpp`.
- 2026-03-20 23:22 +0100 - `T-UX-003D` ferme: le dock shell FreeCAD affiche maintenant une premiere carte alignee sur le contrat YiACAD et reste pilotable via son toggle `YiACAD Shell`.

## Delta 2026-03-20 - backlog T-UX-004 structure
- [x] Produire l'audit exhaustif de refonte YiACAD
- [x] Produire la spec `T-UX-004`
- [x] Produire la feature map Mermaid `T-UX-004`
- [x] Definir le contrat de sortie UX commun pour toutes les actions YiACAD
- [ ] Monter la command palette YiACAD sur KiCad et FreeCAD
- [ ] Construire le review center unifie
- [ ] Rendre l'inspector YiACAD persistant et contextuel
- [ ] Raccorder les resultats au contexte projet et aux artefacts

## Consolidation canonique 2026-03-20

- `T-UX-003` est maintenant ferme comme lot parent; la suite shell profonde se deplace vers `T-UX-007`.
- `T-UX-004` est maintenant ferme comme lot parent:
  - doc/contrat: fait
  - implementation palette/review/inspector: faite sur les surfaces Python YiACAD
- prochain front structurel associe:
  - consommer le `context broker` local YiACAD
  - consommer `uiux_output.json`
  - backend plus robuste que le runner Python direct

## Delta 2026-03-21 - T-UX-004A confirme
- [x] Palette legere livree sur plugin KiCad
- [x] Palette legere livree sur workbench FreeCAD
- [x] Review center leger branche sur `--json-output`
- [x] Entree operateur stable publiee pour arbitrer entre lane `20` et lane `21`
- [ ] Inspector persistant de session
- [ ] Review center multi-surface plus riche

## Delta 2026-03-21 - T-UX-005 confirme
- [x] Review center enrichi sur plugin KiCad
- [x] Review center enrichi sur workbench FreeCAD
- [x] Sections `Status`, `Severity`, `Summary`, `Details`, `Context`, `Artifacts`, `Next steps` en place
- [x] Fallback texte conserve
- [ ] Inspector persistant de session
- [ ] Review session persistante multi-surface

## Delta 2026-03-21 - preuve backend UI/UX
- [x] Publier une preuve operateur `KiCad + FreeCAD -> facade backend -> uiux_output`
- [x] Exposer cette preuve via `yiacad_uiux_tui.sh` et `yiacad_operator_index.sh`
- [ ] Continuer sur l'inspector persistant et la session de revue

## Delta 2026-03-21 - T-UX-006A
- [x] Persister la derniere session de revue sur les surfaces Python YiACAD
- [x] Exposer cette session via `yiacad_uiux_tui.sh --action review-session`
- [ ] Etendre cette session persistante aux shells compiles quand le write-set sera acceptable

## Delta 2026-03-21 - T-UX-006B
- [x] Persister un historique de revue YiACAD
- [x] Classer les entrees d'historique avec une taxonomie legere
- [x] Exposer l'historique via `yiacad_uiux_tui.sh` et `yiacad_operator_index.sh`
- [ ] Enrichir ensuite l'inspector persistant avec cette taxonomie et un historique plus riche

## Delta 2026-03-21 - T-UX-006C
- [x] Exposer une vue de taxonomie de revue pour l'operateur
- [x] Relayer cette vue dans l'index operateur
- [ ] Continuer ensuite sur l'inspector contextuel plus riche

## Delta 2026-03-21 - T-UX-006 confirme
- [x] Bandeau de session persistant sur plugin KiCad
- [x] En-tete de session persistant sur workbench FreeCAD
- [x] Dernier contrat et dernier `context_ref` conserves
- [x] Trajet recent / continuite de session visible
- [ ] Session de revue riche multi-vues

## Delta 2026-03-21 - backend service base
- [x] Surfaces Python YiACAD recablees sur un client backend `service-first`
- [x] Fallback direct conserve
- [ ] Extension eventuelle aux surfaces compilees plus profondes

## Delta 2026-03-21 - T-UX-006D
- [x] Exposer un contexte de revue compact cote KiCad avec taxonomie et dernieres actions
- [x] Enrichir le trail FreeCAD avec une synthese de taxonomie
- [x] Exposer `review-context` via `yiacad_uiux_tui.sh` et `yiacad_operator_index.sh`
- [ ] Continuer ensuite seulement si utile vers une session multi-vues plus profonde

## Delta 2026-03-21 - T-UX-006E
- [x] Fournir un `context_ref` deterministe pour les preuves backend meme quand le chemin source ne pointe pas encore vers un fichier existant
- [x] Recharger le backend service local pour prendre en compte ce builder de contexte
- [x] Verdir `review-context` cote header sans masquer le statut metier reel

## Delta 2026-03-21 - T-UX-006F
- [x] Remplacer les chemins de preuve temporaires par des fixtures stables suivies dans le repo
- [x] Garder le statut metier `blocked` tout en fiabilisant le contexte operateur
- [ ] Continuer ensuite vers un contexte projet plus riche que la seule fixture de preuve

## Delta 2026-03-21 - T-UX-006D
- [x] Exposer un contexte de revue synthétique dans le review center YiACAD
- [x] Relayer ce contexte via `yiacad_uiux_tui.sh --action review-context`
- [x] Relayer ce contexte via `yiacad_operator_index.sh --action review-context`

## 2026-03-21 - Lot update
- `T-ARCH-101C` etendu: les surfaces KiCad compilees passent en `service-first` via `tools/cad/yiacad_backend_client.py`, avec auto-start du service local et fallback direct vers `tools/cad/yiacad_native_ops.py`.
- `T-OPS-119` consolide: `tools/cockpit/yiacad_operator_index.sh` devient l'entree operateur stable avec `status`, `uiux`, `global`, `backend`, `proofs` et des alias de compatibilite conserves.
- Risque residuel: aucune validation d'execution n'a ete lancee; l'extension aux call sites compiles restants doit etre traitee dans un lot separe.

## 2026-03-21 - Proofs lane
- Nouveau point d'entree: `bash tools/cockpit/yiacad_proofs_tui.sh --action status`.
- Objectif: centraliser `backend`, `review-session`, `review-history`, `review-taxonomy` et l'hygiene des logs dans une surface canonique sans casser les alias historiques.
- Documentation: `docs/YIACAD_PROOFS_TUI_2026-03-21.md`.

## Delta 2026-03-21 - T-UX-003 / T-UX-004 clos
- [x] Verrouiller la presence des surfaces natives YiACAD via `test/test_yiacad_native_surface_contract.py`
- [x] Fermer `T-UX-003` comme lot parent apres verification des ancrages KiCad/FreeCAD deja livres
- [x] Fermer `T-UX-004` comme lot parent apres verification de la palette, du review center et de la persistance cote plugin/workbench
- [x] Reporter les approfondissements shell compiles sous `T-UX-007` au lieu de laisser `T-UX-003` / `T-UX-004` ouverts par inertie documentaire
