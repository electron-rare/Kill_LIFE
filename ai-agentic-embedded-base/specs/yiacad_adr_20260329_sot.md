# ADR - YiACAD 2026 source of truth

- **ID**: `ADR-20260329-01`
- **Statut**: Accepted
- **Contexte**:

Au `2026-03-29`, YiACAD a deja un backend `service-first`, des surfaces desktop/web/TUI, et des moteurs integres `KiCad`, `FreeCAD`, `KiBot`, `KiAuto`. Les releases amont recentes changent le point d'equilibre:

- `KiCad 10.0.0` a ete annonce le `2026-03-20`.
- `FreeCAD 1.1` a ete annonce le `2026-03-25`.
- `KiCad` pousse maintenant une integration moderne via `IPC API`, `kicad-python`, `kicad-cli`.
- `KiCanvas` reste utile pour la review web, mais n'est pas un shell d'edition canonique.
- `KiBot` et `KiAuto` restent plus credibles en workers Linux/Docker qu'en experience desktop primaire.

La decision a prendre est donc la suivante: quel est le vrai socle produit YiACAD 2026, et ou placer l'IA, le web, et les moteurs CAD integres.

## Decision

YiACAD adopte le SOT suivant:

1. `YiACAD` est une app independante et la frontiere produit.
2. `KiCad 10.0.x` est le moteur ECAD auteur canonique.
3. `FreeCAD 1.1.x` est le moteur MCAD auteur canonique.
4. `desktop` est la surface d'authoring canonique.
5. `web` est la surface canonique de review, collaboration, artefacts, PR/release, et orchestration.
6. `KiBot` et `KiAuto` sont des moteurs integres d'automatisation, executes prioritairement en Linux/Docker.
7. L'IA YiACAD opere au-dessus du backend, du graphe projet et des artefacts normalises.
8. `MCP` reste une couche d'adaptation, jamais la source de verite du produit.

## Options considerees

1. Conserver une architecture definie par des forks `KiCad` / `FreeCAD`.
2. Basculer vers un produit CAD browser-first avec edition canonique dans le web.
3. Fixer YiACAD comme produit `desktop-first authoring`, `web-first review`, `Linux-first manufacturing`, `AI-first orchestration`.

## Trade-offs

- Cout :
  - option 3 demande une vraie discipline de boundary entre desktop, backend, web et workers
  - elle evite en revanche la maintenance lourde de forks applicatifs complets
- Risque :
  - web editing complet est reporte
  - la coherence produit depend fortement du backend YiACAD et de ses contrats
- Temps :
  - l'option 3 livre plus vite de la valeur reelle sur review, exports, CI et evidence
  - l'option 2 allongerait fortement le temps avant un produit CAD credible
- Complexite :
  - l'option 3 garde plusieurs lanes, mais chaque lane a un role net
  - l'option 1 semble simple a court terme mais explose la dette d'integration a moyen terme
- Conso / perf :
  - desktop authoring profite des moteurs natifs
  - web review reste leger
  - CI Linux concentre les jobs lourds sur des runners adaptes

## Consequences

- les specs YiACAD doivent pinner `KiCad >= 10.0` et `FreeCAD >= 1.1`
- toute nouvelle integration KiCad doit viser `IPC API`, `kicad-python`, ou `kicad-cli`
- toute nouvelle integration FreeCAD doit viser Python API / workbench / addon
- `KiBot` et `KiAuto` doivent etre modeles comme backend actions et jobs CI, pas comme primitives UI
- le web doit rester review-first tant qu'aucune surface browser-side authoring n'est assez mature
- les plugins IA tiers restent des signaux de marche et des probes UX, pas la definition produit de YiACAD

## Validation

- Tests/mesures :
  - revue web officielle `2026-03-29`
  - verification des annonces amont `KiCad 10.0.0` et `FreeCAD 1.1`
  - verification des surfaces officielles KiCad API / PCM / `kicad-python`
  - verification du positionnement officiel de `KiBot`, `KiAuto`, `KiCanvas`, `Yjs`
- Criteres :
  - coherence entre architecture produit, UX, backend, CI/CD
  - reduction de la dette de fork
  - convergence vers une stack credible en production 2026

## References externes

- KiCad release `2026-03-20`: <https://www.kicad.org/blog/2026/03/Version-10.0.0-Released/>
- KiCad APIs and bindings: <https://dev-docs.kicad.org/en/apis-and-binding/>
- KiCad `kicad-python`: <https://docs.kicad.org/kicad-python-main/>
- FreeCAD release `2026-03-25`: <https://blog.freecad.org/2026/03/25/freecad-version-1-1-released/>
- FreeCAD `1.0` baseline: <https://blog.freecad.org/2024/11/19/freecad-version-1-0-released/>
- KiBot docs: <https://kibot.readthedocs.io/en/latest/installation.html>
- KiAuto upstream: <https://github.com/INTI-CMNB/KiAuto>
- KiCanvas: <https://kicanvas.org/home/>
- Yjs websocket docs: <https://docs.yjs.dev/ecosystem/connection-provider/y-websocket>
