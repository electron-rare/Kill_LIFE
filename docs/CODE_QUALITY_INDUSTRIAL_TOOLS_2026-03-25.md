# Code Quality Report: Industrial Tools
> Date: 2026-03-25
> Scope: `tools/industrial/bom_analyzer.py`, `tools/industrial/opcua_mcp.py`, `tools/industrial/mqtt_mcp.py`, `tools/industrial/nodered_connector.py`, `tools/apify_mcp.py`

## Summary Table

| File | Lines | Issues | Critical | High | Medium | Low |
|------|-------|--------|----------|------|--------|-----|
| `tools/industrial/bom_analyzer.py` | 940 | 3 | 0 | 0 | 1 | 2 |
| `tools/industrial/opcua_mcp.py` | 329 | 2 | 0 | 0 | 1 | 1 |
| `tools/industrial/mqtt_mcp.py` | 388 | 2 | 0 | 0 | 1 | 1 |
| `tools/industrial/nodered_connector.py` | 315 | 2 | 0 | 1 | 0 | 1 |
| `tools/apify_mcp.py` | 374 | 4 | 1 | 1 | 1 | 1 |
| **Total** | **2346** | **13** | **1** | **2** | **4** | **6** |

## Fixes Applied

Three bugs were fixed directly in the codebase:

1. **CRITICAL** `tools/apify_mcp.py` line 284 -- `monitor_updates` used Python's built-in `hash()` for content change detection. `hash()` is randomized across process restarts (PYTHONHASHSEED), so every server restart would report every monitored URL as "changed". Replaced with `hashlib.md5().hexdigest()` for deterministic hashing.

2. **HIGH** `tools/apify_mcp.py` line 310 -- File handle leak: `sum(1 for _ in open(dataset_file))` opens a file without closing it. Wrapped in `with` statement.

3. **HIGH** `tools/industrial/nodered_connector.py` line 266 -- `int(self.headers.get("Content-Length", 0))` would raise `ValueError` on malformed headers (e.g. `Content-Length: chunked` or empty string). Wrapped in try/except.

---

## Detailed Findings

### `tools/industrial/bom_analyzer.py` (940 lines)

**Architecture:** CLI tool with argparse, CSV parsing, LCSC knowledge base, DFM checking, report generation. Well-structured, comprehensive.

| # | Severity | Category | Description |
|---|----------|----------|-------------|
| 1 | Medium | Dead code | `detect_delimiter()` lines 210-213: `for delim in [",", ";", "\t"]: ... pass` loop body is empty. The loop iterates but does nothing before falling through to `csv.Sniffer`. Appears to be leftover scaffolding for a heuristic that was never implemented. |
| 2 | Low | Style | `Optional` import from `typing` (line 30) is never used. All optional types use `X \| None` syntax. |
| 3 | Low | Fragility | `generate_report()` hardcodes date `2026-03-25` (line 771). Should use `datetime.date.today()` or accept a parameter. |

**Positives:** Good use of dataclasses, clean CLI with subcommands, solid CSV parsing with multi-EDA column normalization, LCSC price API with proper error handling, thorough DFM checking.

---

### `tools/industrial/opcua_mcp.py` (329 lines)

**Architecture:** MCP stdio server for OPC-UA. Clean separation between asyncua-backed implementation and stub fallback.

| # | Severity | Category | Description |
|---|----------|----------|-------------|
| 1 | Medium | Security | `opcua_write` tool allows writing arbitrary values to OPC-UA nodes with no confirmation or allowlist. The description says "use with caution" but there is no programmatic safeguard. Consider adding an env-var opt-in like `OPCUA_WRITE_ENABLED=1`. |
| 2 | Low | Unused import | `sys` (line 9) is imported but never used. |

**Positives:** Proper depth/breadth limiting on browse, subscription duration capped at 30s, clean fallback stubs, good JSON serialization of OPC-UA types.

---

### `tools/industrial/mqtt_mcp.py` (388 lines)

**Architecture:** MCP stdio server for MQTT. Uses paho-mqtt with threading for connect/subscribe, asyncio sleep for duration control.

| # | Severity | Category | Description |
|---|----------|----------|-------------|
| 1 | Medium | Security | `mqtt_publish` allows publishing to any topic with no allowlist or confirmation. Same concern as OPC-UA write -- an env-var gate (`MQTT_PUBLISH_ENABLED`) would add a safety layer for production brokers. |
| 2 | Low | Unused import | `sys` (line 9) is imported but never used. |

**Positives:** Proper broker string parsing with port fallback, buffer size limits, retained message fetching in history, duration caps on subscriptions.

---

### `tools/industrial/nodered_connector.py` (315 lines)

**Architecture:** HTTP bridge between Node-RED and Mascarade. Supports aiohttp (async) and stdlib fallback. Clean msg format translation.

| # | Severity | Category | Description |
|---|----------|----------|-------------|
| 1 | High | Bug | **FIXED.** `Content-Length` parsing in stdlib fallback server could crash on malformed headers. |
| 2 | Low | Robustness | Stdlib fallback `do_POST` (line 278) calls `asyncio.run()` per request, which creates a new event loop each time. This works but is inefficient under load. The aiohttp path does not have this issue. |

**Positives:** Dual-mode server (aiohttp + stdlib), clean Node-RED msg format helpers, batch message support, graceful httpx fallback to stub mode.

---

### `tools/apify_mcp.py` (374 lines)

**Architecture:** MCP stdio server for web scraping via Apify actors with direct-scrape fallback. Includes dataset feeding for Mascarade training.

| # | Severity | Category | Description |
|---|----------|----------|-------------|
| 1 | Critical | Bug | **FIXED.** `monitor_updates` used `hash()` for change detection. Python's `hash()` is non-deterministic across restarts, causing false positives on every restart. |
| 2 | High | Bug | **FIXED.** `handle_feed_dataset` leaked file handle when counting lines. |
| 3 | Medium | Security | `_run_actor()` (line 85) embeds `APIFY_API_TOKEN` in URL query string: `?token={APIFY_TOKEN}`. If an exception includes the URL (which httpx does by default), the token leaks into error responses sent back via MCP. Consider using an `Authorization` header instead. |
| 4 | Low | Unused import | `sys` (line 10) is imported but never used. |

**Positives:** Good fallback chain (Apify -> direct scrape -> urllib), HTML stripping for text extraction, StackExchange API integration, JSONL dataset output format.

---

## Recommendations

### Immediate (no-effort)
- Remove unused `sys` imports from `opcua_mcp.py`, `mqtt_mcp.py`, and `apify_mcp.py`
- Remove unused `Optional` import from `bom_analyzer.py`
- Remove dead `for delim in ...` loop in `bom_analyzer.py:detect_delimiter()`

### Short-term (low-effort, high-value)
- Add `OPCUA_WRITE_ENABLED` and `MQTT_PUBLISH_ENABLED` env-var gates to prevent accidental writes on production systems
- Move Apify token from URL query parameter to `Authorization: Bearer` header
- Replace hardcoded date in `bom_analyzer.py` report with `datetime.date.today()`

### Medium-term
- Add input URL validation in `apify_mcp.py` scraping tools (reject non-http(s) URLs, private IPs)
- Add rate limiting to MQTT wildcard topic discovery (`#` subscribe) to avoid flooding
- Consider adding a `--dry-run` flag to `bom_analyzer.py suggest` for CI pipelines
