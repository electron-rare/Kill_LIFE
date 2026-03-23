# Cartographie GitHub — Écosystème Multi-LLM Mascarade

> **Dernière MAJ**: 2026-03-22 (session 13 — +2 providers EDA, +1 agent kicad-happy)
> **Objectif**: Référencer les repos GitHub officiels des providers et outils pertinents pour l'infrastructure Mascarade + Kill_LIFE

---

## 🔷 Anthropic — github.com/anthropics (77 repos)

### SDKs (providers Mascarade)
| Repo | Stars | Langage | Usage Mascarade |
|------|-------|---------|-----------------|
| **anthropic-sdk-python** | 3.0k | Python | Provider `claude.py` — SDK principal |
| **anthropic-sdk-typescript** | 1.7k | TypeScript | Frontend/API gateway |
| **anthropic-sdk-go** | 918 | Go | — |
| **anthropic-sdk-java** | 260 | Kotlin | — |
| **anthropic-sdk-csharp** | 192 | C# | — |
| **anthropic-sdk-php** | 118 | PHP | — |
| **anthropic-sdk-ruby** | 309 | Ruby | — |

### Agents & Tools
| Repo | Stars | Description | Pertinence |
|------|-------|-------------|------------|
| **skills** | 99.3k | Public Agent Skills registry | Skills de référence pour Kill_LIFE agents |
| **claude-code** | 81k | CLI coding agent (Shell) | Outil de dev principal |
| **claude-agent-sdk-python** | 5.6k | SDK agents Python | Potentiel orchestrateur alternatif Mascarade |
| **claude-code-action** | 6.4k | GitHub Actions CI/CD | CI Kill_LIFE / Mascarade |
| **claude-plugins-official** | 13.9k | Plugin directory officiel | Référence plugins Kill_LIFE |

### Ressources & Learning
| Repo | Stars | Description |
|------|-------|-------------|
| **claude-cookbooks** | 35.6k | Notebooks/recettes Claude |
| **prompt-eng-interactive-tutorial** | 33.9k | Tutoriel prompt engineering |
| **courses** | 19.7k | Cours éducatifs Anthropic |
| **claude-quickstarts** | 15.5k | Quickstart apps déployables |

### Anthropic Platform configuré
| Élément | Valeur |
|---------|--------|
| Organisation | L'électron rare |
| Plan | Evaluation access (free tier) |
| Workspace | Default |
| Clé mascarade-router | `sk-ant-api03-bEo...hQAA` ✅ |
| Clé kill-life-governance | `sk-ant-api03-xKJ...zQAA` ✅ |

---

## 🟢 OpenAI — github.com/openai (234 repos)

### SDKs (providers Mascarade)
| Repo | Stars | Langage | Usage Mascarade |
|------|-------|---------|-----------------|
| **openai-python** | 30.3k | Python | Provider `openai.py` — SDK principal |
| **openai-node** | 10.8k | TypeScript | Frontend/API |
| **openai-go** | 3.1k | Go | — |
| **openai-java** | 1.4k | Kotlin | — |

### Agents
| Repo | Stars | Description | Pertinence |
|------|-------|-------------|------------|
| **codex** | 66.8k | CLI coding agent (Rust) | Concurrent Claude Code |
| **openai-agents-python** | 20.2k | Multi-agent framework Python | Référence pour architecture agents Mascarade |
| **openai-agents-js** | 2.5k | Multi-agent framework JS | — |
| **plugins** | 74 | OpenAI Plugins | Plugin architecture ref |

### Outils & ML
| Repo | Stars | Description | Pertinence |
|------|-------|-------------|------------|
| **whisper** | 96.4k | Speech Recognition | Potentiel module voix Mascarade |
| **tiktoken** | 17.6k | BPE tokenizer rapide | Token counting dans router |
| **evals** | 18k | Framework d'évaluation LLM | Benchmark T-MA-021 |
| **openai-cookbook** | 72.3k | Guides & exemples API | Recettes Responses API |

### Projets OpenAI Platform configurés
| Projet | ID | Clé |
|--------|----|-----|
| Default | `proj_OwtOT7Ws1BtPVsKFkuI3VFpM` | — |
| Mascarade | `proj_Z6TszEfikDtBSfn5rIeaJnQI` | mascarade-router |
| Kill_LIFE | `proj_CYBNMcd3L1ml9IZHC1tqdpQh` | kill-life-governance |

