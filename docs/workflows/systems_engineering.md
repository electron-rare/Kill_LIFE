# Workflow — Bureau d’études / Ingénierie système (HW/FW)

## But
Produire une architecture end‑to‑end : interfaces, budgets, risques, plan de validation, puis backlog.

## Phases

### 1) Requirements engineering (requirements → spec)
- Livrables : RFC2119 + NFR + AC + matrice traçabilité (AC → tests)
- Label : `ai:spec`

### 2) Architecture système (design → ADR)
- Livrables : diagrammes blocs, interfaces, budgets (power/memory/latency), modes de panne, ADR
- Label : `ai:plan`

### 3) Design review (DR0/DR1)
- DR0 : cohérence + risques (pas de “dead ends”)
- DR1 : budgets + plan de validation + BOM
- Livrables : checklist review + décisions (ADR)
- Labels : `ai:plan` puis `ai:qa` (si tu veux injecter la test matrix)

### 4) Backlog (WBS)
- Livrables : epics/stories, tâches, critères d’acceptation
- Label : `ai:tasks`

### 5) Exécution (impl + tests)
- Firmware : drivers + tasks + logs + watchdog
- Hardware : schéma/PCB + DRC/ERC
- Labels : `ai:impl` / `ai:qa`

## Gates
- Budgets explicités (power, mémoire, latence)
- Plan de validation (unit/integration/HIL/endurance)
- Scope guard :
  - `ai:spec` doit rester dans `specs/` + `docs/`
  - `ai:impl` ne touche pas aux workflows

## Evidence pack
Voir `docs/evidence/evidence_pack.md` + exports (KiCad + BOM + logs CI).

## Mode “BE” recommandé (cadence)
- Triage hebdo (30 min)
- DR0 et DR1 (60–90 min)
- ADR obligatoire pour : MCU/RTOS, bus, power architecture, radio stack
