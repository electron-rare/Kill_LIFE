# Vue canonique des sous-systemes Kill_LIFE

> Date: 2026-03-25 | Source: Plan 21 - refonte globale YiACAD

---

## 1. Cartographie des sous-systemes

### 1.1 ai-agentic-embedded-base (zone pilotage)

**Role**: cadre de refonte spec-first, gouvernance IA, orchestration des lots, contrats mesh.

| Couche | Contenu | Fichiers cles |
|---|---|---|
| Intake | Probleme, utilisateurs, hypotheses, risques | `specs/00_intake.md` |
| Spec | Objectifs, user stories, exigences fonctionnelles/non-fonctionnelles, AC | `specs/01_spec.md` |
| Architecture | Diagramme bloc Mermaid, ADR, etats de lot, risques | `specs/02_arch.md` |
| Plan | Enchainement autonome des lots, scope tools/cockpit | `specs/03_plan.md` |
| Tasks | Lots prioritaires, responsabilites, write-sets | `specs/04_tasks.md` |
| Contrats | JSON schemas (agent_handoff, workflow_handshake, repo_snapshot, machine_registry, mascarade_dispatch, yiacad_uiux_output, context_broker, operator_lane_evidence, runtime_mcp_ia_gateway) | `specs/contracts/*.schema.json` |
| Specs domaine | MCP, KiCad, knowledge base, CI/CD, agentic intelligence, YiACAD global/backend/UI-UX, ZeroClaw dual HW | `specs/*_spec.md` |

**Principes directeurs**: spec-driven chain comme source de verite, IA en overlay optionnel avec gates, labels `ai:*` comme garde-fous.

### 1.2 zeroclaw (zone runtime agent)

**Role**: runtime agent autonome Rust, trait-driven, $10 hardware, <5MB RAM.

| Couche | Contenu | Fichiers cles |
|---|---|---|
| Core runtime | Agent loop, dispatcher, classifier | `src/agent/` |
| Providers | OpenRouter, GLM, router, resilient wrapper | `src/providers/` |
| Channels | Telegram, Discord, Slack, iMessage, QQ, Signal, WhatsApp, Mattermost, DingTalk, CLI | `src/channels/` |
| Tools | Shell, file, memory, browser, HTTP, git, cron, screenshot, PDF, hardware | `src/tools/` |
| Memory | SQLite, markdown, vector, snapshot, lucid, response cache | `src/memory/` |
| Security | Bubblewrap, Docker, Firejail, Landlock, secrets, audit | `src/security/` |
| Peripherals | STM32 Nucleo, Arduino, RPi GPIO, serial, flash | `src/peripherals/` |
| Observability | Log, OTEL, Prometheus, verbose, multi, noop | `src/observability/` |
| Tunnels | Cloudflare, ngrok, Tailscale, custom | `src/tunnel/` |
| Tests | 12 integration tests (e2e, memory, config, provider, channel, security) | `tests/*.rs` |
| Docs | ~90 fichiers multi-langues (EN, ZH, JA, RU, FR, VI), runbook, security, hardware, contributing | `docs/` |

**Principes directeurs**: KISS, YAGNI, DRY rule-of-three, SRP, fail-fast, secure-by-default, determinism.

### 1.3 openclaw (zone observateur sandbox)

**Role**: runtime agent local en mode observateur strict -- ne commite pas, ne modifie pas le code.

| Couche | Contenu | Fichiers cles |
|---|---|---|
| Integration | Labels `ai:*`, commentaires sanitises, GitHub Agentic Workflows | `README.md` |
| VM sandbox | QEMU images Debian, scripts de creation/destruction VM | `vm/` |
| Setup local | Installation, verification observer-only, scan secrets, check mounts | `local_setup/` |
| Onboarding | Guide contributeur, exemples, supports visuels, guide VM sandbox, test actions | `onboarding/` |

**Principes directeurs**: least privilege, sandbox obligatoire, aucun acces secrets, write surface = zero code.

---

## 2. Relations inter-sous-systemes

```
ai-agentic-embedded-base (specs/contrats)
    |
    +--- specs/contracts/ -----> zeroclaw (consomme les contrats runtime)
    |                           - agent_handoff, workflow_handshake
    |                           - machine_registry, mascarade_dispatch
    |
    +--- labels ai:* ---------> openclaw (observe et labellise)
    |                           - mode viewer/label manager uniquement
    |
    +--- tools/cockpit/ ------> operateur humain (TUI entrypoint)
```

Flux de donnees canonique:
1. `ai-agentic-embedded-base` definit les specs, contrats et plans
2. `zeroclaw` implemente le runtime agent en Rust avec les contrats
3. `openclaw` observe, labellise et remonte le statut sans modifier le code
4. `tools/cockpit/` fournit la surface operateur unifiee

