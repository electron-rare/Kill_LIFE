# TODO 23 — Intégration Mistral Agents

> **Owner**: PM-Mesh + Architect
> **Date création**: 2026-03-21
> **Dernière MAJ**: 2026-03-22 (session 13 — runtime actif verrouillé sur le repo Mascarade)
> **Statut global**: 🟢 Phase 0 DONE — Phase 1 DONE — Phase 2 quasi-done (21/24) — Migration Beta API DONE — Agents AI Studio v2 configurés — OpenAI Platform ready — Anthropic Platform ready — Infra 3 providers opérationnelle

---

## 🔄 REPRISE PROCHAINE SESSION

**Contexte** : 8 sessions complétées. Infrastructure multi-LLM (Mistral + OpenAI) opérationnelle. Migration Beta API terminée.

**Tâches restantes Lot 23** (3/24 restantes) :
1. **T-MA-016** : Lancer fine-tune Mistral Small sur dataset KiCad fusionné (~15k examples) — nécessite VM avec accès mascarade-datasets/
   - Config prête : `tools/mistral/finetune/configs/kicad_small.yaml`
   - Script validation : `tools/mistral/finetune/prepare_and_validate.sh`
2. **T-MA-017** : Lancer fine-tune Codestral sur dataset SPICE+embedded (~20k examples) — idem VM
   - Config prête : `tools/mistral/finetune/configs/spice_codestral.yaml`
3. **T-MA-021** : Benchmark comparatif base model vs fine-tuned sur 100 prompts métier — après fine-tune
   - Framework prêt : `tools/evals/benchmark_providers.py` (3 providers, JSONL prompts, summary auto)
   - 20 prompts template : `tools/evals/prompts/metier_100_template.jsonl` (à étendre à 100)
4. ~~**T-MA-023** : Documentation agents Mascarade~~ — **DONE** session 14 → `docs/MASCARADE_AGENTS_DOCUMENTATION.md`
5. ~~**T-MA-037** : Migrer `mistral_agents_tui.sh` vers Beta Conversations API~~ — ✅ session 8
6. ~~**T-MA-038** : Créer `mistral_agents.py` provider Mascarade (Beta API)~~ — ✅ session 8

**Infra prête** :
- Mistral AI Studio : 4 agents v2 (Sentinelle, Tower, Forge, Devstral) — IDs ci-dessous
- OpenAI Platform : 3 projets (Default, Mascarade, Kill_LIFE) + 3 clés API + 1 admin key — **$50 crédits**, auto-recharge ON
- Anthropic Platform : Org "L'électron rare" — 2 clés API (mascarade-router, kill-life-governance) — Evaluation access
- Pipeline fine-tune : `mistral_dataset_pipeline.py` prêt, 12 JSONL ~176 MB en attente upload
- Fine-tune configs : `tools/mistral/finetune/configs/` (kicad_small.yaml, spice_codestral.yaml)
- Benchmark framework : `tools/evals/benchmark_providers.py` (Mistral + Anthropic + OpenAI, 20 prompts template)
- Beta API client : `mistral_agents_beta_api.py` avec fallback deprecated

**Clés et IDs critiques** :
- Sentinelle: `ag_019d124c302375a8bf06f9ff8a99fb5f` (mistral-medium-latest, temp 0.1)
- Tower: `ag_019d124e760877359ad3ff5031179ebc` (magistral-medium-latest, temp 0.4)
- Forge: `ag_019d1251023f73258b80ac73f90458f6` (codestral-latest, temp 0.21)
- Devstral: `ag_019d125348eb77e880df33acbd395efa` (devstral-latest, temp 0.17)
- OpenAI Mascarade: `proj_Z6TszEfikDtBSfn5rIeaJnQI` — clé mascarade-router (sk-proj-...u5cA)
- OpenAI Kill_LIFE: `proj_CYBNMcd3L1ml9IZHC1tqdpQh` — clé kill-life-governance (sk-proj-...R78A)
- OpenAI Admin: clé "claude" (sk-admin-...uicA)
- Mistral mascarade-router: `708z...7kG` (workspace Default, expire jamais) — ✅ connectivité validée 22/03
- Mistral kill-life-governance: `14CW...f1b` (workspace Default, expire jamais)
- Mistral kxkm: `**...gJnw` (legacy, active, dernière utilisation 22 mars 2026)
- Mistral Billing: **Le Chat Team 59,98 €/mois** (2 sièges) + **AI Studio Scale** (pay-as-you-go, 6 RPS, 2M TPM, 10B tokens/mois, fine-tune inclus) — crédits API 0,00 € — Visa ****-2046
- Anthropic mascarade-router: `sk-ant-api03-bEo...hQAA` (workspace Default, Evaluation access) — ✅ validée
- Anthropic kill-life-governance: `sk-ant-api03-xKJ...zQAA` (workspace Default, Evaluation access) — ✅ validée
- Org Anthropic: "L'électron rare" — Plan: Evaluation access (free tier)
- Anthropic Rate Limits (Free Tier): 5 RPM, 10K input TPM, 4K output TPM par modèle (Sonnet/Opus/Haiku)
- Anthropic Batch: 5 RPM — Web Search: 30/s — Files Storage: 500 GB
- ⚠️ **Pas de crédits Anthropic** — nécessite achat crédits pour usage API

