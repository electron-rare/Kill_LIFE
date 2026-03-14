# MCP Runtime Status Alignment — 2026-03-14

## Scope

Close `K-DA-020` by replaying `bash tools/test_python.sh --suite stable` and isolating the first real failure around the MCP runtime stack.

## Finding

The first red was not a runtime regression in `tools/mcp_runtime_status.py`.

It was a test harness mismatch:

- `tools/mcp_runtime_status.run_check(...)` is now async and uses `asyncio.create_subprocess_exec(...)`
- `test/test_mcp_runtime_status.py` was still mocking the legacy synchronous surface `subprocess.run(...)`

Failure observed before the fix:

- `AttributeError: module 'tools.mcp_runtime_status' has no attribute 'subprocess'`

## Fix

`test/test_mcp_runtime_status.py` now matches the real async contract:

- patch `tools.mcp_runtime_status.asyncio.create_subprocess_exec`
- use an async fake process with `communicate()`
- call `asyncio.run(run_check(spec))`

## Validation

Stable suite replay:

- `bash tools/test_python.sh --suite stable`

Result:

- green

No runtime code was changed in this lot. The closure is a test-alignment closure, not a behavior change in the MCP runtime itself.