---

## 3. Tableau de maturite par lane

Echelle: 0 = absent, 1 = ebauche, 2 = partiel, 3 = utilisable, 4 = complet, 5 = maintenu et auditable

| Lane | ai-agentic-embedded-base | zeroclaw | openclaw | Score moyen |
|---|---|---|---|---|
| **Specs** | 5 (chain 00-04 + 14 specs domaine + contracts) | 4 (CLAUDE.md + architecture doc) | 2 (README seul) | 3.7 |
| **Code** | 2 (scripts cockpit, pas de code propre) | 5 (100+ modules Rust, crates) | 3 (VM scripts, local_setup, onboarding test) | 3.3 |
| **Tests** | 1 (contract tests root-level) | 4 (12 integration tests + cargo test) | 2 (1 test Python onboarding) | 2.3 |
| **Docs** | 3 (README, specs lisibles) | 5 (~90 docs multi-langues, SUMMARY, runbook) | 3 (onboarding guides, VM sandbox guide) | 3.7 |
| **Ops** | 4 (65+ TUI cockpit scripts, log_ops, lot_chain) | 3 (bootstrap.sh, Docker, CI workflows) | 3 (VM create/destroy, install scripts) | 3.3 |

### Synthese maturite

| Zone | Score global /25 | Statut |
|---|---|---|
| ai-agentic-embedded-base | 15 | Pilotage solide, code/tests faibles |
| zeroclaw | 21 | Maturite elevee, tests a renforcer |
| openclaw | 13 | Fonctionnel mais sous-documente et sous-teste |

---

## 4. KPI de densite documentaire et fragmentation

### 4.1 Densite documentaire (ratio docs/code)

| Zone | Fichiers doc | Fichiers code/scripts | Ratio doc/code |
|---|---|---|---|
| ai-agentic-embedded-base | 42 (specs) | 0 (pas de code propre) | N/A (pure spec) |
| zeroclaw | ~90 (docs/) | ~100 (src/*.rs) | 0.90 |
| openclaw | 10 (onboarding + README) | 17 (vm + local_setup scripts) | 0.59 |
| Root (Kill_LIFE) | ~40 (docs/plans) + ~20 (docs/) | 65 (tools/cockpit) + 17 (test/) | 0.73 |

### 4.2 Fragmentation

| Indicateur | Valeur | Seuil acceptable | Statut |
|---|---|---|---|
| Plans dans docs/plans/ | 40+ fichiers | <30 | FRAGMENTE |
| Specs dupliquees (root specs/ = mirror de ai-agentic-embedded-base/specs/) | 2 copies identiques | 1 seule source | REDONDANT |
| Scripts cockpit | 65+ scripts | <40 | FRAGMENTE |
| Contrats JSON schemas | 17 fichiers | OK | OK |
| Langues docs zeroclaw | 6 langues (EN/ZH/JA/RU/FR/VI) | OK | OK |
| README variants (root) | 2 (EN, FR) | OK | OK |

### 4.3 Points d'attention fragmentation

1. **Specs miroir**: `specs/` (root) et `ai-agentic-embedded-base/specs/` contiennent les memes fichiers. Risque de desynchronisation. Action: definir une seule source de verite et un symlink ou script de sync.
2. **Explosion cockpit**: 65+ scripts dans `tools/cockpit/` sans index structure. Action: regrouper par domaine (mascarade, yiacad, ops, mesh, intelligence).
3. **Plans non archives**: 40+ plans dans `docs/plans/` melangent actifs et historiques. Action: separer `docs/plans/active/` et `docs/plans/archive/`.

### 4.4 Couverture de test

| Zone | Tests | Fichiers testes | Couverture estimee |
|---|---|---|---|
| Root (Python) | 17 test files | cockpit contracts, MCP, firmware, sanitizer | ~25% des scripts cockpit |
| zeroclaw (Rust) | 12 integration tests | agent, memory, config, provider, channel | ~15% des modules src/ |
| openclaw | 1 test file | onboarding actions | ~5% |

---

## 5. Vue d'ensemble rapide

```
Kill_LIFE/
  ai-agentic-embedded-base/   [PILOTAGE]  specs, contrats, plans -- score 15/25
  zeroclaw/                    [RUNTIME]   Rust agent, multi-provider/channel -- score 21/25
  openclaw/                    [OBSERVER]  sandbox viewer, labels ai:* -- score 13/25
  specs/                       [MIROIR]    copie de ai-agentic-embedded-base/specs
  tools/cockpit/               [OPS TUI]   65+ scripts entree operateur
  docs/plans/                  [PLANS]     40+ plans actifs/historiques
  test/                        [TESTS]     17 contract tests Python
```

---

*Derniere mise a jour: 2026-03-25 -- genere depuis Plan 21 refonte globale YiACAD*
