#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path

from kill_life.agent_catalog import canonical_agent_ids


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PATH = REPO_ROOT / "tools" / "autonomous_next_lots.py"
CANONICAL_AGENT_IDS = set(canonical_agent_ids())


def load_module():
    spec = importlib.util.spec_from_file_location("autonomous_next_lots", SCRIPT_PATH)
    module = importlib.util.module_from_spec(spec)
    assert spec is not None and spec.loader is not None
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


AUTONOMOUS_NEXT_LOTS = load_module()


class AutonomousNextLotsCatalogTests(unittest.TestCase):
    def test_all_declared_lot_owners_are_canonical(self) -> None:
        self.assertGreaterEqual(len(AUTONOMOUS_NEXT_LOTS.LOTS), 1)
        for lot in AUTONOMOUS_NEXT_LOTS.LOTS:
            with self.subTest(lot=lot.key):
                self.assertIn(lot.owner_agent, CANONICAL_AGENT_IDS)


if __name__ == "__main__":
    unittest.main()
