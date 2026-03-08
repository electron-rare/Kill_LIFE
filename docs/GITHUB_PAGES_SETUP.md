# GitHub Pages Posture

GitHub Pages is not a canonical release surface for `Crazy Lane`.

Current contract:
- `crazy_life` owns the canonical web/devops release path.
- `Kill_LIFE` keeps runtime, workflow JSON, evidence, firmware, CAD and compliance as source of truth.
- Any Pages publication in `Kill_LIFE` is secondary and should be treated as docs/evidence preview only.

## What is canonical today

- Release gate: repo-local stable CI + versioned release workflow.
- Stable CI: `.github/workflows/ci.yml`
- Versioned release: `.github/workflows/release_signing.yml`

## What Pages means here

If Pages is still enabled for `Kill_LIFE`, use it only for lightweight docs/evidence preview.
Do not use it as a proxy for:
- cockpit release readiness
- workflow editor release readiness
- runtime release gating

## Legacy note

The repository still contains more than one historical Pages workflow shape.
Until one of them is explicitly simplified or removed, treat Pages as non-blocking
and secondary to the canonical CI/release path above.