**Limitation connue** : codestral-latest et devstral-latest ne supportent PAS les builtin connectors AI Studio (Code, Image, Recherche) — erreur 3004

---

## P0 — Fondations (URGENT)

- [x] T-MA-001: Rédiger specs des 4 agents (Sentinelle, Tower, Forge, Devstral) → `MASTER_INTEGRATION_PLAN_2026-03-21.md`
- [x] T-MA-002: Créer `mistral_agents_tui.sh` dans tools/cockpit/
- [x] T-MA-003: Créer `integration_health_tui.sh` dans tools/cockpit/
- [x] T-MA-004: Créer les 4 agents sur console.mistral.ai/build/agents
  - [x] Sentinelle (mistral-medium-latest, temp=0.1) → ag_019d124c302375a8bf06f9ff8a99fb5f
  - [x] Tower (magistral-medium-latest, temp=0.4) → ag_019d124e760877359ad3ff5031179ebc
  - [x] Forge (codestral-latest, temp=0.2) → ag_019d1251023f73258b80ac73f90458f6
  - [x] Devstral (devstral-latest, temp=0.15) → ag_019d125348eb77e880df33acbd395efa
- [x] T-MA-005: Implémenter `mistral_agents_api.py` provider dans `core/mascarade/router/providers/`
- [x] T-MA-006: Ajouter config agents dans `mascarade/.env` (MISTRAL_AGENTS_API_KEY, agent IDs)

## P1 — Branchements

- [x] T-MA-010: Brancher Sentinelle → Mascarade API (/health, /providers, /metrics) → `sentinelle_connector.py`
- [x] T-MA-011: Brancher Sentinelle → Langfuse (traces, scores, latence) → `sentinelle_connector.py`
- [x] T-MA-012: Brancher Sentinelle → Grafana (Prometheus queries: CPU, RAM, disk) → `sentinelle_connector.py`
- [x] T-MA-013: Configurer Tower → Outline search (docs produit, formations) → `tower_outline_connector.py`
- [x] T-MA-014: Configurer Tower → template emails (premier contact, follow-up, proposal) → `tower_templates.py`
- [x] T-MA-015: Audit qualité des 10 datasets fine-tune → `dataset_audit_tui.sh` (cockpit)
  - [x] build_kicad_dataset.py → unified in `tools/mistral/build_datasets.py` (56 examples)
  - [x] build_spice_dataset.py → unified in `tools/mistral/build_datasets.py` (48 examples)
  - [x] build_freecad_dataset.py → unified in `tools/mistral/build_datasets.py` (63 examples)
  - [x] build_stm32_dataset.py → unified in `tools/mistral/build_datasets.py` (51 examples)
  - [x] build_embedded_dataset.py → unified in `tools/mistral/build_datasets.py` (49 examples)
  - [x] build_iot_dataset.py → unified in `tools/mistral/build_datasets.py` (53 examples)
  - [x] build_emc_dataset.py → unified in `tools/mistral/build_datasets.py` (59 examples)
  - [x] build_dsp_dataset.py → unified in `tools/mistral/build_datasets.py` (58 examples)
  - [x] build_power_dataset.py → unified in `tools/mistral/build_datasets.py` (63 examples)
  - [x] build_platformio_dataset.py → unified in `tools/mistral/build_datasets.py` (49 examples)
- [ ] T-MA-016: Lancer fine-tune Mistral Small sur dataset KiCad fusionné (~15k examples)
- [ ] T-MA-017: Lancer fine-tune Codestral sur dataset SPICE+embedded (~20k examples)

## P2 — Production & CI/CD

