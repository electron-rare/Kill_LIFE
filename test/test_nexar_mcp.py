#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import selectors
import signal
import subprocess
import time
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / 'tools' / 'run_nexar_mcp.sh'
PROTOCOL_VERSION = '2025-03-26'


def send_message(proc: subprocess.Popen[str], payload: dict) -> None:
    body = json.dumps(payload)
    proc.stdin.write(body + "\n")
    proc.stdin.flush()


def read_message(proc: subprocess.Popen[str], timeout: float = 10.0) -> dict:
    selector = selectors.DefaultSelector()
    selector.register(proc.stdout, selectors.EVENT_READ)
    deadline = time.monotonic() + timeout
    try:
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise AssertionError('timed out waiting for nexar response')
            if not selector.select(remaining):
                raise AssertionError('timed out waiting for nexar response')
            line = proc.stdout.readline()
            if not line:
                stderr = proc.stderr.read().strip() if proc.stderr else ''
                raise AssertionError(f'unexpected EOF while reading nexar response: {stderr}')
            line = line.strip()
            if not line:
                continue
            return json.loads(line)
    finally:
        selector.close()


def terminate(proc: subprocess.Popen[str]) -> None:
    if proc.poll() is None:
        try:
            os.killpg(proc.pid, signal.SIGTERM)
        except Exception:
            proc.terminate()
        proc.wait(timeout=5)
    for handle in (proc.stdin, proc.stdout, proc.stderr):
        if handle:
            handle.close()


class NexarMcpTests(unittest.TestCase):
    def test_server_supports_initialize_tools_list_and_demo_search(self):
        env = os.environ.copy()
        env.pop('NEXAR_TOKEN', None)
        env.pop('NEXAR_API_KEY', None)
        proc = subprocess.Popen(
            ['bash', str(SCRIPT)],
            cwd=REPO_ROOT,
            env=env,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            start_new_session=True,
        )
        try:
            send_message(
                proc,
                {
                    'jsonrpc': '2.0',
                    'id': 1,
                    'method': 'initialize',
                    'params': {
                        'protocolVersion': PROTOCOL_VERSION,
                        'capabilities': {},
                        'clientInfo': {'name': 'test', 'version': '1.0.0'},
                    },
                },
            )
            initialize = read_message(proc)
            self.assertEqual(initialize['result']['serverInfo']['name'], 'nexar-api')
            self.assertEqual(initialize['result']['protocolVersion'], PROTOCOL_VERSION)

            send_message(proc, {'jsonrpc': '2.0', 'id': 2, 'method': 'tools/list', 'params': {}})
            tools_list = read_message(proc)
            self.assertGreaterEqual(len(tools_list['result']['tools']), 4)

            send_message(
                proc,
                {
                    'jsonrpc': '2.0',
                    'id': 3,
                    'method': 'tools/call',
                    'params': {
                        'name': 'search_parts',
                        'arguments': {'query': 'STM32', 'limit': 2},
                    },
                },
            )
            search = read_message(proc)
            result = search['result']
            self.assertFalse(result['isError'])
            self.assertTrue(result['_meta']['parts'])
            self.assertTrue(result['_meta']['demo_mode'])
        finally:
            terminate(proc)


if __name__ == '__main__':
    unittest.main()
