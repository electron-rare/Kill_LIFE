# Plan 23 — Intégration Mistral Agents dans l'écosystème saillant.cc

> **Owner**: PM-Mesh + Architect
> **Date création**: 2026-03-21
> **Statut**: 🟢 Lancé
> **Dépendances**: Lot 22 (intelligence agentique), Mascarade providers

---

## Objectif

Intégrer 4 agents Mistral spécialisés dans l'écosystème saillant.cc :
- **Sentinelle** (Ops/Monitoring) — diagnostic infra via Mascarade/Langfuse/Grafana/Docker
- **Tower** (Commercial) — scoring leads, rédaction, CRM
- **Forge** (Fine-tune) — pilotage pipeline DPO/SimPO/KTO sur données KiCad/SPICE
- **Devstral** (Code) — dev workflow avec GitHub/Linear/Docker CI

## Architecture cible

```
Mascarade Router ──→ Mistral Agents API
                       ├── Sentinelle (mistral-medium) ──→ Langfuse, Grafana, Docker
                       ├── Tower (mistral-large) ──→ Outline, CRM/PostgreSQL
                       ├── Forge (codestral) ──→ Fine-tune pipeline, datasets
                       └── Devstral (devstral) ──→ GitHub, Linear, Docker exec
```

## Phases

### Phase 0 — Fondations (J1-J4) — P0

| # | Tâche | Agent BMAD | Livrable | Done |
|---|-------|-----------|----------|------|
| 1 | Créer les 4 agents sur console.mistral.ai | PM | 4 agents configurés | [x] |
| 2 | Implémenter `mistral_agents_api.py` provider dans Mascarade | Architect + Builder | Provider fonctionnel | [x] |
| 3 | Tests handoff inter-agents | QA | Suite de tests | [x] |
| 4 | Déployer `mistral_agents_tui.sh` cockpit | Doc | Script opérationnel | [x] |
| 5 | Déployer `integration_health_tui.sh` cockpit | Doc | Script opérationnel | [x] |

### Phase 1 — Branchements (J5-J10) — P1

| # | Tâche | Agent BMAD | Livrable | Done |
|---|-------|-----------|----------|------|
| 6 | Brancher Sentinelle sur API Mascarade /health /providers /metrics | Ops + Builder | Monitoring actif | [x] |
| 7 | Brancher Sentinelle sur Langfuse traces + Grafana | Ops | Dashboard | [x] |
| 8 | Configurer Tower avec Outline search + template emails | Builder | Pipeline scoring | [x] |
| 9 | Audit qualité des 10 datasets fine-tune | QA + Forge | Rapport qualité | [x] |
| 10 | Lancer fine-tune KiCad sur Mistral Studio | Forge | Modèle v1 | [ ] |

### Phase 2 — Production (J11-J14) — P2

| # | Tâche | Agent BMAD | Livrable | Done |
|---|-------|-----------|----------|------|
| 11 | Intégrer Devstral dans workflow CI/CD | Architect + Devstral | PR automation | [x] |
| 12 | Benchmark fine-tune: base vs KiCad-tuned (100 prompts) | QA + Forge | Rapport benchmark | [ ] |
| 13 | Documentation complète dans Outline wiki | Doc | 4 pages wiki | [x] |
| 14 | Cron health-check Sentinelle (06:00 daily) | Ops | Cron configuré | [x] |

## Critères de succès

- 4/4 agents déployés et fonctionnels sur Mistral Studio
- Handoff inter-agents validé (Sentinelle → Devstral pour fix auto)
- Fine-tune KiCad : accuracy >85% sur benchmark domaine
- Health-check automatique : 0 faux positifs sur 7 jours
- TUI cockpit intégré dans `yiacad_operator_index.sh`

## Risques

| Risque | Impact | Mitigation |
|--------|--------|-----------|
| API Mistral Agents en beta, breaking changes | Élevé | Abstraire via provider Mascarade, versionner |
| Qualité datasets insuffisante pour fine-tune | Moyen | Audit P1 avant lancement fine-tune |
| Coût API Mistral en production | Moyen | Monitoring via Sentinelle, fallback Ollama |
| Latence handoff inter-agents >5s | Faible | Circuit breaker Mascarade |

## Référence

- Master Integration Plan: `MASTER_INTEGRATION_PLAN_2026-03-21.md`
- Mistral Agents API: https://docs.mistral.ai/agents/introduction
- MCP 2026 best practices: topologie fédérée, pas de god-orchestrator
- LangGraph state persistence: PostgresSaver pour crash recovery