- [x] T-MA-020: Intégrer Devstral dans workflow CI → `devstral-review.yml` (GitHub Actions PR review)
- [ ] T-MA-021: Benchmark comparatif: base model vs fine-tuned sur 100 prompts métier
- [x] T-MA-022: Cron Sentinelle health-check (06:00 daily) → `sentinelle_cron.sh`
- [x] T-MA-023: Documentation agents Mascarade → `docs/MASCARADE_AGENTS_DOCUMENTATION.md` (4 sections: Sentinelle, Tower, Forge, Devstral + 18 Ollama profiles + mesh + API usage)
- [x] T-MA-024: Intégrer `mistral_agents_tui.sh` dans `yiacad_operator_index.sh` → 7 new actions (agents-status/chat/health/e2e, studio-status/files/finetune)
- [x] T-MA-025: Tests d'intégration end-to-end (handoff Sentinelle → Devstral → fix auto) → `e2e_agents_test.sh`

## P2bis — Migration API (CRITIQUE)

- [x] T-MA-035: Créer `mistral_agents_beta_api.py` — client Beta Conversations API avec fallback deprecated
  - [x] MistralBetaAgentsClient: chat(), chat_deprecated(), chat_with_fallback()
  - [x] Pattern Handoff intégré (handoff from→to)
  - [x] MistralLibraryClient pour Document Library RAG (Tower)
  - [x] Health check avec ping de tous les agents
  - [x] CLI test (health, chat, handoff, libraries)
- [x] T-MA-036: Mettre à jour `e2e_agents_test.sh` — support Beta API + fallback deprecated
  - [x] call_agent() refactoré avec _call_api() → conversations/completions puis agents/completions
  - [x] Option --api-mode (beta|deprecated)
  - [x] Rapport JSON inclut api_mode
- [x] T-MA-037: Migrer `mistral_agents_tui.sh` vers Beta Conversations API
  - [x] Rewrite complet: API abstraction layer (_call_beta, _call_deprecated, call_agent)
  - [x] Fallback automatique beta → deprecated
  - [x] Nouvelle action handoff (Sentinelle→Devstral)
  - [x] API mode toggle (beta/deprecated)
  - [x] extract_content() compatible deux formats de réponse
- [x] T-MA-038: Créer `mistral_agents.py` provider Mascarade (Beta Conversations API)
  - [x] Provider dédié `MistralAgentsProvider` dans providers/mistral_agents.py
  - [x] Registre des 4 agents avec IDs, modèles, températures, rôles
  - [x] send() avec fallback beta → deprecated
  - [x] send_to_agent() API haut niveau pour workflows
  - [x] handoff() inter-agents (from→to avec transform_prompt)
  - [x] Enregistré dans providers/__init__.py
  - [x] Config `mistral_agents_api_mode` ajoutée dans config.py

## P3 — Évolutions futures

- [x] T-MA-030: Implémenter A2A protocol dans Mascarade (MCP + A2A complémentaires) — delivered in Mascarade PR #33
- [x] T-MA-031: Migrer orchestrateur Mascarade vers graph-based state (LangGraph-compatible) — `core/mascarade/router/graph_state.py` + FastAPI endpoints
- [x] T-MA-032: Ajouter RAG Document Library à Tower (Outline + docs PDF) — via MistralLibraryClient — delivered in Mascarade PR #33
- [x] T-MA-033: Pipeline d'évaluation continue des agents → `tools/evals/weekly_benchmark.sh` (Ollama devstral, keyword-match quality heuristic, latency/tokens, auto-compare previous run)
- [x] T-MA-034: Lot chain dispatch vers agents Mistral → `tools/ai/dispatch_to_agent.sh` (domain-to-agent mapping, local Ollama or Mistral API, dry-run, logging)

---

## Journal de bord

### 2026-03-21
- Création du lot 23
- Specs des 4 agents rédigées dans MASTER_INTEGRATION_PLAN
- TUI `mistral_agents_tui.sh` et `integration_health_tui.sh` déployés dans cockpit
- Recherche web effectuée : Mistral Agents API, MCP 2026, LangGraph 2026
- Matrice agent × tâche établie avec dépendances critiques
- **4 agents créés sur console.mistral.ai** avec IDs réels :
  - Sentinelle: ag_019d124c302375a8bf06f9ff8a99fb5f (mistral-medium, temp 0.1)
  - Tower: ag_019d124e760877359ad3ff5031179ebc (magistral-medium, temp 0.4)
  - Forge: ag_019d1251023f73258b80ac73f90458f6 (codestral, temp 0.2)
  - Devstral-Code: ag_019d125348eb77e880df33acbd395efa (devstral, temp 0.15)
