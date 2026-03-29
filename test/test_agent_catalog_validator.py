#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
VALIDATOR_PATH = REPO_ROOT / "tools" / "specs" / "validate_agent_catalog.py"
CATALOG_PATH = REPO_ROOT / "specs" / "contracts" / "kill_life_agent_catalog.json"


def load_validator():
    spec = importlib.util.spec_from_file_location("validate_agent_catalog", VALIDATOR_PATH)
    module = importlib.util.module_from_spec(spec)
    assert spec is not None and spec.loader is not None
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


VALIDATOR = load_validator()
CATALOG = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))


class AgentCatalogValidatorTests(unittest.TestCase):
    def build_temp_repo(self) -> Path:
        temp_root = Path(tempfile.mkdtemp(prefix="kill-life-agent-catalog-"))
        shutil.copytree(REPO_ROOT / "specs" / "contracts", temp_root / "specs" / "contracts")

        for rel_path in (
            "README.md",
            "README_FR.md",
            "docs/plans/12_plan_gestion_des_agents.md",
            "docs/AGENT_SPEC_MODULE_MATRIX_2026-03-20.md",
            "tools/autonomous_next_lots.py",
            "tools/cad/yiacad_fusion_lot.sh",
            "tools/cockpit/intelligence_tui.sh",
            "tools/cockpit/runtime_ai_gateway.sh",
        ):
            source = REPO_ROOT / rel_path
            destination = temp_root / rel_path
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)

        for agent in CATALOG["agents"]:
            for rel_path in (
                agent["agent_doc"],
                agent["github_agent_doc"],
                agent["start_prompt"],
                agent["plan_wizard_prompt"],
            ):
                source = REPO_ROOT / rel_path
                destination = temp_root / rel_path
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, destination)

        return temp_root

    def validate_temp_repo(self, repo_root: Path) -> dict:
        return VALIDATOR.validate_agent_catalog(
            repo_root=repo_root,
            catalog_path=repo_root / "specs" / "contracts" / "kill_life_agent_catalog.json",
        )

    def test_missing_prompt_is_reported(self) -> None:
        repo_root = self.build_temp_repo()
        try:
            (repo_root / ".github" / "prompts" / "start_pm_mesh.prompt.md").unlink()
            payload = self.validate_temp_repo(repo_root)
        finally:
            shutil.rmtree(repo_root)

        self.assertFalse(payload["ok"])
        self.assertIn("catalog-missing-files", payload["errors"])
        self.assertIn(".github/prompts/start_pm_mesh.prompt.md", payload["missing_files"])

    def test_missing_agent_doc_is_reported(self) -> None:
        repo_root = self.build_temp_repo()
        try:
            (repo_root / "agents" / "pm_mesh.md").unlink()
            payload = self.validate_temp_repo(repo_root)
        finally:
            shutil.rmtree(repo_root)

        self.assertFalse(payload["ok"])
        self.assertIn("catalog-missing-files", payload["errors"])
        self.assertIn("agents/pm_mesh.md", payload["missing_files"])

    def test_readme_drift_is_reported(self) -> None:
        repo_root = self.build_temp_repo()
        try:
            readme = repo_root / "README.md"
            readme.write_text(readme.read_text(encoding="utf-8").replace("KillLife-Bridge", "KillLifeBridge", 1), encoding="utf-8")
            payload = self.validate_temp_repo(repo_root)
        finally:
            shutil.rmtree(repo_root)

        self.assertFalse(payload["ok"])
        self.assertIn("catalog-doc-drift", payload["errors"])
        self.assertTrue(any(item["path"] == "README.md" for item in payload["docs_missing_agents"]))

    def test_matrix_drift_is_reported(self) -> None:
        repo_root = self.build_temp_repo()
        try:
            matrix = repo_root / "docs" / "AGENT_SPEC_MODULE_MATRIX_2026-03-20.md"
            matrix.write_text(matrix.read_text(encoding="utf-8").replace("Schema-Guard", "SchemaGuard"), encoding="utf-8")
            payload = self.validate_temp_repo(repo_root)
        finally:
            shutil.rmtree(repo_root)

        self.assertFalse(payload["ok"])
        self.assertIn("catalog-doc-drift", payload["errors"])
        self.assertTrue(
            any(item["path"] == "docs/AGENT_SPEC_MODULE_MATRIX_2026-03-20.md" for item in payload["docs_missing_agents"])
        )

    def test_invalid_owner_agent_is_reported(self) -> None:
        repo_root = self.build_temp_repo()
        try:
            registry_path = repo_root / "specs" / "contracts" / "ops_kill_life_erp_registry.json"
            registry = json.loads(registry_path.read_text(encoding="utf-8"))
            registry["layers"][0]["owner_agent"] = "Not-A-Real-Agent"
            registry_path.write_text(json.dumps(registry, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
            payload = self.validate_temp_repo(repo_root)
        finally:
            shutil.rmtree(repo_root)

        self.assertFalse(payload["ok"])
        self.assertIn("catalog-invalid-owner-agent", payload["errors"])
        self.assertTrue(any(item["owner_agent"] == "Not-A-Real-Agent" for item in payload["invalid_owner_refs"]))

    def test_new_catalog_agent_requires_matching_files(self) -> None:
        repo_root = self.build_temp_repo()
        try:
            catalog_path = repo_root / "specs" / "contracts" / "kill_life_agent_catalog.json"
            catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
            extra_agent = dict(catalog["agents"][0])
            extra_agent.update(
                {
                    "id": "Ops-Preview",
                    "slug": "ops_preview",
                    "display_name": "Ops Preview",
                    "agent_doc": "agents/ops_preview.md",
                    "github_agent_doc": ".github/agents/ops_preview.md",
                    "start_prompt": ".github/prompts/start_ops_preview.prompt.md",
                    "plan_wizard_prompt": ".github/prompts/plan_wizard_ops_preview.prompt.md",
                }
            )
            catalog["agents"].append(extra_agent)
            catalog_path.write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
            payload = self.validate_temp_repo(repo_root)
        finally:
            shutil.rmtree(repo_root)

        self.assertFalse(payload["ok"])
        self.assertIn("catalog-missing-files", payload["errors"])
        self.assertIn("agents/ops_preview.md", payload["missing_files"])
        self.assertIn(".github/agents/ops_preview.md", payload["missing_files"])
        self.assertIn(".github/prompts/start_ops_preview.prompt.md", payload["missing_files"])
        self.assertIn(".github/prompts/plan_wizard_ops_preview.prompt.md", payload["missing_files"])


if __name__ == "__main__":
    unittest.main()
