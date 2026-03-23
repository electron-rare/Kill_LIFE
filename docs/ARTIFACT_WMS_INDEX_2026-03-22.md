# Artifact WMS Index

Date: 2026-03-22
Status: baseline WMS index
Scope: index `artifacts/` by lot, consumer layer, owner agent, and purpose

## 1. Objective

The `WMS` layer in `Kill_LIFE` already stores many useful artifacts, but retrieval is still uneven.

This index closes the minimum gap:

- map `artifact -> lot -> consumer layer -> owner agent`
- expose one TUI surface for summary and retrieval
- make unknown artifacts visible instead of silently ignored

## 2. Canonical files

Structured rules:
- [artifact_wms_index_rules.json](/Users/electron/Documents/Lelectron_rare/Kill_LIFE/specs/contracts/artifact_wms_index_rules.json)

Operator TUI:
- [artifact_wms_index_tui.sh](/Users/electron/Documents/Lelectron_rare/Kill_LIFE/tools/cockpit/artifact_wms_index_tui.sh)

## 3. Supported views

- `summary`
- `entries`
- `unknown`

Examples:

```bash
bash tools/cockpit/artifact_wms_index_tui.sh --action summary
bash tools/cockpit/artifact_wms_index_tui.sh --action entries --json
bash tools/cockpit/artifact_wms_index_tui.sh --action unknown --json
```

## 4. Reading

The index is intentionally pragmatic:

- it scans `latest*` artifacts under `artifacts/`
- it applies explicit keyword-based rules from the contract
- unmatched artifacts are exposed as `unknown`

This is enough to close the immediate `WMS` gap without introducing a heavy metadata service.

## 5. Current classification model

Examples of classified artifact families:

- `product_contract_*` -> `MES`
- `kill_life_memory` -> `MES`
- `daily_operator_summary` -> `MES`
- `mascarade_incident_*` -> `WMS`
- `mascarade_watch_*` -> `WMS`
- `mascarade_runtime_health` -> `DCS`
- `dataset_*` -> `WMS`
- `repo_state` / `specs` -> `PLM`
- `operator_lane` -> `MES`

## 6. Why this closes the layer gap

Before this index:

- artifacts existed
- latest outputs existed
- handoff files existed
- but there was no direct machine-readable map from artifact to lot family and consumer

After this index:

- `WMS` has a contract
- `WMS` has a TUI surface
- `unknown` artifacts become visible technical debt instead of silent drift

## 7. Next step

Best next step:

- branch this index into the main cockpit entrypoint
- then reduce `unknown` artifact groups until the index becomes the practical source of truth for `WMS`
