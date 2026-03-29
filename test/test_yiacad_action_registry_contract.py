#!/usr/bin/env python3
from __future__ import annotations

import unittest

from kill_life.yiacad_action_registry import (
    INPUT_ARGUMENTS,
    load_yiacad_action_registry,
    yiacad_actions,
    yiacad_actions_for_surface,
)


class YiacadActionRegistryContractTests(unittest.TestCase):
    def test_registry_is_machine_readable_and_unique(self) -> None:
        payload = load_yiacad_action_registry()
        self.assertEqual(payload["contract_version"], "yiacad-action-registry/v1")
        self.assertEqual(payload["component"], "yiacad-action-registry")
        actions = yiacad_actions()
        commands = [entry["transport_command"] for entry in actions]
        action_ids = [entry["action_id"] for entry in actions]
        self.assertEqual(len(commands), len(set(commands)))
        self.assertEqual(len(action_ids), len(set(action_ids)))
        for entry in actions:
            for input_name in entry["accepted_inputs"]:
                self.assertIn(input_name, INPUT_ARGUMENTS)

    def test_surface_views_cover_kicad_and_freecad(self) -> None:
        kicad_commands = {
            entry["transport_command"] for entry in yiacad_actions_for_surface("yiacad-kicad")
        }
        freecad_commands = {
            entry["transport_command"] for entry in yiacad_actions_for_surface("yiacad-freecad")
        }
        self.assertTrue({"status", "kicad-erc-drc", "bom-review", "ecad-mcad-sync"}.issubset(kicad_commands))
        self.assertTrue({"status", "ecad-mcad-sync", "manufacturing-package", "kiauto-checks"}.issubset(freecad_commands))


if __name__ == "__main__":
    unittest.main()