---

## 🟠 Mistral AI — github.com/mistralai (24 repos)

### SDKs (providers Mascarade)
| Repo | Stars | Langage | Usage Mascarade |
|------|-------|---------|-----------------|
| **client-python** | 716 | Python | Provider `mistral.py` + `mistral_agents.py` — SDK principal |
| **client-ts** | 131 | TypeScript | — |

### Inference & Fine-tune
| Repo | Stars | Description | Pertinence |
|------|-------|-------------|------------|
| **mistral-inference** | 10.7k | Lib inférence locale (Jupyter) | Référence formats modèles |
| **mistral-finetune** | 3.1k | Pipeline fine-tune officiel | **T-MA-016/017** — fine-tune KiCad/SPICE |
| **mistral-common** | 871 | Preprocessing/tokenization | Token counting Mistral |

### Agents & Tools
| Repo | Stars | Description | Pertinence |
|------|-------|-------------|------------|
| **mistral-vibe** | 3.6k | CLI coding agent Python | Concurrent Claude Code / Codex |
| **agent-client-protocol** | 4 | Fork ACP (éditeur↔agent) | Protocol standard agents |
| **cookbook** | 2.2k | Recettes Mistral | Exemples Beta API |

### Agents AI Studio configurés
| Agent | ID | Modèle | Temp |
|-------|----|--------|------|
| Sentinelle | `ag_019d124c...` | mistral-medium-latest | 0.1 |
| Tower | `ag_019d124e...` | magistral-medium-latest | 0.4 |
| Forge | `ag_019d1251...` | codestral-latest | 0.21 |
| Devstral | `ag_019d1253...` | devstral-latest | 0.17 |

### Divers
| Repo | Description |
|------|-------------|
| **platform-docs-public** (MDX) | Docs API publiques |
| **prom_client_python** (fork Prometheus) | Monitoring instrumenté |
| **zed-extensions** (fork Zed) | Extension éditeur Zed |
| **megablocks-public** (archive, fork Databricks) | MoE sparse training |
| **flyte** (fork Flyteorg) | Workflow orchestration |

---

## 📊 Comparatif CLI Agents (coding tools)

| Outil | Org | Stars | Langage | Licence |
|-------|-----|-------|---------|---------|
| **skills** | Anthropic | 99.3k | Python | — |
| **claude-code** | Anthropic | 81k | Shell | — |
| **codex** | OpenAI | 66.8k | Rust | Apache-2.0 |
| **mistral-vibe** | Mistral | 3.6k | Python | Apache-2.0 |

## 📊 Comparatif Agent Frameworks

| Framework | Org | Stars | Description |
|-----------|-----|-------|-------------|
| **claude-agent-sdk-python** | Anthropic | 5.6k | SDK agents Claude |
| **openai-agents-python** | OpenAI | 20.2k | Multi-agent workflows |
| **openai-agents-js** | OpenAI | 2.5k | Multi-agent JS |
| *(Conversations Beta API)* | Mistral | — | Agents via API Studio |

---

## 🔗 Mapping providers Mascarade → GitHub repos

```
mascarade/router/providers/
├── claude.py         → anthropics/anthropic-sdk-python
├── openai.py         → openai/openai-python
├── mistral.py        → mistralai/client-python
├── mistral_agents.py → mistralai/client-python + Beta Conversations API
├── google.py         → google (Gemini SDK)
├── bedrock.py        → AWS SDK (boto3)
├── huggingface.py    → huggingface_hub
├── ollama.py         → ollama/ollama-python
├── llama_cpp.py      → local inference
├── apple_coreml.py   → coremltools
├── kicad_router.py   → custom KiCad routing
├── pcbdesigner.py    → planned provider path in active repo (T-EDA-001, Plan 26)
└── quilter.py        → planned provider path in active repo (T-EDA-002, Plan 26)

mascarade/agents/
├── kicad_agent.py        → KiCad schematic/PCB agent
├── kicad_happy_agent.py  → planned agent path in active repo for BOM/LCSC/DFM (T-EDA-003, Plan 26)
├── spice_agent.py        → LTspice simulation agent
├── components_agent.py   → Component sourcing agent
└── freecad_agent.py      → FreeCAD 3D/mechanical agent
```

