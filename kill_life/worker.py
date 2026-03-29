"""Kill_LIFE background worker — polls mascarade-core for pending tasks.

Polls the Mascarade task queue and dispatches agent execution requests
to the local Kill_LIFE API. Gracefully degrades when Mascarade is
unreachable (logs and retries).
"""

from __future__ import annotations

import asyncio
import logging
import os
import signal
import sys

import httpx

logging.basicConfig(level=logging.INFO, format="%(asctime)s [kill-life-worker] %(message)s")
log = logging.getLogger(__name__)

MASCARADE_CORE_URL = os.environ.get("MASCARADE_CORE_URL", "http://localhost:8100")
KILL_LIFE_API_URL = os.environ.get("KILL_LIFE_API_URL", "http://localhost:8200")
POLL_INTERVAL = int(os.environ.get("WORKER_POLL_INTERVAL", "10"))

_running = True


def _shutdown(signum, frame):
    global _running
    log.info("Received signal %s, shutting down...", signum)
    _running = False


async def poll_and_dispatch(client: httpx.AsyncClient) -> int:
    """Poll Mascarade for pending tasks and dispatch them. Returns count of tasks processed."""
    try:
        resp = await client.get(
            f"{MASCARADE_CORE_URL}/v1/api/agents/queue",
            params={"source": "kill-life"},
            timeout=10.0,
        )
        if resp.status_code == 404:
            # Endpoint not available yet — not an error
            return 0
        resp.raise_for_status()
        data = resp.json()
    except httpx.ConnectError:
        log.debug("Mascarade unreachable at %s — will retry", MASCARADE_CORE_URL)
        return 0
    except httpx.TimeoutException:
        log.debug("Mascarade poll timed out")
        return 0
    except Exception as exc:
        log.warning("Poll error: %s", exc)
        return 0

    tasks = data.get("tasks", [])
    if not tasks:
        return 0

    processed = 0
    for task in tasks:
        agent_name = task.get("agent")
        task_input = task.get("input", "")
        task_id = task.get("id", "unknown")

        if not agent_name:
            log.warning("Task %s has no agent name, skipping", task_id)
            continue

        log.info("Dispatching task %s → agent %s", task_id, agent_name)
        try:
            run_resp = await client.post(
                f"{KILL_LIFE_API_URL}/agents/{agent_name}/run",
                json={"input": task_input, "context": task.get("context")},
                timeout=60.0,
            )
            if run_resp.is_success:
                log.info("Task %s completed (agent=%s)", task_id, agent_name)
                processed += 1
            else:
                log.warning("Task %s failed: %s %s", task_id, run_resp.status_code, run_resp.text[:200])
        except Exception as exc:
            log.warning("Task %s dispatch error: %s", task_id, exc)

    return processed


async def main():
    signal.signal(signal.SIGTERM, _shutdown)
    signal.signal(signal.SIGINT, _shutdown)

    log.info("Kill_LIFE worker started")
    log.info("  MASCARADE_CORE_URL: %s", MASCARADE_CORE_URL)
    log.info("  KILL_LIFE_API_URL:  %s", KILL_LIFE_API_URL)
    log.info("  POLL_INTERVAL:      %ds", POLL_INTERVAL)

    async with httpx.AsyncClient() as client:
        while _running:
            count = await poll_and_dispatch(client)
            if count:
                log.info("Processed %d task(s) this cycle", count)
            await asyncio.sleep(POLL_INTERVAL)

    log.info("Worker stopped.")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        sys.exit(0)
