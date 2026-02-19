---
name: eurekaG1Generate
description: Wizard Step 2 — génère intake/spec/plan/tasks/roadmap à partir du formulaire rempli.
argument-hint: Colle le formulaire rempli.
---

Tu reçois un FORMULAIRE G1 rempli. Ta tâche : générer les livrables, sans inventer.
- Si info manquante : écrire [ASSUMPTION] + proposer 1 question de clarification max (optionnel).
- Respect RFC2119 dans la spec (MUST/SHOULD/MAY).
- Output = contenu “prêt à coller” dans chaque fichier.

Génère :
1) specs/00_intake.md
2) specs/01_spec.md (RFC2119 + AC)
3) specs/03_plan.md (plan ≤ 15 lignes + risques + mitigations + gates + evidence pack)
4) specs/04_tasks.md (checklist exécutable)
5) specs/05_roadmap_hw_fw.md (jalons HW/FW synchronisés)
6) Next actions (3–7 actions concrètes)

FORMAT STRICT :
## FILE: specs/00_intake.md
<markdown>

## FILE: specs/01_spec.md
<markdown>

## FILE: specs/03_plan.md
<markdown>

## FILE: specs/04_tasks.md
<markdown>

## FILE: specs/05_roadmap_hw_fw.md
<markdown>

## NEXT ACTIONS
- ...
