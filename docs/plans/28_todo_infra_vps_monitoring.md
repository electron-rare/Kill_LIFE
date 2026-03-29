# TODO 28 - Consolidation monitoring infra VPS

Plan: docs/plans/28_plan_infra_vps_monitoring.md
Last updated: 2026-03-29

## Phase 1 - Inventaire JSON canonique

- [ ] T-INF-001 - Creer artifacts/cockpit/infra_vps_inventory.json (13 services cockpit-v1)
- [ ] T-INF-002 - Creer specs/contracts/infra_vps.schema.json et valider inventaire
- [ ] T-INF-003 - Documenter champs manquants api-proxy cal-api

## Phase 2 - Script healthcheck bash

- [ ] T-INF-004 - Ecrire tools/cockpit/infra_vps_healthcheck.sh (DNS TLS TCP HTTP)
- [ ] T-INF-005 - Sortie JSON cockpit-v1
- [ ] T-INF-006 - Sortie markdown digest operateur
- [ ] T-INF-007 - Option --service nom

## Phase 3 - Audit securite services clems

- [x] T-INF-008 - Audit auth rag.saillant.cc (RAGFlow)
- [x] T-INF-009 - Audit auth + allowlist browser.saillant.cc (Browser Use)
- [x] T-INF-010 - Isolation reseau containers clems vs electron
- [x] T-INF-011 - docs/evidence/infra_sec_audit_2026-03-29.md

## Phase 4 - Integration cockpit

- [x] T-INF-012 - Lane infra_vps dans runtime_ai_gateway.sh
- [x] T-INF-013 - Champ infra_vps_status dans sortie JSON gateway
- [x] T-INF-014 - Mettre a jour runtime_mcp_ia_gateway.schema.json si besoin

## Phase 5 - Runbook operationnel

- [x] T-INF-015 - docs/INFRA_VPS_RUNBOOK_2026.md
- [x] T-INF-016 - Pointer depuis RUNBOOK.md