- `mistral_agents_api.py` provider implémenté et mis à jour avec les 4 IDs
- Note: mistral-large indisponible dans agents → Tower utilise magistral-medium (meilleur raisonnement dispo)
- **Session 2 — Phase 1 :**
  - `sentinelle_connector.py` créé : 7 tools MCP (mascarade_health, mascarade_providers, mascarade_metrics, langfuse_traces, langfuse_scores, prometheus queries, full_diagnostic)
  - `tower_templates.py` créé : 7 templates emails (premier_contact_inbound/outbound, followup_post_demo, proposition_commerciale, formation_kicad, relance_30j/60j)
  - `dataset_audit_tui.sh` créé : audit statique des 10 builders (score/8, couverture, validation, dedup, balance)
  - `test_mistral_agents_provider.py` créé : 20+ tests unitaires (registry, provider, complete, handoff, health_check, singleton) + tests d'intégration
  - `.env.example` mis à jour avec les 4 agent IDs
  - Note: virtiofs EDEADLK deadlock persiste sur fichiers existants du repo — nouveaux fichiers OK
  - `devstral-review.yml` créé : GitHub Actions workflow pour code review automatique par Devstral sur PRs
  - `sentinelle_cron.sh` créé : cron daily health-check avec analyse Sentinelle + alerting webhook
  - **Bilan session 2** : P0 6/6 ✅ | P1 5/8 (63%) | P2 2/6 (33%) | Total 13/20 tâches complétées
- **Session 3 — Analyse exhaustive + Lot 24 :**
  - Exploration complète Mistral AI Studio (Playground, Agents, Batches, IA Documentaire, Audio offline+realtime, Fine-tune Modèles+Jobs, Fichiers, Vibe CLI, Codestral)
  - Analyse exhaustive Kill_LIFE (47 scripts, 22 plans, 6 agents BMAD, 15+ schemas JSON)
  - Analyse exhaustive Mascarade (10+ providers, 15+ services Docker, 10 builders fine-tune)
  - Recherche web état de l'art 2026 (MCP, A2A, LangGraph, n8n, fine-tune ORPO/KTO, frameworks agentiques)
  - Document `ANALYSE_EXHAUSTIVE_ECOSYSTEME_2026-03-21.md` généré (diagrammes Mermaid, feature maps, matrice agents)
  - `mistral_studio_tui.sh` créé (14 actions couvrant toute la console Mistral Studio)
  - Lot 24 plan + TODO créés (16 tâches, 4 phases: Fichiers, Fine-tune, Intégrations Studio, Production)
  - **Chaînage** : Lot 23 → Lot 24 (Intégration Mistral Studio Complète)
- **Session 4 — Exécution Lot 23 restant + Pipeline Lot 24 :**
  - `tower_outline_connector.py` créé : OutlineConnector (sync+async) avec 5 MCP tools (search, get_document, product_lookup, training_lookup, list_collections) — T-MA-013 ✅
  - `yiacad_operator_index.sh` étendu : +7 actions (agents-status, agents-chat, agents-health, agents-e2e, studio-status, studio-files, studio-finetune) — T-MA-024 ✅
  - `e2e_agents_test.sh` créé : 6 tests E2E (Sentinelle health+anomaly, Tower email, Forge quality, Devstral review, Handoff Sentinelle→Devstral) avec rapport JSON cockpit-v1 — T-MA-025 ✅
  - `mistral_dataset_pipeline.py` créé : pipeline complète merge→validate→upload→finetune avec 3 domaines (kicad, spice-embedded, full), déduplication MD5, split train/val — Lot 24 T-MS-002/003 prêt
  - `infra_container_health.sh` créé : health-check web+Docker avec fix/restart automatique pour containers down (metabase, listmonk, changedetection, bookmarks)
  - Recherche web fine-tune Mistral 2026 : format ChatML JSONL confirmé, 200-5000 exemples min, loss only on assistant, Mistral Forge enterprise lancé
  - Audit datasets existants : 12 fichiers JSONL (~176 MB total) dans mascarade-datasets/ — virtiofs deadlock empêche lecture directe, scripts VM-ready créés
  - **Bilan session 4** : P0 6/6 ✅ | P1 7/8 (88%) | P2 4/6 (67%) | Total 17/20 tâches complétées
  - **Restant** : T-MA-016 (fine-tune KiCad), T-MA-017 (fine-tune SPICE), T-MA-021 (benchmark), T-MA-023 (docs Outline)
