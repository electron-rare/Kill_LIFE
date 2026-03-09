# 18) TODO enchainement autonome des lots utiles

Last updated: 2026-03-09 06:06:59

Ce fichier est regenere localement par `tools/autonomous_next_lots.py`.

## `mcp-runtime` — Alignement MCP runtime local

- done: lot detecte (Stabiliser les launchers MCP, le bootstrap Mac, la resolution du repo compagnon et la doc operateur associee.)
- done: `bash tools/bootstrap_mac_mcp.sh codex`
  resume: codex mcp add openscad --env MASCARADE_DIR=/Users/electron/mascarade-main -- bash /Users/electron/Kill_LIFE/tools/run_openscad_mcp.sh | codex mcp add huggingface --url https://huggingface.co/mcp --bearer-token-env-var HUGGINGFACE_API_KEY | codex mcp add playwright -- npx -y @playwright/mcp@latest
- done: `bash tools/bootstrap_mac_mcp.sh json`
  resume:     } |   } | }
- done: `.venv/bin/python tools/validate_specs_mcp_smoke.py --json --quick`
  resume: {"status": "ready", "protocol_version": "2025-03-26", "server_name": "validate-specs", "tool_count": 2, "checks": ["initialize", "tools/list"], "error": null}
- advisory: `.venv/bin/python tools/knowledge_base_mcp_smoke.py --json --quick`
  resume: {"status": "degraded", "protocol_version": "2025-03-26", "server_name": "knowledge-base", "provider": "memos", "tool_count": 4, "checks": ["initialize", "tools/list"], "secret_configured": false, "live_validation": "missing_secret", "error": "memos auth missing"}
- advisory: `.venv/bin/python tools/github_dispatch_mcp_smoke.py --json --quick`
  resume: {"status": "degraded", "protocol_version": "2025-03-26", "server_name": "github-dispatch", "tool_count": 3, "checks": ["initialize", "tools/list"], "token_configured": false, "live_requested": false, "live_validation": "missing_secret", "error": "GitHub dispatch auth missing"}

## `cad-mcp-host` — Runtime CAD host-first

- done: lot detecte (Qualifier KiCad, FreeCAD et OpenSCAD en host-first sur macOS tout en gardant le fallback conteneur operable.)
- done: `bash tools/hw/run_kicad_mcp.sh --doctor`
  resume: KICAD_PYTHON_STDERR_LOG_LEVEL=WARNING | REQUESTED_RUNTIME=auto | SELECTED_RUNTIME=host
- done: `bash tools/hw/cad_stack.sh doctor`
  resume: 1.0.2 | PlatformIO Core, version 6.1.19 | OpenSCAD version 2021.01
- done: `.venv/bin/python tools/freecad_mcp_smoke.py --quick --json`
  resume: {"status": "ready", "protocol_version": "2025-03-26", "server_name": "freecad", "tool_count": 4, "checks": ["initialize", "tools/list", "get_runtime_info"], "error": null}
- done: `.venv/bin/python tools/openscad_mcp_smoke.py --quick --json`
  resume: {"status": "ready", "protocol_version": "2025-03-26", "server_name": "openscad", "tool_count": 4, "checks": ["initialize", "tools/list", "get_runtime_info"], "error": null}

## `python-local` — Execution Python repo-locale

- done: lot detecte (Garder les scripts et smokes sur l'interpreteur repo-local plutot que sur le Python systeme.)
- done: `bash tools/test_python.sh --venv-dir .venv --suite stable`
  resume: ---------------------------------------------------------------------- | Ran 3 tests in 0.014s | OK

