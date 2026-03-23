# YiACAD Native GUI Runbook

Date: `2026-03-20`

## Objectif

Ajouter une premiere couche GUI + utilitaires IA directement dans KiCad et FreeCAD, sans modifier les upstreams pour l'instant.

## Composants ajoutes

- Pont partage: `tools/cad/yiacad_ai_bridge.py`
- Installateur local: `tools/cad/install_yiacad_native_gui.sh`
- Plugin KiCad: `tools/cad/integrations/kicad/yiacad_kicad_plugin/`
- Workbench FreeCAD: `tools/cad/integrations/freecad/YiACADWorkbench/`

## Fonctions exposees

- queue d'une requete IA locale depuis KiCad ou FreeCAD
- lecture du dernier statut YiACAD
- ouverture rapide des artefacts locaux
- routage des demandes dans `artifacts/cad-ai-requests/`

## Installation locale

```bash
bash tools/cad/install_yiacad_native_gui.sh install
bash tools/cad/install_yiacad_native_gui.sh status
```

Par defaut sur macOS:

- KiCad: `~/Library/Application Support/kicad/scripting/plugins`
- FreeCAD: `~/Library/Application Support/FreeCAD/Mod`

## Affectation agents / sous-agents

- `CAD-Fusion`: pilote de la surface GUI IA-native
- `CAD-Bridge`: integrateur plugin/workbench et bridge local
- `CAD-Smoke`: qualifie le chemin de requete et le statut YiACAD
- skill principal: `bash-cli-tui`

## Etat courant

- KiCad: plugin ActionPlugin chargeable, compatible avec le menu `Tools -> External Plugins`
- FreeCAD: workbench Python chargeable avec toolbar/menu `YiACAD AI`
- Les requetes sont versionnees localement dans `artifacts/cad-ai-requests`

## Suite recommandee

1. Brancher les actions KiCad sur l'IPC API lorsque la couche upstream YiACAD passera au fork natif.
2. Ajouter un panneau de retour IA avec lecture des reponses, pas seulement la mise en queue.
3. Connecter les requetes a des utilitaires concrets: ERC/DRC, BOM review, sync ECAD/MCAD, generation STEP.