- **Session 5 — Cross-référence docs + Migration Beta API :**
  - Capture documentation Mistral AI complète → `MISTRAL_DOCS_REFERENCE_2026-03-21.md` (469 lignes, 11 sections)
  - Audit HuggingFace clemsail : 4 modèles LoRA (TinyLlama/Qwen), 8 datasets domaine
  - **Découverte critique** : endpoint `/v1/agents/completions` marqué deprecated → Beta Conversations API disponible
  - `mistral_agents_beta_api.py` créé (400+ lignes) :
    - MistralBetaAgentsClient : chat(), chat_deprecated(), chat_with_fallback(), handoff(), health_check()
    - MistralLibraryClient : create_library(), add_document(), list_documents() (RAG natif Mistral)
    - Shortcuts nommés : sentinelle(), tower(), forge(), devstral()
    - CLI complète : health, chat, chat-deprecated, handoff, libraries
  - `e2e_agents_test.sh` mis à jour : support dual API (beta/deprecated), option --api-mode, fallback automatique
  - T-MA-035 ✅, T-MA-036 ✅
  - **Bilan session 5** : P0 6/6 ✅ | P1 7/8 (88%) | P2 4/6 (67%) | P2bis 2/4 (50%) | Total 19/24 tâches
  - **Restant** : T-MA-016/017 (fine-tune VM), T-MA-021 (benchmark), T-MA-023 (docs), T-MA-037/038 (migration TUI+provider)
- **Session 6 — Configuration AI Studio Agents v2 :**
  - **4 agents configurés sur console.mistral.ai** (température + outils) :
    - Sentinelle: temp 0.1, Code+Recherche activés → **v2 sauvé** ✅
    - Tower: temp 0.4, Recherche+Image activés → **v2 sauvé** ✅
    - Forge: temp 0.21, **pas de builtin tools** (codestral-latest ne supporte pas les connecteurs, Code 3004) → **v2 sauvé** ✅
    - Devstral-Code: temp 0.17, **pas de builtin tools** (devstral-latest même limitation) → **v2 sauvé** ✅
  - **Découverte** : `codestral-latest` et `devstral-latest` ne supportent pas les builtin connectors (Code, Image, Recherche, Recherche Premium) — erreur API 3004
  - **Audit AI Studio complet** :
    - Fichiers: 0 fichiers (prêt pour upload pipeline T-MS-002/003)
    - Fine-tune > Modèles personnalisés: 0 modèles (en attente T-MS-010/011)
    - Fine-tune > Jobs: 0 jobs
    - Batches: 0 tâches par lot (en attente T-MS-012)
    - IA Documentaire: OCR playground actif, 10 docs max, 50 Mo, PDF/images. API: 1000 pages/doc, 2000 pages/min
    - Audio STT: Beta, offline+realtime, 10 fichiers, 1024 Mo, MP3/WAV/MP4/MOV/WEBM
    - Vibe CLI: clé API active (***3Ltg), quota indisponible pour l'organisation
    - Codestral: clé API active (***otEl), endpoints FIM+Chat confirmés
  - **Bilan session 6** : P0 6/6 ✅ | P1 7/8 (88%) | P2 4/6 (67%) | P2bis 2/4 (50%) | Total 19/24 tâches
  - **Restant** : T-MA-016/017 (fine-tune VM), T-MA-021 (benchmark), T-MA-023 (docs), T-MA-037/038 (migration TUI+provider)
- **Session 7 — Configuration OpenAI Platform :**
  - **OpenAI Platform** configuré comme provider complémentaire Mascarade :
    - Billing: $50 credit, auto-recharge ON ($25 @ $15 threshold), pay-as-you-go
    - Admin key "claude" (sk-admin-...uicA): Active, All permissions — administration globale
    - Assistants API: deprecated (suppression août 2026) → utiliser Responses API
  - **3 projets créés** pour isolation API :
    - Default project: `proj_OwtOT7Ws1BtPVsKFkuI3VFpM` (12 fév. 2026)
    - Mascarade: `proj_Z6TszEfikDtBSfn5rIeaJnQI` (22 mars 2026)
    - Kill_LIFE: `proj_CYBNMcd3L1ml9IZHC1tqdpQh` (22 mars 2026)
  - **2 clés API projet créées** :
    - mascarade-router (sk-proj-UTp...EV9JL9...) → projet Mascarade, All permissions
    - kill-life-governance (sk-proj-xiO...x92WpF75l...) → projet Kill_LIFE, All permissions
  - **Architecture multi-provider OpenAI** : projets isolés permettent suivi usage/coûts par écosystème
  - **Bilan session 7** : P0 6/6 ✅ | P1 7/8 (88%) | P2 4/6 (67%) | P2bis 2/4 (50%) | OpenAI Platform ✅ | Total 19/24 tâches Mistral + infra OpenAI ready
  - **Restant** : T-MA-016/017 (fine-tune VM), T-MA-021 (benchmark), T-MA-023 (docs), T-MA-037/038 (migration TUI+provider)

