# YiACAD operator log contract - 2026-03-21

## Canonical entries
- Operator index: `bash tools/cockpit/yiacad_operator_index.sh --action status`
- Logs lane: `bash tools/cockpit/yiacad_logs_tui.sh --action status`
- Proofs lane: `bash tools/cockpit/yiacad_proofs_tui.sh --action status`

## Log sources
- `artifacts/yiacad_operator_index`
- `artifacts/yiacad_uiux_tui`
- `artifacts/yiacad_backend_service_tui`
- `artifacts/yiacad_proofs_tui`
- `artifacts/cad-ai-native/service`

## Actions
- `bash tools/cockpit/yiacad_logs_tui.sh --action summary`
- `bash tools/cockpit/yiacad_logs_tui.sh --action list`
- `bash tools/cockpit/yiacad_logs_tui.sh --action latest`
- `bash tools/cockpit/yiacad_logs_tui.sh --action purge-logs --days 14 --yes`

## Intent
- Keep one public entry for operators.
- Separate logs and proofs into dedicated surfaces.
- Preserve historical aliases until the next cleanup lot.
