---
goal: "Consolidation monitoring infra VPS - healthcheck runbook cockpit Kill_LIFE"
version: "1.0"
date_created: "2026-03-29"
last_updated: "2026-03-29"
owner: "electron-rare / ops-agent"
status: "In progress"
tags: ["ops", "infrastructure", "monitoring", "healthcheck", "chore"]
---

# Plan 28 - Consolidation monitoring infra VPS

Status: In progress

## Introduction

Ce plan formalise l'inventaire complet des services VPS Saillant (*.saillant.cc
et *.lelectronrare.fr), la mise en place d'un script de healthcheck automatise,
et leur integration dans le cockpit Kill_LIFE (runtime_ai_gateway).

RAGFlow (rag.saillant.cc) et Browser Use (browser.saillant.cc) sont traites comme
agents externes consommateurs de la pile Mascarade.

owner_repo : Kill_LIFE

---

## 1. Requirements and Constraints

- REQ-001 : Tout service VPS expose doit apparaitre dans artifacts/cockpit/infra_vps_inventory.json
- REQ-002 : Healthcheck couvre DNS TLS port TCP et reponse HTTPS >= 200
- REQ-003 : Resultats compatibles format cockpit-v1 JSON (status degraded_reasons engine_status)
- REQ-004 : Runbook executable sans dependances externes (bash curl nc dig)
- SEC-001 : Browser Use (browser.saillant.cc) - auditer exposition SSRF auth allowlist isolation reseau
- SEC-002 : RAGFlow (rag.saillant.cc) - API non exposee sans authentification
- CON-001 : Services /home/clems/ - utilisateur Unix different - pas de sudo
- CON-002 : Pas de dependance agent externe (offline-safe)
- GUD-001 : Sortie JSON (--json) et digest markdown court pour l'operateur
- GUD-002 : Etat degrade expose etapes de remediation executables
- PAT-001 : Convention cockpit-v1 (tools/cockpit/runtime_ai_gateway.sh)

---

## 2. Inventaire des services

| N  | Path                         | Domaine                 | Service                     | User     | Statut       |
|----|------------------------------|-------------------------|-----------------------------|----------|--------------|
| 1  | /home/electron/mascarade/    | mascarade.saillant.cc   | Mascarade LLM router        | electron | actif        |
| 2  | /home/electron/qdrant/       | qdrant.saillant.cc      | Qdrant vector store         | electron | actif        |
| 3  | /home/electron/n8n/          | n8n.saillant.cc         | n8n workflow automation     | electron | actif        |
| 4  | /home/electron/gitea/        | gitea.saillant.cc       | Gitea self-hosted Git       | electron | actif        |
| 5  | /home/electron/nextcloud/    | nextcloud.saillant.cc   | Nextcloud stockage          | electron | actif        |
| 6  | /home/electron/minio/        | minio.saillant.cc       | MinIO object storage        | electron | actif        |
| 7  | /home/electron/vaultwarden/  | vault.saillant.cc       | Vaultwarden secrets         | electron | actif        |
| 8  | /home/electron/traefik/      | --                      | Traefik reverse proxy       | electron | actif        |
| 9  | /home/electron/portainer/    | portainer.saillant.cc   | Portainer containers        | electron | actif        |
| 10 | --                           | api.lelectronrare.fr    | API proxy passerelle        | electron | a verifier   |
| 11 | --                           | cal.lelectronrare.fr    | Cal.com prise de RDV        | --       | parque       |
| 12 | /home/clems/ragflow/         | rag.saillant.cc         | RAGFlow RAG pipeline        | clems    | a auditer    |
| 13 | /home/clems/browser-use/     | browser.saillant.cc     | Browser Use navigation AI   | clems    | a auditer SEC|

---

## 3. Implementation Steps

### Phase 1 - Inventaire JSON canonique

GOAL-001 : Figer l'inventaire VPS dans un fichier JSON machine-readable versionnable.

| Task      | Description                                                                 | Completed | Date |
|-----------|-----------------------------------------------------------------------------|-----------|------|
| T-INF-001 | Creer artifacts/cockpit/infra_vps_inventory.json (13 services cockpit-v1)   |           |      |
| T-INF-002 | Valider contre specs/contracts/infra_vps.schema.json                        |           |      |
| T-INF-003 | Documenter champs manquants api-proxy et cal-api                            |           |      |

### Phase 2 - Script healthcheck bash

GOAL-002 : Fournir tools/cockpit/infra_vps_healthcheck.sh executable sans dependances.

| Task      | Description                                                              | Completed | Date |
|-----------|--------------------------------------------------------------------------|-----------|------|
| T-INF-004 | Ecrire le script - check DNS (dig) TLS (curl -I) TCP (nc -z) HTTP >= 200 |           |      |
| T-INF-005 | Sortie JSON cockpit-v1 : status degraded_reasons[] timestamp             |           |      |
| T-INF-006 | Sortie markdown digest operateur (tableau emoji par service)              |           |      |
| T-INF-007 | Option --service <nom> pour cibler un service unique                     |           |      |