### 2026-03-22 (session 8)
  - **T-MA-037 DONE** : `mistral_agents_tui.sh` entièrement réécrit pour Beta Conversations API
    - API abstraction layer : `_call_beta()` (POST /v1/conversations) + `_call_deprecated()` (POST /v1/agents/{id}/completions)
    - `call_agent()` unifié avec fallback automatique beta → deprecated
    - `extract_content()` compatible deux formats (outputs/choices)
    - Nouvelle action `handoff` (Sentinelle diagnostique → Devstral corrige)
    - Menu v2 avec toggle API mode beta/deprecated
  - **T-MA-038 DONE** : `mistral_agents.py` créé dans `mascarade/router/providers/`
    - `MistralAgentsProvider` : provider dédié aux 4 agents Mistral AI Studio
    - Registre agents : Sentinelle, Tower, Forge, Devstral (IDs, modèles, températures, rôles)
    - `send()` conforme interface LLMProvider avec résolution agent par nom/ID
    - `send_to_agent()` : API haut niveau pour appels directs par nom d'agent
    - `handoff()` : workflow inter-agents (from→to avec injection contexte)
    - `stream()` : fallback vers send() (Conversations API ne supporte pas le streaming)
    - Enregistré dans `providers/__init__.py`, config `mistral_agents_api_mode` ajoutée
  - **Bilan session 8** : P0 6/6 ✅ | P1 7/8 (88%) | P2 6/6 ✅ | P2bis 4/4 ✅ | Total 21/24 — Migration Beta API terminée
  - **Clés API Mistral AI Studio créées** :
    - mascarade-router: `**...5Gav` (workspace Default, expire jamais)
    - kill-life-governance: `**...4Gid` (workspace Default, expire jamais)
  - **GitHub Ecosystem Map** : `github_ecosystem_map.md` créé dans docs/references/
    - Cartographie complète : Anthropic (77 repos), OpenAI (234 repos), Mistral (24 repos)
    - SDKs, agents, tools, comparatifs CLI/frameworks, mapping providers→repos
  - **Anthropic Claude Platform** configuré :
    - Org: "L'électron rare" — Plan: Evaluation access (free tier)
    - Clé mascarade-router: `sk-ant-api03-Fj1...dwAA` (workspace Default)
    - Clé kill-life-governance: `sk-ant-api03-xKJ...zQAA` (workspace Default)
    - Rate Limits Free Tier: 5 RPM, 10K input TPM, 4K output TPM (Sonnet/Opus/Haiku)
    - ⚠️ Pas de crédits — nécessite achat pour usage API
  - **OpenAI Platform** vérifié : $50 crédits actifs, auto-recharge ON, 3 projets confirmés
  - **Bilan session 8 final** : Infrastructure multi-LLM 3 providers (Mistral + OpenAI + Anthropic) opérationnelle
  - **Restant** : T-MA-016/017 (fine-tune, nécessite VM), T-MA-021 (benchmark, nécessite fine-tune)

---

## Session 9 — 2026-03-22 — Hardening local Beta API / reprise cockpit

Travail local ferme sans dependance VM fine-tune.

Fait:
- hardening de `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/tools/cockpit/e2e_agents_test.sh`
  - payload Beta Conversations aligne sur `/v1/conversations`
  - fallback deprecated aligne sur `/v1/agents/{id}/completions`
  - parsing assistant robuste sur `outputs[].content` et `choices[].message.content`
  - logs internes envoyes sur stderr pour ne plus polluer les JSON captures
- hardening de `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/tools/cockpit/sentinelle_cron.sh`
  - migration Beta API avec fallback deprecated
  - ajout du reporting `analysis_api_mode`
  - ecriture JSON du rapport rendue plus sure
- hardening du bridge Mascarade sur la structure reelle du repo:
  - `/Users/electron/Documents/Projets/mascarade/core/mascarade/agents/mistral_agents.py`
  - normalisation des blocs `outputs[].content` en texte simple

Constat topologie:
- repo Mascarade de reference pour ce lot: `/Users/electron/Documents/Projets/mascarade`
- ne pas utiliser la copie `Github_Repos/Perso/mascarade-main` pour ces correctifs
- le chemin historique `core/mascarade/router/providers/mistral_agents.py` n'est pas la structure active ici

