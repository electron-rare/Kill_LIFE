# Evidence - Infra Security Audit 2026-03-29

## Scope

- T-INF-008: Audit auth rag.saillant.cc (RAGFlow)
- T-INF-009: Audit auth and allowlist browser.saillant.cc (Browser Use)
- T-INF-010: Check network isolation signals for clems services

Generated from: artifacts/cockpit/infra_vps_security_audit_latest.json
Timestamp (UTC): 2026-03-29T02:44:42.183830+00:00

## Raw Findings

### rag.saillant.cc (RAGFlow)
- HTTP HEAD status: 502
- Conclusion: auth behavior (401/403) cannot be validated while upstream returns 502.
- Port probe: 80=open, 443=open, 2375=closed, 2376=closed, 3000=closed, 8080=open

### browser.saillant.cc (Browser Use)
- HTTP HEAD status: 200
- Conclusion: endpoint appears reachable without explicit auth challenge at entrypoint.
- Port probe: 80=open, 443=open, 2375=closed, 2376=closed, 3000=closed, 8080=open

## Security Assessment

- T-INF-008: BLOCKED (service returns 502, auth policy not testable in current state)
- T-INF-009: DEGRADED (public 200 observed, enforce explicit auth gate and allowlist checks)
- T-INF-010: PARTIAL (sensitive Docker ports 2375/2376 are closed externally; full container isolation requires host-level verification on VPS)

## Required Remediation

1. Restore RAGFlow upstream to return application responses, then retest unauthenticated behavior expecting 401/403.
2. Enforce authentication at Browser Use edge (reverse proxy/app middleware) and verify unauthenticated requests return 401/403.
3. Validate Browser Use URL allowlist in backend logic and record allowed patterns.
4. Run host-level isolation checks on VPS: container network mappings, cross-user bridge visibility, and exposed interfaces.

## Repro Commands

```bash
curl -k -I --max-time 12 https://rag.saillant.cc
curl -k -I --max-time 12 https://browser.saillant.cc
nc -z -w 2 rag.saillant.cc 2375; echo $?
nc -z -w 2 browser.saillant.cc 2376; echo $?
```

## Evidence Files

- artifacts/cockpit/infra_vps_security_audit_latest.json
- docs/evidence/infra_sec_audit_2026-03-29.md