### Phase 3 - Audit securite services clems

GOAL-003 : Valider que RAGFlow et Browser Use ne sont pas exposes sans controle d'acces.

| Task      | Description                                                    | Completed | Date |
|-----------|----------------------------------------------------------------|-----------|------|
| T-INF-008 | Verifier rag.saillant.cc retourne 401/403 sans token           |           |      |
| T-INF-009 | Verifier browser.saillant.cc a allowlist URLs et auth en place |           |      |
| T-INF-010 | Verifier isolation reseau containers clems vs electron         |           |      |
| T-INF-011 | Documenter dans docs/evidence/infra_sec_audit_2026-03-29.md   |           |      |

### Phase 4 - Integration cockpit Kill_LIFE

GOAL-004 : Remonter l'etat infra VPS dans runtime_ai_gateway comme surface externe.

| Task      | Description                                                                    | Completed | Date |
|-----------|--------------------------------------------------------------------------------|-----------|------|
| T-INF-012 | Ajouter lane infra_vps dans tools/cockpit/runtime_ai_gateway.sh               |           |      |
| T-INF-013 | Exposer infra_vps_status dans JSON de sortie de la gateway                     |           |      |
| T-INF-014 | Mettre a jour specs/contracts/runtime_mcp_ia_gateway.schema.json si besoin    |           |      |

### Phase 5 - Runbook operationnel

GOAL-005 : Documenter les procedures de remediation.

| Task      | Description                                                  | Completed | Date |
|-----------|--------------------------------------------------------------|-----------|------|
| T-INF-015 | Ecrire docs/INFRA_VPS_RUNBOOK_2026.md                       |           |      |
| T-INF-016 | Ajouter pointeur dans RUNBOOK.md                            |           |      |

---

## 4. Alternatives

- ALT-001 : Prometheus + Blackbox Exporter - ecarte overhead infra non justifie pour 13 services
- ALT-002 : Uptime Kuma via Portainer - complement UI possible mais ne remplace pas le healthcheck cockpit
- ALT-003 : Monitoring via n8n - ecarte couplage fort avec service lui-meme monitore

---

## 5. Dependencies

- DEP-001 : tools/cockpit/runtime_ai_gateway.sh - point integration lane infra
- DEP-002 : specs/contracts/runtime_mcp_ia_gateway.schema.json - contrat a etendre
- DEP-003 : artifacts/cockpit/ - repertoire sortie artefacts
- DEP-004 : bash curl dig nc - outils systeme disponibles sur VPS

---

## 6. Files

- FILE-001 : artifacts/cockpit/infra_vps_inventory.json
- FILE-002 : specs/contracts/infra_vps.schema.json
- FILE-003 : tools/cockpit/infra_vps_healthcheck.sh
- FILE-004 : docs/INFRA_VPS_RUNBOOK_2026.md
- FILE-005 : docs/evidence/infra_sec_audit_2026-03-29.md
- FILE-006 : tools/cockpit/runtime_ai_gateway.sh (modification)
- FILE-007 : specs/contracts/runtime_mcp_ia_gateway.schema.json (modification)
- FILE-008 : RUNBOOK.md (amendement)

---

## 7. Testing

- TEST-001 : infra_vps_healthcheck.sh retourne JSON valide status ok pour services actifs
- TEST-002 : --service rag.saillant.cc retourne resultat cible coherent
- TEST-003 : infra_vps.schema.json valide infra_vps_inventory.json sans erreur
- TEST-004 : runtime_ai_gateway.sh --json inclut infra_vps_status sans casser champs existants
- TEST-005 : curl rag.saillant.cc sans token retourne 401 ou 403 (SEC-001)
- TEST-006 : curl browser.saillant.cc sans auth retourne 401 ou 403 (SEC-002)

---

## 8. Risks and Assumptions

- RISK-001 : Services clems hors docker-compose electron - healthcheck resilient si socket Docker inaccessible
- RISK-002 : browser.saillant.cc surface SSRF si URL de navigation non validee cote backend
- RISK-003 : api-proxy sans container/host - risque configuration fantome orphelin Traefik
- ASSUMPTION-001 : Le VPS dispose de curl dig nc installes nativement
- ASSUMPTION-002 : Traefik gere TLS pour *.saillant.cc via Let Encrypt
- ASSUMPTION-003 : L'utilisateur clems a ses containers Docker non partages avec electron

---

## 9. Related Specifications

- specs/contracts/runtime_mcp_ia_gateway.schema.json
- docs/plans/18_plan_enchainement_autonome_des_lots_utiles.md
- RUNBOOK.md
- tools/cockpit/runtime_ai_gateway.sh
