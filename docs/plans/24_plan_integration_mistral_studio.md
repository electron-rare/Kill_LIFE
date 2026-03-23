# Plan 24 — Intégration Mistral AI Studio Complète

> **Owner**: PM-Mesh + Architect + Forge
> **Date**: 2026-03-21
> **Statut**: 🟢 Lancé
> **Dépendances**: Lot 23 (agents créés ✅)

---

## Contexte

Suite au Lot 23 (agents Mistral créés + provider), ce lot couvre l'intégration
de **toutes les fonctionnalités** de Mistral AI Studio dans l'écosystème :
Fichiers, Fine-tune, Batches, IA Documentaire, Audio, Vibe CLI, Codestral.

## Phases

### P0 — Fichiers & Datasets (J1-J2)

| # | Tâche | Agent | Livrable | Status |
|---|-------|-------|---------|--------|
| 1 | Créer `mistral_studio_tui.sh` cockpit | Doc + PM | Script TUI | [x] |
| 2 | Upload datasets fine-tune via API Files | Forge | 10 JSONL Mistral | [ ] |
| 3 | Upload docs RAG pour Tower | Tower + Doc | Document Library | [ ] |
| 4 | Upload datasheets composants pour OCR | HW + Sentinelle | Pipeline OCR | [ ] |

### P1 — Fine-tune & Batches (J3-J7)

| # | Tâche | Agent | Livrable | Status |
|---|-------|-------|---------|--------|
| 5 | Fine-tune KiCad sur Mistral Small | Forge + HW | ft:kicad-v1 | [ ] |
| 6 | Fine-tune SPICE+Embedded sur Codestral | Forge + FW | ft:spice-embedded-v1 | [ ] |
| 7 | Batch benchmark base vs fine-tuned (100 prompts) | QA + Forge | Rapport comparatif | [ ] |
| 8 | Configurer Document Library RAG pour Tower | Tower | Recherche docs active | [ ] |

### P2 — Intégrations Studio (J8-J10)

| # | Tâche | Agent | Livrable | Status |
|---|-------|-------|---------|--------|
| 9 | Intégrer IA Documentaire dans pipeline OCR | Sentinelle + HW | OCR automatisé | [ ] |
| 10 | Intégrer Audio STT dans ops workflow | Sentinelle | Transcription auto | [ ] |
| 11 | Installer Vibe CLI sur VM photon-docker | Devstral | CLI opérationnel | [ ] |
| 12 | Intégrer Codestral FIM dans Mascarade | Architect + Devstral | Provider FIM | [ ] |

### P3 — Production (J11-J14)

| # | Tâche | Agent | Livrable | Status |
|---|-------|-------|---------|--------|
| 13 | Déployer modèles fine-tuned dans Mascarade | Architect | Router mis à jour | [ ] |
| 14 | Tests E2E pipeline Studio→Mascarade→Agent | QA | Evidence pack | [ ] |
| 15 | Documentation Outline (4 pages Studio) | Doc | Wiki à jour | [ ] |
| 16 | Cron audit qualité modèles (weekly) | QA + Sentinelle | Benchmark continu | [ ] |

---

## Risques

| Risque | Impact | Mitigation |
|--------|--------|-----------|
| Datasets insuffisants (<5k exemples) | Fine-tune dégradé | Augmentation via prompting + OSS |
| Coût fine-tune élevé | Budget | Commencer par Mistral Small (moins cher) |
| Playground nécessite plan payant | Tests limités | Utiliser API directement via TUI |
| virtiofs deadlock | Code illisible | Audit sur VM directement |

## Critères de succès

- [ ] 2 modèles fine-tuned déployés dans Mascarade
- [ ] Benchmark >15% amélioration sur prompts métier
- [ ] IA Documentaire OCR fonctionnel sur datasheets
- [ ] Audio STT intégré dans workflow ops
- [ ] Vibe CLI opérationnel sur VM
