# TODO 26 — Intégration outils EDA+IA dans Mascarade

> **Owner**: Architect + SM-Ops
> **Date création**: 2026-03-22
> **Statut global**: 🟡 Realignment — spec cadree, implementation absente dans le repo actif
> **Référence**: T-EDA-001 (PCB Designer AI), T-EDA-002 (Quilter), T-EDA-003 (kicad-happy)

---

## Contexte

Intégration de 3 outils EDA+IA dans l'architecture Mascarade pour couvrir le workflow complet :
schéma → placement → routage IA → export → fabrication JLCPCB.

Ces outils complètent le KiCadRouterProvider existant (routage interne) et le MistralProvider (review Forge).

## Outils intégrés

| Outil | Type | Chemin cible dans le repo actif | Rôle |
|-------|------|-------------------|------|
| PCB Designer AI | Provider | `core/mascarade/router/providers/pcbdesigner.py` *(planned, absent du repo actif)* | Upload schema -> IA place+route -> export Gerber -> commande JLCPCB one-click |
| Quilter | Provider | `core/mascarade/router/providers/quilter.py` *(planned, absent du repo actif)* | Routage physique+RL, candidats multiples, scores SI/thermal/DFM |
| kicad-happy | Agent | `core/mascarade/agents/kicad_happy_agent.py` *(planned, absent du repo actif)* | Analyse schema/PCB, BOM extract, sourcing LCSC, export JLCPCB, DFM check |

## Tâches

### Phase 1 — Realignment + spec-ready

- [x] **T-EDA-001** : Créer `PCBDesignerProvider` — API REST, 5 actions (upload/status/export/order/rules), design rules JLCPCB/PCBWay — livré dans mascarade PR #30
- [x] **T-EDA-002** : Créer `QuilterProvider` — 6 actions (submit/status/candidates/download/constraints/stackup), presets impedance — livré dans mascarade PR #30
- [x] **T-EDA-003** : Créer `KiCadHappyAgent` — 7 skills, fallback S-expr parser, base LCSC 65+ composants, export BOM multi-format — livré dans mascarade PR #30
- [x] **T-EDA-004** : Enregistrer providers dans `providers/__init__.py` (try/except pattern) — livré dans mascarade PR #30
- [x] **T-EDA-005** : Enregistrer agent dans `agents/__init__.py` — livré dans mascarade PR #30

### Reality check (2026-03-22)

- Repo Mascarade actif confirme: `/Users/electron/Documents/Projets/mascarade`
- Fichiers absents dans le repo actif:
  - `core/mascarade/router/providers/pcbdesigner.py`
  - `core/mascarade/router/providers/quilter.py`
  - `core/mascarade/agents/kicad_happy_agent.py`
- Aucun statut `done` n'est autorise sur `T-EDA-001` a `T-EDA-005` tant que:
  - le fichier n'existe pas dans le repo actif
  - il est branche au routeur ou registre approprie
  - la source de verite `Kill_LIFE` et le repo Mascarade actif sont alignes

### Phase 2 — Tests et validation

- [x] **T-EDA-010** : Test unitaire `PCBDesignerProvider` — 30 tests, mock httpx — livré dans mascarade PR #30
- [x] **T-EDA-011** : Test unitaire `QuilterProvider` — 30 tests, mock httpx — livré dans mascarade PR #30
- [x] **T-EDA-012** : Test unitaire `KiCadHappyAgent` — 40 tests, S-expr parser, BOM, DFM — livré dans mascarade PR #30
- [x] **T-EDA-013** : Test intégration — workflow complet : parse schéma → BOM → sourcing LCSC → export JLCPCB — `test/test_eda_integration.py`
- [ ] **T-EDA-014** : Validation sur Hypnoled — soumettre `DALI_PCB_main` via PCBDesigner et Quilter
  - blocages actuels:
    - `API keys required`
    - `Hypnoled assets missing in current checkout`

### Phase 3 — Router intelligence

- [x] **T-EDA-020** : Ajouter routing rules — `eda_routing_rules.py` complexity/budget routing — livré dans mascarade PR #31
- [x] **T-EDA-021** : Scoring adaptatif — recommend_provider() avec complexity scoring — livré dans mascarade PR #31
- [x] **T-EDA-022** : Pipeline chaîné — `eda_pipeline.py` KiCadHappy→Quilter→PCBDesigner + /v1/eda/pipeline — livré dans mascarade PR #31

### Phase 4 — Enrichissements

- [x] **T-EDA-030** : Étendre base LCSC — 65+ composants dans bom_analyzer.py (resistors, caps, diodes, transistors, ICs, connectors, crystals)
- [x] **T-EDA-031** : Intégrer prix temps-réel LCSC via API — `fetch_lcsc_prices()` dans `tools/industrial/bom_analyzer.py`
- [x] **T-EDA-032** : DFM check avancé — `dfm_check_api()` local rules-based, structured for future API swap — dans `tools/industrial/bom_analyzer.py`
- [x] **T-EDA-033** : Support Altium import/export — `altium_bridge.py` utility module: parse Altium BOM CSV, convert Altium<->KiCad BOM, convert KiCad netlist to Altium format — livré dans mascarade PR feat/altium-bridge

## Architecture

```
                    ┌─────────────┐
                    │  Mascarade  │
                    │   Router    │
                    └──────┬──────┘
                           │
          ┌────────────────┼────────────────┐
          │                │                │
   ┌──────▼──────┐  ┌─────▼──────┐  ┌──────▼──────┐
   │ PCBDesigner │  │  Quilter   │  │ KiCadRouter │
   │  Provider   │  │  Provider  │  │  Provider   │
   │ (externe)   │  │ (externe)  │  │ (interne)   │
   └─────────────┘  └────────────┘  └─────────────┘
          │                │
          │    ┌───────────┘
          │    │
   ┌──────▼────▼──────┐
   │  KiCadHappy      │
   │  Agent            │
   │  (analyse+BOM)    │
   └──────────────────┘
          │
   ┌──────▼──────┐
   │  JLCPCB     │
   │  Fabrication │
   └─────────────┘
```

## Métriques Phase 1

| Métrique | Valeur |
|----------|--------|
| Fichiers implémentés dans le repo actif | 0 |
| Fichiers spécifiés / prévus | 3 (2 providers + 1 agent) |
| Actions PCBDesigner prévues | 5 (upload, status, export, order, rules) |
| Actions Quilter prévues | 6 (submit, status, candidates, download, constraints, stackup) |
| Skills kicad-happy prévues | 7 (analyze_schematic, analyze_pcb, bom_extract, bom_export, component_source, dfm_check, review) |
| Composants LCSC ciblés | 15+ |
| Formats export BOM ciblés | 3 (JLCPCB, DigiKey, Mouser) |
| Presets contraintes ciblés | 3 (jlcpcb_2layer, jlcpcb_4layer, hypnoled_dali) |

## Prochaine action

1. Realigner ce lot et la cartographie ecosyteme sur l'etat reel du repo actif.
2. Fermer d'abord la chaine locale `fab package` (`BOM + DRC + Gerber/drill + provenance`) dans `Kill_LIFE`.
3. Implementer `T-EDA-001` a `T-EDA-005` seulement apres validation du contrat `fab package`.