---

## 💰 Synthèse Billing — Infrastructure Multi-LLM (22 mars 2026)

| Provider | Plan | Crédits | Billing | Limites clés |
|----------|------|---------|---------|--------------|
| **Mistral** | Le Chat Team (59,98 €/mois) + AI Studio Scale | 0,00 € (pay-as-you-go) | Visa ****-2046 | 6 RPS, 2M TPM, 10B tokens/mois, fine-tune ✅ |
| **OpenAI** | Pay as you go | **$50.00** | Auto-recharge ON ($25@$15) | Standard tier |
| **Anthropic** | Evaluation access (free) | **0** (nécessite achat) | — | 5 RPM, 10K input TPM, 4K output TPM |

### Providers Mascarade — Statut opérationnel
| Provider | Fichier | SDK | Clé API | Statut |
|----------|---------|-----|---------|--------|
| `claude.py` | ClaudeProvider | anthropic SDK | mascarade-router (sk-ant-...hQAA) | ✅ Validé (crédits requis) |
| `openai.py` | OpenAIProvider | openai SDK | mascarade-router (sk-proj-...) | ✅ Opérationnel ($50) |
| `mistral.py` | MistralProvider | mistralai SDK | mascarade-router (708z...7kG) | ✅ Connectivité validée |
| `mistral_agents.py` | MistralAgentsProvider | httpx (Beta API) | mascarade-router (708z...7kG) | ✅ 4 agents v2 — validé |
| `pcbdesigner.py` | PCBDesignerProvider | aiohttp (REST) | `PCBDESIGNER_API_KEY` (a configurer) | 🟡 Planned, not implemented in active Mascarade repo |
| `quilter.py` | QuilterProvider | aiohttp (REST) | `QUILTER_API_KEY` (a configurer) | 🟡 Planned, not implemented in active Mascarade repo |

---

## Actions suivantes

1. **mistral-finetune** → Cloner et tester pour T-MA-016/017 (fine-tune KiCad/SPICE datasets)
2. **openai evals** → Adapter framework pour benchmark T-MA-021
3. **claude-agent-sdk-python** → Évaluer comme orchestrateur alternatif au router Mascarade
4. **tiktoken** → Intégrer token counting OpenAI dans le router (estimation coûts)
5. **openai-agents-python** → Étudier patterns multi-agent pour A2A protocol (T-MA-030)
6. **Acheter crédits Anthropic** → Nécessaire pour activer le provider Claude en production

---

## 🟣 Outils EDA+IA — Providers spécialisés PCB (Plan 26)

| Outil | Type Mascarade | API / Source | Approche | Temps typique |
|-------|---------------|-------------|----------|---------------|
| **PCB Designer AI** | Provider | REST `api.pcbdesigner.ai/v1` | IA placement+routing → Gerber → JLCPCB one-click | 30min–2h |
| **Quilter** | Provider | REST `api.quilter.ai/v1` | Physique+RL, multi-candidat, scores SI/thermal/DFM | 2–6h |
| **kicad-happy** | Agent | GitHub (Claude Code skills) | Analyse schéma/PCB, BOM extract, sourcing LCSC, DFM | Secondes |
| **KiCad Router** | Provider (existant) | Autorouter KiCad interne | Routage offline local | Minutes |

### Pipeline chaine cible (T-EDA-022)
```
kicad-happy (analyse+BOM) → quilter (routage physique) → pcbdesigner (commande JLCPCB)
```

Note de realite:
- cette chaine est une cible d'architecture
- elle n'est pas implementee dans le repo Mascarade actif au 2026-03-22
- aucun provider/agent EDA n'est considere `done` tant que le fichier n'existe pas dans `/Users/electron/Documents/Projets/mascarade`

Canonical mapping and adoption notes:
- `docs/PCB_AI_FAB_INTEGRATION_MAP_2026-03-22.md`
- `specs/contracts/pcb_ai_fab_registry.json`
- `tools/cockpit/pcb_ai_fab_tui.sh`
