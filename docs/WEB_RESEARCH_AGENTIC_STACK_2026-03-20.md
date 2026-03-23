# Veille officielle agentic stack / tri-repo

Last updated: 2026-03-20 15:45 CET

Sources officielles verifiees le 2026-03-20.

| Projet | Source officielle | Apport utile pour le tri-repo | Decision actuelle |
| --- | --- | --- | --- |
| MCP | https://modelcontextprotocol.io/docs/getting-started/intro | Contrat standard pour outils, sources de donnees et workflows relies aux agents | A conserver comme colonne vertebrale des bridges outil/runtime |
| OpenAI Agents SDK | https://openai.github.io/openai-agents-python/ | Primitives `agents`, `handoffs`, `guardrails`, `sessions`, tracing et MCP integre | A utiliser comme reference de design pour la gouvernance agentique et les handoffs |
| AutoGen | https://microsoft.github.io/autogen/stable/user-guide/agentchat-user-guide/tutorial/index.html | Teams, AgentChat, GraphFlow, runtime event-driven | A benchmarker pour orchestration multi-agent plus riche, sans remplacement direct |
| LangGraph | https://docs.langchain.com/oss/python/langgraph/overview | Graphes et orchestration stateful pour workflows complexes | A reutiliser comme reference de design pour `graph engine` / workflow handshakes |
| OpenHands | https://docs.openhands.dev/openhands/usage/cli/quick-start | Terminal mode, headless mode, MCP servers, IDE integration | Bon benchmark pour execution agentique outillee, pas source de verite runtime |
| n8n | https://docs.n8n.io/ | Orchestration workflow visuelle, webhooks, executions, integrations | A conserver pour les lanes d'integration et les smokes workflow |
| Wokwi CI | https://docs.wokwi.com/wokwi-ci/getting-started | Simulation embarquee CI, utile pour hardware/firmware sans cible physique | A evaluer pour la partie ZeroClaw / embedded CI |
| PlatformIO Unit Testing | https://docs.platformio.org/en/latest/advanced/unit-testing/index.html | Cadre de tests embarques, segmentation par environnements, unit testing cible | A garder comme reference pour QA embarquee et preuve firmware |

## Notes d'integration

- MCP reste le contrat d'interface le plus naturel pour `Kill_LIFE <-> mascarade <-> crazy_life`.
- L'OpenAI Agents SDK fournit la meilleure reference officielle pour la separation `agent`, `handoff`, `guardrail`, `session`, `trace`.
- AutoGen et LangGraph sont les deux benchmarks les plus utiles pour les futurs lots d'orchestration avancee:
  - AutoGen pour les teams / runtimes plus riches.
  - LangGraph pour les graphes stateful et les transitions explicites.
- OpenHands est surtout un benchmark de posture operateur et d'integration CLI/MCP.
- n8n, Wokwi CI et PlatformIO sont a conserver comme piliers de workflow, simulation et validation technique.

## Decision produit

- Pas de remplacement complet de l'existant.
- Adoption incrementale:
  1. garder MCP comme contrat commun,
  2. aligner les handoffs et sessions sur les primitives de l'OpenAI Agents SDK,
  3. reserver AutoGen/LangGraph a des lots compares et bornes,
  4. conserver n8n / Wokwi / PlatformIO comme outillage complementaire et specialise.