Reste ouvert inchangé:
- `T-MA-016` fine-tune KiCad merge ~15k -> VM / datasets requis
- `T-MA-017` fine-tune Codestral SPICE+embedded ~20k -> VM / datasets requis
- `T-MA-021` benchmark base vs fine-tuned sur 100 prompts -> apres fine-tune
- `T-MA-023` docs Outline -> reporte Lot 24

## Gouvernance de dossier — source de verite unique

Decision verrouillee a partir du 2026-03-22.

Dossiers autorises:
- Kill_LIFE tracking / cockpit: `/Users/electron/Documents/Lelectron_rare/Kill_LIFE`
- Mascarade code actif: `/Users/electron/Documents/Projets/mascarade`

Dossier interdit pour ce lot:
- `/Users/electron/Documents/Lelectron_rare/Github_Repos/Perso/mascarade-main`

Regle operative:
- tout correctif Mascarade Mistral doit etre applique uniquement dans `/Users/electron/Documents/Projets/mascarade`
- tout suivi, journal de session, TODO et scripts cockpit restent uniquement dans `Kill_LIFE`
- ne pas melanger les deux copies ni reporter des chemins obsoletes dans les prochaines sessions

Chemins actifs de reference pour Mistral:
- provider standard: `/Users/electron/Documents/Projets/mascarade/core/mascarade/router/providers/mistral.py`
- agents distants Mistral: `/Users/electron/Documents/Projets/mascarade/core/mascarade/agents/mistral_agents.py`
- router API Mistral agents: `/Users/electron/Documents/Projets/mascarade/core/mascarade/routers/mistral_agents.py`

Garde-fou operateur ajoute:
- `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/tools/cockpit/mistral_workspace_guard.sh`
- usage: `bash tools/cockpit/mistral_workspace_guard.sh --action status --json`
- objectif: signaler toute derive de dossier et rappeler la source de verite unique

## Session 10 — 2026-03-22 — Preflight dataset local avant lots VM

Travail local uniquement dans `Kill_LIFE`.

Fait:
- refonte de `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/tools/cockpit/dataset_audit_tui.sh`
- le script couvre maintenant trois actions explicites:
  - `--action audit`
  - `--action preflight`
  - `--action paths`
- le script rappelle la source de verite Mascarade active: `/Users/electron/Documents/Projets/mascarade`
- le script expose dans le JSON cockpit:
  - readiness locale
  - chemins canoniques
  - presence de copie interdite
  - lots bloques cote VM: `T-MS-002`, `T-MS-003`, `T-MA-016`, `T-MA-017`, `T-MA-021`

Lecture operationnelle:
- `T-MA-015` devient la surface locale de preflight dataset
- la suite reste dependante du host VM dataset/fine-tune (`photon-docker` par defaut)
- pas de confusion entre audit local et execution VM

## Session 11 — 2026-03-22 — Re-synchronisation provider dans le repo actif

Travail applique uniquement dans:
- `/Users/electron/Documents/Projets/mascarade`

Fait:
- `T-MA-038` re-synchronise dans le repo actif, sans reutiliser la copie interdite `mascarade-main`
- provider ajoute et branche dans le routeur actif:
  - `/Users/electron/Documents/Projets/mascarade/core/mascarade/router/providers/mistral_agents.py`
  - `/Users/electron/Documents/Projets/mascarade/core/mascarade/router/providers/__init__.py`
  - `/Users/electron/Documents/Projets/mascarade/core/mascarade/router/router.py`
- bridge d'agents distants durci:
  - `/Users/electron/Documents/Projets/mascarade/core/mascarade/agents/mistral_agents.py`
  - base URL configurable
  - fallback beta conversations -> deprecated completions
  - IDs d'agents lus depuis la config active
- tests locaux ajoutes / ajustes:
  - `/Users/electron/Documents/Projets/mascarade/core/tests/test_mistral_agents.py`
  - `/Users/electron/Documents/Projets/mascarade/core/tests/test_mistral_agents_provider.py`
- validation locale passee:
  - `cd /Users/electron/Documents/Projets/mascarade/core && ./.venv/bin/python -m py_compile mascarade/config.py mascarade/agents/mistral_agents.py mascarade/router/providers/__init__.py mascarade/router/providers/mistral_agents.py mascarade/router/router.py tests/test_mistral_agents.py tests/test_mistral_agents_provider.py`
  - `cd /Users/electron/Documents/Projets/mascarade/core && ./.venv/bin/python -m pytest tests/test_mistral_agents.py tests/test_mistral_agents_provider.py tests/test_router.py -q`

