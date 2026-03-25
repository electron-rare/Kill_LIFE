# TODO 23 — Intégration Mistral Agents

> **Owner**: PM-Mesh + Architect
> **Date création**: 2026-03-21
> **Dernière MAJ**: 2026-03-21 (session 4)
> **Dernière MAJ**: 2026-03-22 (session 5)
> **Statut global**: 🟢 Phase 0 DONE — Phase 1 DONE — Phase 2 quasi-done (19/24) — Migration Beta API en cours — Agents AI Studio v2 configurés

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
- [ ] T-MA-037: Migrer `mistral_agents_tui.sh` vers Beta Conversations API
- [ ] T-MA-038: Migrer `mistral_agents_api.py` (Mascarade provider) vers Beta API

## P3 — Évolutions futures

- [ ] T-MA-030: Implémenter A2A protocol dans Mascarade (MCP + A2A complémentaires)
- [ ] T-MA-031: Migrer orchestrateur Mascarade vers graph-based state (LangGraph-compatible)
- [ ] T-MA-032: Ajouter RAG Document Library à Tower (Outline + docs PDF) — via MistralLibraryClient
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
