# Workflow — Cabinet de conseil (stratégie → décision → roadmap)

## But
Transformer une demande floue en **décision actionnable** + **plan exécutable** (roadmap/backlog) avec risques cadrés.

## Entrées
- Brief client / demande interne
- Contraintes (délai, budget, compliance, supply)
- Contexte produit

## Sorties
- Spec RFC2119 (exigences)
- Options + tradeoffs + recommandation
- Roadmap + backlog (WBS)
- ADR (decision record)

## Phases (opérationnel)

### 0) Intake (30–60 min)
- Clarifier : problème, objectifs, contraintes, “definition of done”
- Output : **problem statement** + **outcomes**
- Labels : `type:consulting` + `needs:triage`

### 1) Diagnostic (0.5–2 j)
- Analyse existant (repo, arch, contraintes)
- Lister hypothèses et risques
- Output : *assumptions log* + risques + questions ouvertes
- Label conseillé : `ai:plan` (si tu veux produire un diagnostic structuré en PR docs)

### 2) Options & arbitrage (0.5–2 j)
- 2–4 options max
- Tradeoffs : coût/temps/risque/perf/conso
- Output : recommandation + ADR
- Label : `ai:plan`

### 3) Roadmap & backlog (0.5–2 j)
- Roadmap jalonnée (V0/V1/RC)
- Backlog : epics + stories + AC
- Output : `ai:tasks`

### 4) Kickoff exécution (selon besoin)
- Impl minimal / prototype
- Output : PR d’impl + tests minimaux
- Label : `ai:impl`

## Gates
- Spec lint OK
- ADR présent pour les décisions structurantes
- Scope guard OK (pas de modifications hors scope)
- Evidence pack joint

## Evidence pack (minimum)
- `docs/evidence/` : notes, ADR, comparatif options, backlog

## Comment l’utiliser dans ce repo
1. Ouvre une issue avec le template **Cabinet — Intake / Cadrage**.
2. Triage : ajoute `prio:*` `risk:*` `scope:*`.
3. Quand l’intake est validé : ajoute `ai:spec` ou `ai:plan`.
4. La PR créée doit contenir : spec/plan/ADR/backlog.