Constat:
- le tracking session 8 disait `T-MA-038` termine, mais le repo actif n'avait pas encore le provider routeur branche
- l'etat est maintenant aligne entre tracking et code actif pour `T-MA-038`

Reste ouvert inchangé:
- `T-MA-016`, `T-MA-017`, `T-MA-021` toujours bloques cote VM / datasets / fine-tune
- `T-MA-023` reste reporte lot 24

## Session 11 — 2026-03-22 — Cartographie mesh Mascarade et sync .env

Travail local uniquement dans `Kill_LIFE`.

Fait:
- ajout de `/Users/electron/Documents/Lelectron_rare/Kill_LIFE/tools/cockpit/mascarade_mesh_env_sync.sh`
- le script fige les racines Mascarade canoniques par machine:
  - `clems@192.168.0.120` -> `/home/clems/mascarade`
  - `root@192.168.0.119` -> `/root/mascarade-main`
  - `kxkm@kxkm-ai` -> `/home/kxkm/mascarade`
  - `cils@100.126.225.111` -> `/Users/cils/mascarade-main`
- correction de l'hypothese fausse sur `cils`:
  - ce n'est pas un layout Linux `/home/cils/*`
  - le bon layout actif est macOS `/Users/cils/*`
- propagation `.env` refaite avec succes sur les 4 cibles via le script

Artefact de reference:
- `artifacts/cockpit/mascarade_mesh_env_sync/latest.json`

Lecture operationnelle:
- les prochains lots Mistral ne doivent plus re-decouvrir les racines Mascarade sur ces 4 machines
- utiliser `mascarade_mesh_env_sync.sh` comme source de verite operateur pour la sync d'environnement

## Session 12 — 2026-03-22 — Separation des cles Mistral router / governance

Travail local uniquement dans `Kill_LIFE`, sans modifier la convention provider Mascarade.

Decision retenue:
- `Mascarade` continue d'utiliser `MISTRAL_API_KEY` comme cle routeur
- `Kill_LIFE` utilise desormais `MISTRAL_GOVERNANCE_API_KEY` pour les scripts de gouvernance quand elle est presente
- fallback conserve: si `MISTRAL_GOVERNANCE_API_KEY` est absente, les scripts `Kill_LIFE` retombent sur `MISTRAL_API_KEY`

Fait:
- ajout de `tools/cockpit/load_mistral_governance_env.sh`
- ajout de `tools/cockpit/kill_life_mistral_governance_sync.sh`
- `e2e_agents_test.sh` charge maintenant la cle gouvernance si disponible
- `sentinelle_cron.sh` charge maintenant la cle gouvernance si disponible
- `tools/mistral/mistral_client.py` lit `MISTRAL_GOVERNANCE_API_KEY` puis fallback `MISTRAL_API_KEY`, puis fallback secret file local
- secret local hors repo cree et synchronise:
  - local -> `~/.kill-life/mistral.env`
  - clems -> `/home/clems/.kill-life/mistral.env`
  - root -> `/root/.kill-life/mistral.env`
  - kxkm -> `/home/kxkm/.kill-life/mistral.env`
  - cils -> `/Users/cils/.kill-life/mistral.env`

Artefact de reference:
- `artifacts/cockpit/kill_life_mistral_governance_sync/latest.json`

Point volontairement non fait:
- aucune seconde variable Mistral n'a ete ajoutee au code Mascarade
- le routeur Mascarade reste sur la seule variable canonique `MISTRAL_API_KEY`

## Session 13 — 2026-03-22 — Separation cockpit direct / runtime provider

Travail applique uniquement dans:
- `/Users/electron/Documents/Projets/mascarade`
- `/Users/electron/Documents/Lelectron_rare/Kill_LIFE`

Decision retenue:
- `Kill_LIFE` cockpit operateur reste en appels directs Mistral Studio
- le runtime Mascarade appelle les agents distants via le provider `mistral-agents`
- le repo historique `mascarade-main` reste interdit comme cible d'edition

Fait:
- mapping d'env `MISTRAL_AGENTS_API_MODE` + `MISTRAL_AGENT_*_ID` consolide dans `docs/MISTRAL_STUDIO_INTEGRATION.md`
- aucun secret ni ID reel supplementaire recopie dans le repo actif
- `T-MA-038` confirme comme implementation runtime canonique dans `/Users/electron/Documents/Projets/mascarade`

Impact:
- le tracking lot 23 reste aligne avec le code actif
- la separation cockpit/runtime est maintenant explicite pour les prochaines vagues Studio
