# Recherche web OSS - YiACAD refonte globale (2026-03-20)

## Objectif

Identifier les projets et bibliotheques open source les plus pertinents pour la fusion `KiCad + FreeCAD` et pour la couche IA-native associee.

## References prioritaires

| Projet | Type | Interet pour YiACAD | Source |
| --- | --- | --- | --- |
| KiCad | Upstream ECAD | Base canonique pour `kicad manager`, `pcbnew`, `eeschema` et scripting Python | [KiCad/kicad-source-mirror](https://github.com/KiCad/kicad-source-mirror) |
| FreeCAD | Upstream MCAD | Base canonique pour workbench, docks, documents parametriques et automatisation | [FreeCAD/FreeCAD](https://github.com/FreeCAD/FreeCAD) |
| kicadStepUp | Pont ECAD/MCAD | Reconciliation pratique KiCad <-> FreeCAD, utile pour `ECAD/MCAD Sync` | [easyw/kicadStepUpMod](https://github.com/easyw/kicadStepUpMod) |
| CadQuery | CAD scriptable | Parametrisation geometrique, automation et futurs workflows generatifs | [CadQuery/cadquery](https://github.com/CadQuery/cadquery) |
| kicad-mcp | Serveur MCP | Automation, contextualisation et outillage IA pour KiCad | [lamaalrajih/kicad-mcp](https://github.com/lamaalrajih/kicad-mcp) |
| freecad-mcp | Serveur MCP | Equivalent FreeCAD pour orchestration IA et automation | [contextform/freecad-mcp](https://github.com/contextform/freecad-mcp) |
| LibrePCB | Alternative ECAD | Bon point de comparaison UX/EDA, mais moins aligne sur la trajectoire KiCad + FreeCAD | [LibrePCB/LibrePCB](https://github.com/LibrePCB/LibrePCB) |

## Lecture utile

### KiCad

- L'upstream GitHub est un miroir actif de la branche de developpement KiCad.
- La page upstream affiche une release `10.0.0` marquee `Latest` au 20 mars 2026, ce qui confirme que la base locale doit rester pensee comme evolutive et non figee.

### FreeCAD

- FreeCAD reste la base MCAD parametrique ouverte la plus coherente pour un workbench YiACAD, particulierement pour docks, automatisation Python et echanges STEP.

### StepUp

- `kicadStepUp` est l'outil le plus directement utile quand il s'agit de rapprocher ECAD et MCAD sans reinventer le flux d'echange.

### MCP servers

- `kicad-mcp` et `freecad-mcp` montrent qu'une couche MCP ouverte et locale est deja plausible pour les deux mondes; c'est un bon argument pour formaliser un backend YiACAD proprement separable.

## Recommandations

### A utiliser maintenant

- KiCad upstream
- FreeCAD upstream
- kicadStepUp
- kicad-mcp
- freecad-mcp

### A exploiter ensuite

- CadQuery pour la parametrisation et les futures fonctions generatives
- LibrePCB comme point de comparaison UX et simplification, pas comme base de fusion principale

## Conclusion

Le meilleur axe reste celui deja engage: partir des upstreams `KiCad + FreeCAD`, s'appuyer sur `kicadStepUp` pour le trait d'union ECAD/MCAD, et faire converger les shells natifs avec une couche backend YiACAD puis des integrations MCP bien bornees.
