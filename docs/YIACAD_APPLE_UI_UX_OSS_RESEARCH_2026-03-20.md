# YiACAD UI/UX Apple-native - Web Research OSS - 2026-03-20

## Sources Apple officielles

| Source | Apport pour YiACAD |
| --- | --- |
| [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/) | ancrage global des patterns de navigation, toolbars, search fields et inspectors |
| [Human Interface Guidelines for Generative AI](https://developer.apple.com/design/human-interface-guidelines/generative-ai) | cadrage des affordances IA: contrôle utilisateur, transparence, provenance |
| [Design - What's new](https://developer.apple.com/design/whats-new/) | confirme les surfaces Apple actuelles à privilégier pour une refonte alignée |
| [App Intents](https://developer.apple.com/documentation/AppIntents) | ouvre la piste des commandes système, Spotlight et automatisations natives |
| [Foundation Models framework](https://developer.apple.com/apple-intelligence/whats-new/) | trajectoire future pour assistance locale et on-device si la stack cible évolue |
| [Liquid Glass technology overview](https://developer.apple.com/documentation/technologyoverviews/liquid-glass) | utile comme direction visuelle prudente: profondeur, hiérarchie, matière, sans bruit |

## Synthèse Apple retenue

- placer navigation, recherche et actions essentielles au premier niveau;
- limiter le nombre d’actions visibles dans la toolbar;
- faire des inspecteurs contextuels la destination des détails;
- exposer l’IA comme suggestion ou accélération, jamais comme autorité opaque;
- conserver une forte lisibilité des états et de la provenance.

## OSS / briques exploitables

| Projet | Usage potentiel |
| --- | --- |
| [KiCad](https://github.com/KiCad/kicad-source-mirror) | base ECAD native à faire évoluer côté menus, toolbar et panneaux |
| [FreeCAD](https://github.com/FreeCAD/FreeCAD) | base MCAD/workbench à aligner avec le shell YiACAD |
| [KiCad StepUp](https://github.com/easyw/kicadStepUpMod) | référence concrète de pont ECAD/MCAD entre KiCad et FreeCAD |
| [CadQuery](https://github.com/CadQuery/cadquery) | moteur paramétrique utile pour génération/sync guidée |
| [CQ-editor](https://github.com/CadQuery/CQ-editor) | exemple de shell de modélisation avec panneau et commandes dédiées |
| [kicad-mcp](https://github.com/lamaalrajih/kicad-mcp) | interface MCP exploitable pour assistance KiCad plus fine |

## Décisions intégrées

- conserver KiCad et FreeCAD comme socles, pas comme cibles à masquer;
- prendre `KiCad StepUp` comme référence fonctionnelle pour le volet sync ECAD/MCAD;
- utiliser `CadQuery` comme brique optionnelle d’automatisation future, pas comme shell principal;
- faire converger les surfaces autour d’un shell YiACAD commun avant toute montée en sophistication visuelle.

## Delta 2026-03-20 18:12 - Références officielles shell natif

- [KiCad PCB Python Bindings - Action Plugin support](https://dev-docs.kicad.org/en/apis-and-binding/pcbnew/index.html)
  - confirme que les plugins/actions KiCad peuvent apparaître dans le menu des plugins externes et, si le plugin suit les conventions attendues, exposer un bouton de toolbar.
  - implication YiACAD: un regroupement shell `YiACAD Review` dans les toolbars reste cohérent avec le modèle upstream.
- [KiCad IPC API - For add-on developers](https://dev-docs.kicad.org/en/apis-and-binding/ipc-api/for-addon-developers/index.html)
  - confirme que les actions d’add-on peuvent aussi s’enregistrer sur la toolbar du PCB editor.
  - implication YiACAD: le lot shell actuel reste compatible avec une trajectoire future vers des add-ons/IPC plus propres.
- [FreeCAD DockWindowManager class reference](https://freecad.github.io/SourceDoc/d9/d72/classGui_1_1DockWindowManager.html)
  - documente l’enregistrement de docks nommés et le fait que les workbenches doivent préparer leurs dock windows.
  - implication YiACAD: le `YiACAD Inspector` doit rester un dock explicitement nommé et persistant.
- [FreeCAD Developers Handbook - Dock Windows](https://freecad.github.io/DevelopersHandbook/designguide/elements.html)
  - confirme que les docks sont la destination naturelle des panneaux orientés tâche et que les widgets de toolbar plus atypiques demandent davantage de discipline UX.
  - implication YiACAD: l’inspector/review center doit rester côté dock; la toolbar doit surtout jouer le rôle d’entrée rapide.
