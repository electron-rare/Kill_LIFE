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

- [ ] **T-EDA-001** : Créer `PCBDesignerProvider` — API REST, 5 actions (upload/status/export/order/rules), design rules JLCPCB/PCBWay
- [ ] **T-EDA-002** : Créer `QuilterProvider` — 6 actions (submit/status/candidates/download/constraints/stackup), presets impedance
- [ ] **T-EDA-003** : Créer `KiCadHappyAgent` — 7 skills, fallback S-expr parser, base LCSC 15+ composants, export BOM multi-format
- [ ] **T-EDA-004** : Enregistrer providers dans `providers/__init__.py` (try/except pattern)
- [ ] **T-EDA-005** : Enregistrer agent dans `agents/__init__.py`

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

- [ ] **T-EDA-010** : Test unitaire `PCBDesignerProvider` — mock aiohttp, tester 5 handlers
- [ ] **T-EDA-011** : Test unitaire `QuilterProvider` — mock aiohttp, tester 6 handlers + presets
- [ ] **T-EDA-012** : Test unitaire `KiCadHappyAgent` — parser S-expr sur `DALI.kicad_sch`, BOM extract sur `bom.csv`
- [ ] **T-EDA-013** : Test intégration — workflow complet : parse schéma → BOM → sourcing LCSC → export JLCPCB
- [ ] **T-EDA-014** : Validation sur Hypnoled — soumettre `DALI_PCB_main` via PCBDesigner et Quilter
  - blocages actuels:
    - `API keys required`
    - `Hypnoled assets missing in current checkout`

### Phase 3 — Router intelligence

- [ ] **T-EDA-020** : Ajouter routing rules dans `mascarade_config.yaml` — quand router vers pcbdesigner vs quilter vs kicad_router
- [ ] **T-EDA-021** : Scoring adaptatif — comparer résultats PCBDesigner vs Quilter sur même board, ajuster quality_rank
- [ ] **T-EDA-022** : Pipeline chaîné : kicad-happy (analyse+BOM) → quilter (routage) → pcbdesigner (commande JLCPCB)

### Phase 4 — Enrichissements

- [ ] **T-EDA-030** : Étendre base LCSC dans `KiCadHappyAgent` — parser catalogue JLCPCB Assembly Parts
- [ ] **T-EDA-031** : Intégrer prix temps-réel LCSC/DigiKey via API
- [ ] **T-EDA-032** : DFM check avancé — via API Quilter ou PCBDesigner, pas juste heuristiques locales
- [ ] **T-EDA-033** : Support Altium import/export dans les 2 providers

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
