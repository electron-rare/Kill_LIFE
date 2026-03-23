# Veille OSS (Open Source) — Refonte Kill_LIFE

Date: `2026-03-21`
Période de capture: `2026-03-20` → `2026-03-21` (révisions incrémentales recommandées toutes les 2 semaines)

Objectif: référencer les briques OSS utiles à la refonte IA-native, triées par surface et priorité.

Voir aussi: `docs/OSS_AI_NATIVE_CAD_RESEARCH_2026-03-20.md` pour la vue dédiée KiCad/FreeCAD/OpenSCAD.

## Méthode d’évaluation

- Compatibilité protocol/cadence: capacité d’intégration dans `Kill_LIFE` (`agentic` / `MCP` / `host-first`) — 0 à 1.
- Qualité maintenable: qualité docs, activité récente, tests/CI — 0 à 1.
- Risque opérationnel: faible impact / pas de dépendances cachées / reversibilité — 1 = faible risque.
- Potentiel de plug-in immédiat dans le runtime — 0 à 1.

Score global = moyenne pondérée (0.30 + 0.30 + 0.20 + 0.20).

## Delta verification officielle 2026-03-21

Cette passe ajoute une verification a jour sur les sources officielles les plus structurantes pour `Kill_LIFE`.

| Source officielle | Date cle | Signal verifie | Decision Kill_LIFE |
| --- | --- | --- | --- |
| [MCP blog - November 2025 spec release](https://blog.modelcontextprotocol.io/posts/2025-11-25-first-mcp-anniversary/) | 2025-11-25 | MCP se confirme comme standard de fait; la release officielle ajoute une nouvelle version de la specification | **ADOPT NOW** pour les contrats et la couche discovery/outils |
| [MCP blog - next release update](https://blog.modelcontextprotocol.io/posts/2025-09-26-mcp-next-version-update/) | 2025-09-26 | la trajectoire 2025 mentionne explicitement structured tool outputs, OAuth-based authorization et elicitation | **ADOPT PARTIAL** pour la securite et la granularite des interactions; **DO NOT CLONE** tout le protocole de gouvernance |
| [VS Code Language Model Tool API](https://code.visualstudio.com/api/extension-guides/tools) | verifie 2026-03-21 | VS Code agent mode distingue `extension tools`, `built-in tools` et `MCP tools` | **ADOPT NOW** pour cadrer `studio/mesh/operator`: preferer MCP quand l'outil doit vivre hors VS Code, preferer tool natif quand l'integration editeur est essentielle |
| [VS Code Chat tutorial](https://code.visualstudio.com/api/extension-guides/ai/chat-tutorial) | publie recemment | les chat participants restent la voie officielle pour specialiser une extension autour d'un role clair | **ADOPT PARTIAL**: garder `@killstudio`, `@killmesh`, `@killops` tres specialises |
| [OpenAI Agents SDK - Agents](https://openai.github.io/openai-agents-python/agents/) | verifie 2026-03-21 | `tools`, `handoffs`, `mcp_servers`, `guardrails`, `output_type` sont des primitives stables | **ADOPT PARTIAL** comme vocabulaire et pattern de coordination |
| [OpenAI Agents SDK - Handoffs](https://openai.github.io/openai-agents-js/guides/handoffs/) | verifie 2026-03-21 | le handoff officiel renforce le pattern orchestrateur -> sous-agent specialise | **ADOPT PARTIAL** pour le format de relais court via `summary-short/v1` |
| [OpenAI Agents SDK - Tracing](https://openai.github.io/openai-agents-js/guides/tracing/) | verifie 2026-03-21 | tracing builtin pour runs, outils, handoffs, guardrails | **ADOPT PARTIAL** comme pattern d'observabilite, pas comme dependance centrale du cockpit |
| [LangGraph overview](https://docs.langchain.com/oss/python/langgraph/overview) | verifie 2026-03-21 | durable execution, checkpoints, human-in-the-loop restent le coeur du positionnement | **DEFER**: overlay de workflows longs seulement apres stabilisation du control plane local |

Synthese de cette verification:

- `MCP` est confirme comme priorite d'integration numero 1.
- `VS Code` confirme une strategie hybride: tools natifs dans l'editeur quand necessaire, `MCP tools` pour les surfaces reutilisables.
- `OpenAI Agents SDK` est surtout une reference de patterns `handoffs/tools/tracing`, pas un coeur documentaire a adopter tel quel.
- `LangGraph` reste une option de niveau superieur pour l'orchestration longue, apres convergence des contrats et de la memoire cockpit.

## Tableaux candidats

### MCP et orchestration

| Projet | Score | Source | Usage visé |
| --- | --- | --- | --- |
| [modelcontextprotocol/servers](https://github.com/modelcontextprotocol/servers) | 0.98 | GitHub | Référence des serveurs MCP maintenus, patterns de runtime, couverture de test |
| [Model Context Protocol Docs](https://modelcontextprotocol.io/docs/getting-started/intro) | 0.97 | Documentation officielle | Contrats, transport, sécurité, format JSON-RPC |
| [Model Context Protocol Registry](https://registry.modelcontextprotocol.io/) | 0.94 | Documentation officielle | Discovery et catalogues de serveurs externes |
| [openai-agents-python](https://openai.github.io/openai-agents-python/) | 0.84 | Documentation officielle | Sessions IA, runnables, gestion d’outils/handoff |
| [AutoGen](https://github.com/microsoft/autogen) | 0.82 | GitHub | Multi-agent patterns et délégation de tâches |
| [LangGraph](https://docs.langchain.com/oss/python/langgraph/overview) | 0.82 | Documentation officielle | Workflows longs + reprise d’état |
| [n8n](https://docs.n8n.io/) | 0.76 | Documentation officielle | Orchestration opérateur par flux no-code |

### CAD / KiCad / FreeCAD

| Projet | Score | Source | Usage visé |
| --- | --- | --- | --- |
| [lamaalrajih/kicad-mcp](https://github.com/lamaalrajih/kicad-mcp) | 0.89 | GitHub | Serveur MCP dédié KiCad, testable en prototype |
| [circuit-synth/kicad-sch-api](https://github.com/circuit-synth/kicad-sch-api) | 0.88 | GitHub | API HTTP ciblée sur schématique KiCad |
| [mixelpixx/KiCAD-MCP-Server](https://github.com/mixelpixx/KiCAD-MCP-Server) | 0.83 | GitHub | MCP complet KiCad (macOS/Linux/Windows), 52 outils annoncés |
| [Finerestaurant/kicad-mcp-python](https://github.com/Finerestaurant/kicad-mcp-python) | 0.81 | GitHub | Implémentation MCP via IPC officiel KiCad (stabilité potentielle) |
| [KiCad/KiCad](https://github.com/KiCad/KiCad) | 0.90 | GitHub officiel | Substrat upstream ECAD et base de fork YiACAD |
| [neka-nat/freecad-mcp](https://github.com/neka-nat/freecad-mcp) | 0.83 | GitHub | Serveur MCP FreeCAD expérimental |
| [jango-blockchained/mcp-freecad](https://github.com/jango-blockchained/mcp-freecad) | 0.78 | GitHub | Serveur MCP FreeCAD avec architecture plugin et exports |
| [ATOI-Ming/FreeCAD-MCP](https://github.com/ATOI-Ming/FreeCAD-MCP) | 0.80 | GitHub | PoC de pilotage FreeCAD via MCP |
| [contextform/freecad-mcp](https://github.com/contextform/freecad-mcp) | 0.81 | GitHub | MCP orienté CLAUDE + automation FreeCAD |
| [FreeCAD/FreeCAD](https://github.com/FreeCAD/FreeCAD) | 0.91 | GitHub officiel | Substrat upstream MCAD et base de fork YiACAD |
| [FreeCAD MCP (wujoseph)](https://wujoseph.com/work/freecad-mcp) | 0.70 | Personal portfolio | Projet annexe de preuve de concept IA-native |
| [FreeCAD Python API docs](https://wiki.freecadweb.org/FreeCAD_scripting_tutorial) | 0.77 | Documentation officielle | Scripts macro et automatisation locale |
| [KiCad documentation](https://docs.kicad.org/) | 0.72 | Documentation officielle | Référence stable des commandes et exports |
| [KiCad Automation Scripts](https://github.com/yaqwsx/KiKit) | 0.74 | GitHub | Génération automatique d’artefacts PCB |
| [easyw/kicadStepUpMod](https://github.com/easyw/kicadStepUpMod) | 0.88 | GitHub | Bridge ECAD/MCAD KiCad ↔ FreeCAD pour YiACAD |
| [CadQuery/cadquery](https://github.com/CadQuery/cadquery) | 0.84 | GitHub | Couche paramétrique Python complémentaire à FreeCAD/OpenSCAD |
| [KiCad GitHub Actions via Wokwi CI](https://docs.wokwi.com/wokwi-ci/github-actions) | 0.83 | Documentation officielle | Workflow de simulation/emulation embarquée |

### Veille de vérification rapide (mise à jour 2026-03-20)

- Les trois projets KiCad/FreeCAD MCP restent actifs mais hétérogènes côté maturité; priorité Kill_LIFE: **proto canari** puis **rétroaction lot**.
- Sources vérifiées récemment:
  - [KiCad/KiCad](https://github.com/KiCad/KiCad) (upstream officiel)
  - [FreeCAD/FreeCAD](https://github.com/FreeCAD/FreeCAD) (upstream officiel)
  - [KiCad MCP by lamaalrajih](https://github.com/lamaalrajih/kicad-mcp) (GitHub)
  - [FreeCAD MCP by ATOI-Ming](https://github.com/ATOI-Ming/FreeCAD-MCP) (GitHub)
  - [FreeCAD MCP by neka-nat](https://github.com/neka-nat/freecad-mcp) (GitHub)
  - [FreeCAD MCP (jango-blockchained)](https://github.com/jango-blockchained/mcp-freecad) (GitHub)
  - [Projet FreeCAD MCP (wujoseph)](https://wujoseph.com/work/freecad-mcp) (cas pratique)
  - [FreeCAD MCP (contextform)](https://github.com/contextform/freecad-mcp) (GitHub)
  - [easyw/kicadStepUpMod](https://github.com/easyw/kicadStepUpMod) (bridge ECAD/MCAD)
  - [CadQuery/cadquery](https://github.com/CadQuery/cadquery) (paramétrique Python)

### Firmware / validation continue

| Projet | Score | Source | Usage visé |
| --- | --- | --- | --- |
| [PlatformIO unit testing](https://docs.platformio.org/en/latest/advanced/unit-testing/index.html) | 0.80 | Documentation officielle | Validation robuste des lots firmware |
| [MCP runtime tooling](https://docs.platformio.org/en/latest/integration/github-actions.html) | 0.70 | Documentation officielle | CI GitHub standardisée |
| [Modeling + CAD automation scripts](https://wiki.freecadweb.org/Macro) | 0.69 | Documentation | Modèles de macro et scriptable |

### Répartition de charge / pilotage P2P (scripts op)

| Projet | Score | Source | Usage visé |
| --- | --- | --- | --- |
| [croniter](https://github.com/pallets-eco/croniter) | 0.72 | GitHub | Planification récurrente (TTL, audits, purges) côté TUI/shell |
| [apscheduler](https://github.com/agronholm/apscheduler) | 0.66 | GitHub | Scheduler applicatif léger pour health checks si pilotage Python futur |
| [Keepalived](https://www.keepalived.org/) | 0.70 | Documentation | Concepts de bascule/health checks de services dans architecture multi-hôtes |
| [HAProxy](https://www.haproxy.org/) | 0.78 | Documentation | Répartition de requêtes avec routage basé santé/charge |
| [supervisord](https://github.com/Supervisor/supervisor) | 0.66 | GitHub | Supervision processuelle et relance pour scripts de runbook |

### Agents et TUI opératoire (revue web complémentaire 2026-03-20)

| Projet | Score | Source | Usage visé |
| --- | --- | --- | --- |
| [LangGraph](https://github.com/langchain-ai/langgraph) | 0.84 | GitHub officiel | orchestration durable par lot, graphes d'etat et reprise |
| [AutoGen](https://github.com/microsoft/autogen) | 0.82 | GitHub officiel | sous-agents specialises et conversations outillees |
| [Textual](https://github.com/Textualize/textual) | 0.80 | GitHub officiel | TUI Python riche si le cockpit sort du shell pur |
| [prompt_toolkit](https://python-prompt-toolkit.readthedocs.io/) | 0.76 | Documentation officielle | prompts avances, completions, modes clavier |
| [Bubble Tea](https://github.com/charmbracelet/bubbletea) | 0.73 | GitHub officiel | reference d'ergonomie TUI evenementielle |
| [gum](https://github.com/charmbracelet/gum) | 0.78 | GitHub officiel | composants shell interactifs legers et reversibles |

### Chat multi-agents, presets et personas

| Projet | Source | Ce qui est utile pour Kill_LIFE | Reutilisation recommandee |
| --- | --- | --- | --- |
| [Open WebUI](https://docs.openwebui.com/features/) | [Repo officiel](https://github.com/open-webui/open-webui) | workspace multi-modeles, presets, personnages, projets et outils | inspirer les selecteurs d'agents `kxkm-*`, les panneaux de dispatch et les surfaces par usage |
| [LibreChat](https://www.librechat.ai/docs/configuration/librechat_yaml/object_structure/agents) | [Presets](https://www.librechat.ai/docs/user_guides/presets) | agents configurables, capacites explicites, presets partageables | garder des personas stables, appelables par nom dans le chat, avec capacites par lane |
| [LobeChat](https://github.com/lobehub/lobe-chat) | GitHub officiel | galerie d'agents, multi-providers, selection rapide de roles | reference pour un catalogue visuel de personas et un switch rapide entre lanes |
| [AnythingLLM](https://docs.anythingllm.com/) | [Repo officiel](https://github.com/Mintplex-Labs/anything-llm) | agent builder, skills, flows et logs | rattacher des competences/outils a des agents specialises, avec trace d'execution |
| [LangGraph](https://docs.langchain.com/oss/python/langgraph/overview) | [Repo officiel](https://github.com/langchain-ai/langgraph) | orchestration, memoire, supervision, human-in-the-loop | structurer `PM / Architect / SyncOps` comme graphe d'etat avec handoff et reprise |

Synthese operationnelle:
- `Open WebUI` et `LobeChat` sont les meilleurs points d'appui pour les surfaces `presets/personas`.
- `LibreChat` et `AnythingLLM` sont les plus proches d'une logique `agent builder + skills + capacites`.
- `LangGraph` reste la meilleure reference pour industrialiser l'orchestration des agents dedies par specification et module.

### Benchmark 2026 — patterns retenus pour `summary-short` et la gateway santé `runtime/MCP/IA` (mise à jour 2026-03-21)

Cette note reste la note benchmark transverse de référence. Les autres docs doivent la citer, pas recopier ces décisions.

| Pattern / source primaire | Signal utile | Adoption concrète |
| --- | --- | --- |
| [Model Context Protocol Docs](https://modelcontextprotocol.io/docs/getting-started/intro) + [modelcontextprotocol/servers](https://github.com/modelcontextprotocol/servers) | contrat unique pour discovery, outils, transport et sécurité MCP | **ADOPT NOW** pour la gateway de santé: une seule surface normalise `runtime`, `mcp`, `tools`, `degraded_reason`; pas de checks disparates par extension |
| [MCP Registry](https://registry.modelcontextprotocol.io/) | catalogue vivant pour discovery et comparaison de serveurs | **BENCHMARK ONLY**: utile pour comparer et qualifier, mais pas dépendance runtime à court terme |
| [OpenAI Agents SDK](https://openai.github.io/openai-agents-python/) | patterns `sessions`, `handoffs`, `tools`, `tracing` | **ADOPT PARTIAL** pour le vocabulaire de relais et le format de handoff; **DO NOT ADOPT** comme coeur documentaire ou runtime structurant |
| [OpenHands](https://github.com/OpenHands/OpenHands) | séparation claire `SDK / CLI / GUI / Cloud / Enterprise` | **ADOPT NOW** comme pattern d'architecture: `studio` produit les artefacts, `mesh` porte la gateway runtime, `operator` exécute et supervise; **DO NOT CLONE** le produit |
| [Roo Code](https://github.com/RooCodeInc/Roo-Code) + [VS Code AI extensibility](https://code.visualstudio.com/api/extension-guides/ai/chat-tutorial) | rôles visibles dans l'éditeur, modes spécialisés, usage outillé/MCP | **ADOPT PARTIAL**: garder des lanes explicites et bornées; **DO NOT ADOPT** une "team" autonome large ou une prolifération de modes |
| [LangGraph](https://docs.langchain.com/oss/python/langgraph/overview) | durable execution, checkpoints, human-in-the-loop | **DEFER**: overlay possible pour les workflows longs seulement après stabilisation de `summary-short` et de la gateway de santé |

Décisions d'adoption 2026-03-21:

1. `summary-short` est **adopté** comme artefact canonique de relais court, d'abord dans `kill-life-studio`.
2. Format cible `summary-short`: `goal / state / blockers / next / owner / evidence` en sortie courte et déterministe.
3. `summary-short` n'est **pas** un transcript, ni une mémoire libre de type agent framework; c'est un contrat de handoff compact.
4. La gateway santé `runtime/MCP/IA` est **adoptée** comme source unique d'état technique pour `mesh` et `operator`.
5. La gateway doit exposer au minimum: `runtime_ok`, `mcp_ok`, `llm_ok`, `tools_count`, `degraded_reason`, `last_check`.
6. `kill-life-studio` consomme cette santé en lecture seule; il ne devient pas cockpit runtime.
7. `kill-life-mesh` porte la normalisation et l'agrégation de santé; `kill-life-operator` consomme cette sortie pour les checks et runbooks.
8. `Roo Code`, `OpenHands`, `OpenAI Agents SDK` et `LangGraph` restent des références de pattern; aucune de ces briques n'est adoptée telle quelle comme dépendance centrale court terme.

Conséquence produit immédiate:

- `Studio` produit les `summary-short` et autres artefacts de cadrage.
- `Mesh` expose une gateway de santé unique `runtime/MCP/IA` et relaie des états courts.
- `Operator` s'appuie sur cette gateway pour l'action opératoire, pas sur des probes parallèles.

### Références officielles 2026 vérifiées

- [VS Code AI extensibility](https://code.visualstudio.com/api/extension-guides/ai/chat-tutorial)
- [Model Context Protocol intro](https://modelcontextprotocol.io/docs/getting-started/intro)
- [Model Context Protocol registry](https://registry.modelcontextprotocol.io/)
- [OpenAI Agents SDK](https://openai.github.io/openai-agents-python/)
- [LangGraph overview](https://docs.langchain.com/oss/python/langgraph/overview)

## Recommandation de déploiement Kill_LIFE

### Niveau 1 — Immédiat (safe, faible risque)

1. Consolider le noyau MCP à partir de la spec officielle (`modelcontextprotocol/servers`, docs MCP).
2. Finaliser les guards et gates autour d’`openai-agents-python` en mode piloté (`ai:plan`, `ai:tasks`, `ai:qa`).
3. Standardiser la matrice de contrôle Wokwi + PlatformIO pour les lots `firmware`.

### Niveau 2 — Court terme (expérimental contrôlé)

1. Intégrer `lamaalrajih/kicad-mcp` ou alternative équivalente en lane canari IA-native.
2. Tester `circuit-synth/kicad-sch-api` pour validation de schéma et linting ciblé.
3. Evaluer une des implémentations FreeCAD MCP (`neka-nat/freecad-mcp` ou `ATOI-Ming/FreeCAD-MCP`) en mode non bloquant.
4. Poser YiACAD sur le triptyque `KiCad/KiCad` + `FreeCAD/FreeCAD` + `easyw/kicadStepUpMod`.

### Niveau 3 — Moyen terme (pilotage orchestration)

1. Orchestration longue durée des lots avec LangGraph ou AutoGen.
2. Lier une surface n8n à des jobs d’opérateur pour la routine quotidienne.
3. Déployer un tableau de bord d’acceptation par surface (MCP/CAD/Firmware/logs).

### Synthèse ciblée 2026-03-20

- Court terme: rester sur `bash-cli-tui` + shell TUI pour `Kill_LIFE`, avec `gum` comme couche interactive facultative.
- Moyen terme: garder `Textual` et `prompt_toolkit` comme options de montée en gamme si le cockpit devient trop complexe pour Bash.
- Agentique: traiter `LangGraph` et `AutoGen` comme overlays contrôlés, pas comme source de vérité documentaire ou planificatrice.

## Cartographie d’alignement Kill_LIFE

| Surface | Projection d’intégration | Garde-fou |
| --- | --- | --- |
| `specs` + docs | A2A / IA planificateur documentaire (`ai:spec`, `ai:plan`, `ai:tasks`) | `python3 tools/validate_specs.py --strict --require-mirror-sync` |
| MCP / outils runtime | Lancement canari + observabilité (`tools/mcp_runtime_status.py`, `mesh`) | `run_and_log`, mode `degraded` explicitement géré |
| CAD / forks IA-native | Lane isolée `kill-life-ai-native` et preuves par lot | Aucun merge direct; `write_set` explicite |
| logs / conformité | Refonte TUI + purge contrôlée | `bash tools/cockpit/log_ops.sh` avec rétention et proof |

## Décision d’intégration (mise à jour 2026-03-20)

- Les intégrations actives restent en mode assisté (`ai:spec`, `ai:plan`, `ai:tasks`) sauf lot explicitement en pilotage.
- Chaque nouvelle expérimentation doit créer un lot dans `specs/04_tasks.md` avec preuves de log et rollback.
- Toute proposition de branche/merge doit passer par les contrats `docs/TRI_REPO_MESH_CONTRACT_2026-03-20.md` + handoff.
- Le substrat recommandé pour YiACAD est désormais: upstreams officiels (`KiCad/KiCad`, `FreeCAD/FreeCAD`), bridge ECAD/MCAD (`easyw/kicadStepUpMod`) et adaptateurs MCP en lane canari.
