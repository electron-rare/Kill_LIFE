# Recherche OSS — KiCad / FreeCAD / OpenSCAD pour version IA-native KILL_LIFE

Dernière mise à jour: 2026-03-20

## Critères de sélection

- Intégration IA (MCP ou APIs orientées agent).
- Licence ouverte et maintenance visible.
- Potentiel d’intégration dans un mode "host-first" (sans conteneur par défaut).
- Facilité de fork/adaptation (code Python, structure lisible, docs d’installation).

## Références candidates

### KiCad + MCP

1. [lamaalrajih/kicad-mcp](https://github.com/lamaalrajih/kicad-mcp)
- Type: MCP server pour KiCad (cross-plateforme).
- Usage envisagé: base d’API d’orchestration par agent.
- Signal d’intérêt: cible exactement KiCad + MCP.

2. [lukaalrajih/kicad-mcp-server (sur PyPI)](https://pypi.org/project/kicad-mcp-server/)
- Type: distribution orientée MCP.
- Usage envisagé: réutilisable si stabilité package souhaitée.

3. [KiCad/KiCad](https://github.com/KiCad/KiCad)
- Type: upstream officiel / miroir actif du code source KiCad.
- Usage envisagé: base de fork YiACAD et référence de suivi upstream ECAD.

### KiCad automation classique (non-MCP)

4. [INTI-CMNB/KiBot](https://github.com/INTI-CMNB/KiBot)  
5. [bbernhard/KiBot](https://github.com/bbernhard/KiBot)
- Type: générateur CI/CD (Gerber/BoM/DRC/DRC etc.).
- Usage envisagé: prérequis robuste pour workflows production.

6. [productize/kicad-automation-scripts](https://github.com/productize/kicad-automation-scripts)
7. [INTI-CMNB/KiAuto](https://github.com/INTI-CMNB/KiAuto)
- Type: scripts d’automatisation KiCad.
- Usage envisagé: référence de fallback pour opérations GUI/legacy.

8. [yaqwsx/KiKit](https://github.com/yaqwsx/KiKit)
- Type: automation Python (panelization, exports).
- Usage envisagé: complément de pipeline manufacturier.

9. [MicroType-Engineering/KiBot](https://github.com/MicroType-Engineering/KiBot)
- Type: fork communautaire historique.

### FreeCAD / CAD agents

10. [ATOI-Ming/FreeCAD-MCP](https://github.com/ATOI-Ming/FreeCAD-MCP)
- Type: plugin FreeCAD avec serveur/clients MCP + GUI.
- Usage envisagé: pilote direct GUI + commandes macro.

11. [neka-nat/freecad-mcp](https://github.com/neka-nat/freecad-mcp)
- Type: serveur MCP intégré via addon FreeCAD.
- Usage envisagé: mode addon simple à brancher.

12. [jango-blockchained/mcp-freecad](https://github.com/jango-blockchained/mcp-freecad)
- Type: serveur MCP + addon multi-fournisseur.
- Usage envisagé: option multi-fournisseurs et diagnostics.

13. [contextform/freecad-mcp](https://github.com/contextform/freecad-mcp)
- Type: serveur MCP FreeCAD orienté Claude.
- Usage envisagé: piste IA-native pour pilotage commandé en lane canari.

14. [FreeCAD/FreeCAD](https://github.com/FreeCAD/FreeCAD)
- Type: upstream officiel FreeCAD.
- Usage envisagé: base de fork YiACAD et référence de suivi upstream MCAD.

### OpenSCAD / 3D text-to-geometry

15. [jhacksman/OpenSCAD-MCP-Server](https://github.com/jhacksman/OpenSCAD-MCP-Server)
- Type: MCP server de génération/reconstruction SCAD.
- Usage envisagé: terrain d’expérimentation IA-native paramétrique.

### Bibliothèques de transformation CAD utiles

16. [CadQuery/cadquery](https://github.com/CadQuery/cadquery)
- Type: API Python paramétrique moderne pour CAD scriptable.
- Usage envisagé: couche paramétrique complémentaire à FreeCAD/OpenSCAD dans YiACAD.

17. [easyw/kicadStepUpMod](https://github.com/easyw/kicadStepUpMod)
- Type: bridge KiCad ↔ FreeCAD.
- Usage envisagé: synchronisation ECAD/MCAD utile pour workflow de conversion.

## Plan de tri (proposition)

- Priorité 0: upstreams officiels (`KiCad/KiCad`, `FreeCAD/FreeCAD`) + bridge `easyw/kicadStepUpMod`.
- Priorité 1: kicad-mcp + FreeCAD-MCP (intégration directe agent).
- Priorité 2: KiBot/KiAuto/KiKit pour pipeline de production (builds, DFM, docs).
- Priorité 3: OpenSCAD MCP + CadQuery pour cas paramétriques IA-first.

## Actions proposées

1. Faire un PoC `kicad-mcp` + `lot_mcp_runtime` en mode dry-run.
2. Evaluer la compatibilité de `FreeCAD-MCP` avec les contraintes host-first macOS.
3. Stabiliser une couche `run_*_tui` commune (logs, purge, status) pour KiCad/FreeCAD/OpenSCAD.
4. Suivre `contextform/freecad-mcp` comme alternatif en parallèle (`prep` puis `smoke` de lot YiACAD).
5. Ancrer YiACAD sur `KiCad/KiCad` + `FreeCAD/FreeCAD` avec `easyw/kicadStepUpMod` comme pont ECAD/MCAD.
6. Garder `CadQuery/cadquery` comme surface paramétrique complémentaire, non bloquante.
