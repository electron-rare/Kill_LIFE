#!/usr/bin/env python3
"""Detect, validate, and document the next useful local lots."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from dataclasses import field

ROOT = Path(__file__).resolve().parents[1]
PLAN_DOC = ROOT / "docs" / "plans" / "18_plan_enchainement_autonome_des_lots_utiles.md"
TODO_DOC = ROOT / "docs" / "plans" / "18_todo_enchainement_autonome_des_lots_utiles.md"
INTELLIGENCE_MEMORY_JSON = ROOT / "artifacts" / "cockpit" / "intelligence_program" / "latest.json"

NOISE_PATHS: tuple[str, ...] = (
    "docs/plans/18_plan_enchainement_autonome_des_lots_utiles.md",
    "docs/plans/18_todo_enchainement_autonome_des_lots_utiles.md",
)
NOISE_PREFIXES: tuple[str, ...] = (
    "artifacts/",
    ".venv/",
    ".mypy_cache/",
    ".ruff_cache/",
)


@dataclass(frozen=True)
class Validation:
    name: str
    cmd: tuple[str, ...]
    required: bool = True


@dataclass(frozen=True)
class Lot:
    key: str
    title: str
    description: str
    priority: int
    paths: tuple[str, ...]
    plan_refs: tuple[str, ...]
    owner_repo: str
    owner_agent: str
    handoff_write_set: tuple[str, ...]
    validations: tuple[Validation, ...]
    owner_subagent: str | None = None
    owner_team: str = "PM"
    dependencies: tuple[str, ...] = field(default_factory=tuple)
    rollback_plan: tuple[str, ...] = field(default_factory=tuple)


LOTS: tuple[Lot, ...] = (
    Lot(
        key="zeroclaw-integrations",
        title="Runtime local ZeroClaw / n8n",
        description=(
            "Fermer la lane d'integrations locales ZeroClaw/n8n, les evidences "
            "I-205 associees, puis resynchroniser les plans versionnes "
            "d'enchainement autonome et le cockpit local."
        ),
        priority=5,
        paths=(
            "specs/03_plan.md",
            "specs/04_tasks.md",
            "specs/README.md",
            "specs/mcp_tasks.md",
            "specs/zeroclaw_dual_hw_todo.md",
            "ai-agentic-embedded-base/specs/03_plan.md",
            "ai-agentic-embedded-base/specs/04_tasks.md",
            "ai-agentic-embedded-base/specs/README.md",
            "ai-agentic-embedded-base/specs/mcp_tasks.md",
            "ai-agentic-embedded-base/specs/zeroclaw_dual_hw_todo.md",
            "docs/plans/18_plan_enchainement_autonome_des_lots_utiles.md",
            "docs/plans/18_todo_enchainement_autonome_des_lots_utiles.md",
            "tools/cockpit/README.md",
            "tools/cockpit/lot_chain.sh",
            "tools/ai/integrations/n8n/README.md",
            "tools/ai/integrations/n8n/kill_life_smoke_workflow.json",
            "tools/ai/zeroclaw_integrations_up.sh",
            "tools/ai/zeroclaw_integrations_status.sh",
            "tools/ai/zeroclaw_integrations_import_n8n.sh",
            "tools/ai/zeroclaw_integrations_down.sh",
            "tools/ai/zeroclaw_integrations_lot.sh",
            "tools/cockpit/run_next_lots_autonomously.sh",
        ),
        plan_refs=(
            "specs/zeroclaw_dual_hw_todo.md",
            "docs/plans/18_plan_enchainement_autonome_des_lots_utiles.md",
        ),
        owner_repo="Kill_LIFE",
        owner_agent="PM-Mesh",
        owner_team="PM",
        dependencies=(),
        rollback_plan=(
            "Revenir à la lane `zeroclaw` manuelle si le container n8n échoue de manière persistante.",
            "Rejouer `bash tools/run_autonomous_next_lots.sh run --no-write` puis arbitrer manuellement.",
        ),
        handoff_write_set=(
            "specs/zeroclaw_dual_hw_todo.md",
            "tools/cockpit/lot_chain.sh",
            "tools/cockpit/run_next_lots_autonomously.sh",
        ),
        validations=(
            Validation(
                name="zeroclaw_integrations_lot_verify",
                cmd=("bash", "tools/ai/zeroclaw_integrations_lot.sh", "verify", "--json"),
            ),
            Validation(
                name="python_stable_suite",
                cmd=("bash", "tools/test_python.sh", "--suite", "stable"),
            ),
        ),
    ),
    Lot(
        key="mesh-governance",
        title="Gouvernance mesh tri-repo",
        description=(
            "Versionner le contrat tri-repo, verrouiller les ownerships agents, "
            "et outiller le preflight de synchro continue sans ecraser le travail "
            "des autres contributeurs."
        ),
        priority=7,
        paths=(
            "README.md",
            "docs/index.md",
            "docs/REFACTOR_MANIFEST_2026-03-20.md",
            "docs/TRI_REPO_MESH_CONTRACT_2026-03-20.md",
            "docs/AGENTIC_LANDSCAPE.md",
            "docs/MACHINE_SYNC_STATUS_2026-03-20.md",
            "docs/MCP_SETUP.md",
            "docs/plans/12_plan_gestion_des_agents.md",
            "docs/plans/19_todo_mesh_tri_repo.md",
            "specs/03_plan.md",
            "specs/04_tasks.md",
            "specs/mesh_contracts.md",
            "specs/contracts/agent_handoff.schema.json",
            "specs/contracts/repo_snapshot.schema.json",
            "specs/contracts/workflow_handshake.schema.json",
            "specs/contracts/examples/agent_handoff.mesh.json",
            "specs/contracts/examples/repo_snapshot.mesh.json",
            "specs/contracts/examples/workflow_handshake.mesh.json",
            "tools/cockpit/README.md",
            "tools/cockpit/refonte_tui.sh",
            "tools/cockpit/mesh_sync_preflight.sh",
            "tools/cockpit/ssh_healthcheck.sh",
            "tools/specs/mesh_contract_check.py",
            ".github/workflows/mesh_contracts.yml",
        ),
        plan_refs=(
            "docs/TRI_REPO_MESH_CONTRACT_2026-03-20.md",
            "docs/plans/12_plan_gestion_des_agents.md",
            "specs/03_plan.md",
        ),
        owner_repo="Kill_LIFE",
        owner_agent="PM-Mesh",
        owner_team="PM",
        dependencies=("zeroclaw-integrations",),
        rollback_plan=(
            "Retirer le lot `mesh-governance` du déclenchement auto si la convergence reste bloquée.",
            "Conserver le contrat mesh en mode lecture seule et documenter la dérogation.",
        ),
        handoff_write_set=(
            "docs/TRI_REPO_MESH_CONTRACT_2026-03-20.md",
            "docs/MACHINE_SYNC_STATUS_2026-03-20.md",
            "docs/plans/19_todo_mesh_tri_repo.md",
            "tools/cockpit/mesh_sync_preflight.sh",
            "tools/cockpit/ssh_healthcheck.sh",
        ),
        validations=(
            Validation(
                name="mesh_sync_preflight",
                cmd=("bash", "tools/cockpit/mesh_sync_preflight.sh", "--json"),
            ),
            Validation(
                name="ssh_healthcheck",
                cmd=("bash", "tools/cockpit/ssh_healthcheck.sh", "--json"),
            ),
            Validation(
                name="mesh_agent_handoff_contract",
                cmd=(
                    "python3",
                    "tools/specs/mesh_contract_check.py",
                    "--schema",
                    "specs/contracts/agent_handoff.schema.json",
                    "--instance",
                    "specs/contracts/examples/agent_handoff.mesh.json",
                ),
            ),
            Validation(
                name="mesh_repo_snapshot_contract",
                cmd=(
                    "python3",
                    "tools/specs/mesh_contract_check.py",
                    "--schema",
                    "specs/contracts/repo_snapshot.schema.json",
                    "--instance",
                    "specs/contracts/examples/repo_snapshot.mesh.json",
                ),
            ),
            Validation(
                name="mesh_workflow_handshake_contract",
                cmd=(
                    "python3",
                    "tools/specs/mesh_contract_check.py",
                    "--schema",
                    "specs/contracts/workflow_handshake.schema.json",
                    "--instance",
                    "specs/contracts/examples/workflow_handshake.mesh.json",
                ),
            ),
        ),
    ),
    Lot(
        key="mcp-runtime",
        title="Alignement MCP runtime local",
        description=(
            "Stabiliser les launchers MCP, le bootstrap Mac, la resolution du repo "
            "compagnon et la doc operateur associee."
        ),
        priority=10,
        paths=(
            "docs/MCP_SETUP.md",
            "mcp.json",
            "tools/bootstrap_mac_mcp.sh",
            "tools/lib/runtime_home.sh",
            "tools/mcp_smoke_common.py",
            "tools/run_github_dispatch_mcp.sh",
            "tools/run_knowledge_base_mcp.sh",
            "tools/run_validate_specs_mcp.sh",
            "tools/validate_specs_mcp_smoke.py",
        ),
        plan_refs=(
            "docs/plans/15_plan_mcp_runtime_alignment.md",
            "docs/plans/17_plan_target_architecture_mcp_agentics_2028.md",
        ),
        owner_repo="Kill_LIFE",
        owner_agent="Runtime-Companion",
        owner_team="Architect-Firmware",
        dependencies=("zeroclaw-integrations",),
        rollback_plan=(
            "Désactiver les changements MCP introduits dans le lot et revenir à la configuration de référence.",
            "Conserver la preuve de doc dans `docs/MCP_SETUP.md` et relancer uniquement en mode validation.",
        ),
        handoff_write_set=(
            "docs/MCP_SETUP.md",
            "tools/bootstrap_mac_mcp.sh",
            "tools/lib/runtime_home.sh",
            "tools/run_github_dispatch_mcp.sh",
        ),
        validations=(
            Validation(
                name="bootstrap_codex_dry_run",
                cmd=("bash", "tools/bootstrap_mac_mcp.sh", "codex"),
            ),
            Validation(
                name="bootstrap_json_dry_run",
                cmd=("bash", "tools/bootstrap_mac_mcp.sh", "json"),
            ),
            Validation(
                name="validate_specs_mcp_smoke",
                cmd=(".venv/bin/python", "tools/validate_specs_mcp_smoke.py", "--json", "--quick"),
            ),
            Validation(
                name="knowledge_base_mcp_smoke",
                cmd=(".venv/bin/python", "tools/knowledge_base_mcp_smoke.py", "--json", "--quick"),
                required=False,
            ),
            Validation(
                name="github_dispatch_mcp_smoke",
                cmd=(".venv/bin/python", "tools/github_dispatch_mcp_smoke.py", "--json", "--quick"),
                required=False,
            ),
        ),
    ),
    Lot(
        key="cad-mcp-host",
        title="Runtime CAD host-first",
        description=(
            "Qualifier KiCad, FreeCAD et OpenSCAD en host-first sur macOS tout en "
            "gardant le fallback conteneur operable."
        ),
        priority=20,
        paths=(
            "docs/MCP_SETUP.md",
            "tools/hw/cad_stack.sh",
            "tools/hw/run_kicad_mcp.sh",
            "tools/run_freecad_mcp.sh",
            "tools/run_openscad_mcp.sh",
        ),
        plan_refs=(
            "docs/plans/16_plan_cad_modeling_stack.md",
            "docs/plans/17_plan_target_architecture_mcp_agentics_2028.md",
        ),
        owner_repo="Kill_LIFE",
        owner_agent="Embedded-CAD",
        owner_team="Architect-Firmware",
        dependencies=("mcp-runtime",),
        rollback_plan=(
            "Retour automatique au mode container-only (`tools/hw/cad_stack.sh`).",
            "Conserver les chemins explicites de script pour éviter une dérive host-first.",
        ),
        handoff_write_set=(
            "docs/MCP_SETUP.md",
            "tools/hw/cad_stack.sh",
            "tools/hw/run_kicad_mcp.sh",
        ),
        validations=(
            Validation(
                name="kicad_doctor",
                cmd=("bash", "tools/hw/run_kicad_mcp.sh", "--doctor"),
            ),
            Validation(
                name="cad_stack_doctor",
                cmd=("bash", "tools/hw/cad_stack.sh", "doctor"),
            ),
            Validation(
                name="freecad_mcp_smoke",
                cmd=(".venv/bin/python", "tools/freecad_mcp_smoke.py", "--quick", "--json"),
            ),
            Validation(
                name="openscad_mcp_smoke",
                cmd=(".venv/bin/python", "tools/openscad_mcp_smoke.py", "--quick", "--json"),
            ),
        ),
    ),
    Lot(
        key="yiacad-fusion",
        title="Fusion KiCad + FreeCAD IA-native",
        description=(
            "Mettre en place le lot YiACAD (`prepare`, `smoke`, `status`, "
            "`logs`, `clean-logs`) et la synthese operateur associee sans "
            "fusion automatique de `main`."
        ),
        priority=25,
        paths=(
            "README.md",
            "SYNTHESE_AGENTIQUE.md",
            "docs/AGENTIC_LANDSCAPE.md",
            "docs/AI_WORKFLOWS.md",
            "docs/CAD_AI_NATIVE_FORK_STRATEGY.md",
            "docs/OSS_AI_NATIVE_CAD_RESEARCH_2026-03-20.md",
            "docs/WEB_RESEARCH_OPEN_SOURCE_2026-03-20.md",
            "docs/plans/12_plan_gestion_des_agents.md",
            "docs/plans/18_plan_enchainement_autonome_des_lots_utiles.md",
            "docs/plans/18_todo_enchainement_autonome_des_lots_utiles.md",
            "docs/plans/19_todo_mesh_tri_repo.md",
            "specs/03_plan.md",
            "specs/04_tasks.md",
            "tools/cad/ai_native_forks.sh",
            "tools/cad/yiacad_fusion_lot.sh",
            "tools/cockpit/refonte_tui.sh",
            "tools/cockpit/render_weekly_refonte_summary.sh",
        ),
        plan_refs=(
            "docs/CAD_AI_NATIVE_FORK_STRATEGY.md",
            "docs/OSS_AI_NATIVE_CAD_RESEARCH_2026-03-20.md",
            "docs/plans/18_todo_enchainement_autonome_des_lots_utiles.md",
        ),
        owner_repo="Kill_LIFE",
        owner_agent="CAD-Fusion",
        owner_team="CAD-Fusion",
        dependencies=("cad-mcp-host",),
        rollback_plan=(
            "Geler la branche `kill-life-ai-native` et revenir au mode container-only (`tools/hw/cad_stack.sh`).",
            "Conserver les artefacts YiACAD (`artifacts/cad-fusion`) et la synthese hebdomadaire comme preuve.",
            "Basculer l'execution en mode `status` + `clean-logs` si le smoke bloque.",
        ),
        handoff_write_set=(
            "docs/CAD_AI_NATIVE_FORK_STRATEGY.md",
            "docs/OSS_AI_NATIVE_CAD_RESEARCH_2026-03-20.md",
            "tools/cad/ai_native_forks.sh",
            "tools/cad/yiacad_fusion_lot.sh",
            "tools/cockpit/refonte_tui.sh",
            "tools/cockpit/render_weekly_refonte_summary.sh",
        ),
        validations=(
            Validation(
                name="yiacad_prepare",
                cmd=("bash", "tools/cad/yiacad_fusion_lot.sh", "--action", "prepare"),
            ),
            Validation(
                name="yiacad_status",
                cmd=("bash", "tools/cad/yiacad_fusion_lot.sh", "--action", "status"),
            ),
            Validation(
                name="yiacad_smoke",
                cmd=("bash", "tools/cad/yiacad_fusion_lot.sh", "--action", "smoke"),
                required=False,
            ),
        ),
    ),
    Lot(
        key="python-local",
        title="Execution Python repo-locale",
        description=(
            "Garder les scripts et smokes sur l'interpreteur repo-local plutot que "
            "sur le Python systeme."
        ),
        priority=30,
        paths=(
            "tools/run_validate_specs_mcp.sh",
            "tools/validate_specs_mcp_smoke.py",
            "tools/test_python.sh",
        ),
        plan_refs=("docs/plans/15_plan_mcp_runtime_alignment.md",),
        owner_repo="Kill_LIFE",
        owner_agent="Firmware",
        owner_team="Architect-Firmware",
        dependencies=("mcp-runtime", "cad-mcp-host"),
        rollback_plan=(
            "Revenir à l'exécution Python système si la venv locale est instable.",
            "Limiter les changements au lot `tools/test_python.sh` jusqu'à stabilisation.",
        ),
        handoff_write_set=(
            "tools/test_python.sh",
            "tools/run_validate_specs_mcp.sh",
            "tools/validate_specs_mcp_smoke.py",
        ),
        validations=(
            Validation(
                name="python_stable_suite",
                cmd=("bash", "tools/test_python.sh", "--venv-dir", ".venv", "--suite", "stable"),
            ),
        ),
    ),
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("status", "run", "json"), nargs="?", default="status")
    parser.add_argument("--max-lots", type=int, default=0, help="Limit execution to the first N detected lots.")
    parser.add_argument(
        "--include-noise",
        action="store_true",
        help="Include generated artifacts and lane docs in dirty-path detection.",
    )
    parser.add_argument(
        "--no-write",
        action="store_true",
        help="Do not rewrite plan/todo markdown files.",
    )
    return parser.parse_args()


def now_label() -> str:
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def summarize_lot_status(results: list[dict[str, object]]) -> str:
    if not results:
        return "pending"
    if any(item["status"] == "blocked" for item in results):
        return "blocked"
    if any(item["status"] == "advisory" for item in results):
        return "degraded"
    return "done"


def lot_handoff_info(lot: Lot, results: list[dict[str, object]]) -> dict[str, object]:
    return {
        "lot_id": lot.key,
        "owner_repo": lot.owner_repo,
        "owner_agent": lot.owner_agent,
        "owner_subagent": lot.owner_subagent,
        "owner_team": lot.owner_team,
        "write_set": list(lot.handoff_write_set),
        "status": summarize_lot_status(results),
        "evidence": list(lot.plan_refs),
    }


def run_cmd(cmd: tuple[str, ...]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        list(cmd),
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )


def is_noise_path(path: str) -> bool:
    if path in NOISE_PATHS:
        return True
    return any(path.startswith(prefix) for prefix in NOISE_PREFIXES)


def filter_noise_paths(paths: list[str], include_noise: bool) -> list[str]:
    if include_noise:
        return paths
    return [path for path in paths if not is_noise_path(path)]


def git_status(include_noise: bool = False) -> tuple[str, list[str], int, int]:
    proc = run_cmd(("git", "status", "--short", "--branch"))
    if proc.returncode != 0:
        raise SystemExit(proc.stderr.strip() or proc.stdout.strip() or "git status failed")
    lines = proc.stdout.splitlines()
    branch = lines[0] if lines else "## unknown"
    ahead = 0
    behind = 0
    match = re.search(r"\[([^\]]+)\]", branch)
    if match:
        for chunk in match.group(1).split(","):
            chunk = chunk.strip()
            if chunk.startswith("ahead "):
                ahead = int(chunk.split()[1])
            elif chunk.startswith("behind "):
                behind = int(chunk.split()[1])
    dirty_paths: list[str] = []
    for line in lines[1:]:
        if not line:
            continue
        payload = line[3:]
        if " -> " in payload:
            payload = payload.split(" -> ", 1)[1]
        dirty_paths.append(payload.strip())
    filtered_paths = filter_noise_paths(dirty_paths, include_noise)
    unique_paths: list[str] = []
    seen: set[str] = set()
    for path in filtered_paths:
        if path in seen:
            continue
        seen.add(path)
        unique_paths.append(path)
    return branch, unique_paths, ahead, behind


def matches_path(candidate: str, tracked: str) -> bool:
    return tracked == candidate or tracked.startswith(candidate + "/")


def detect_lots(dirty_paths: list[str]) -> list[Lot]:
    if not dirty_paths:
        return []
    matched: list[Lot] = []
    dirty_unique = tuple(dict.fromkeys(dirty_paths))
    for lot in LOTS:
        for dirty in dirty_unique:
            if any(matches_path(path, dirty) for path in lot.paths):
                matched.append(lot)
                break
    matched.sort(key=lambda item: item.priority)
    return matched


def output_tail(text: str) -> str:
    lines = [line.rstrip() for line in text.splitlines() if line.strip()]
    if not lines:
        return ""
    return " | ".join(lines[-3:])


def classify_blocker(output: str) -> str | None:
    lower = output.lower()
    if "docker_timeout" in lower or "docker cli timeout" in lower or "timed out while checking" in lower:
        return "Docker CLI locale bloquee ou en timeout sur cette machine."
    if "cli_timeout" in lower:
        return "CLI locale en timeout pendant la validation."
    if any(token in lower for token in ("auth", "token", "permission", "credential", "secret")):
        return "Secrets/identifiants manquants pour une validation live."
    if "docker" in lower:
        return "Runtime Docker/CAD indisponible ou non accessible."
    if "not found" in lower or "no such file" in lower:
        return "Chemin ou outil attendu manquant."
    return None


def execute_lot(lot: Lot) -> list[dict[str, object]]:
    results: list[dict[str, object]] = []
    for validation in lot.validations:
        proc = run_cmd(validation.cmd)
        combined = "\n".join(part for part in (proc.stdout, proc.stderr) if part).strip()
        if proc.returncode == 0:
            status = "done"
        elif validation.required:
            status = "blocked"
        else:
            status = "advisory"
        results.append(
            {
                "name": validation.name,
                "cmd": list(validation.cmd),
                "required": validation.required,
                "status": status,
                "returncode": proc.returncode,
                "summary": output_tail(combined),
                "blocker": classify_blocker(combined) if proc.returncode != 0 else None,
            }
        )
        if status == "blocked":
            break
    return results


def load_intelligence_snapshot() -> dict[str, object] | None:
    if INTELLIGENCE_MEMORY_JSON.exists():
        try:
            return json.loads(INTELLIGENCE_MEMORY_JSON.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            return None
    proc = run_cmd(("bash", "tools/cockpit/intelligence_tui.sh", "--action", "memory", "--json"))
    if proc.returncode != 0:
        return None
    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError:
        return None


def render_plan(
    branch: str,
    dirty_paths: list[str],
    ahead: int,
    behind: int,
    lots: list[Lot],
    results: dict[str, list[dict[str, object]]],
    intelligence: dict[str, object] | None,
) -> str:
    lines = [
        "# 18) Plan d'enchainement autonome des lots utiles",
        "",
        f"Last updated: {now_label()}",
        "",
        "Ce plan est regenere localement par `tools/autonomous_next_lots.py`.",
        "",
        "## Cycle lot opérationnel",
        "",
        "1. detection: `bash tools/run_autonomous_next_lots.sh status`",
        "2. run: `bash tools/run_autonomous_next_lots.sh run`",
        "3. proof JSON: `bash tools/run_autonomous_next_lots.sh json`",
        "4. mise a jour plan/todo",
        "5. revue owner + routing lot suivant",
        "6. synthese operateur + lot exit checklist",
        "",
        "## Objectif",
        "",
        "Detecter les deltas utiles a traiter, prioriser le prochain lot executable,",
        "mettre a jour un plan/todo operateur, puis relancer les validations associees.",
        "",
        "## Regles de priorite",
        "",
        "1. lot dirty avec validations requises cassables",
        "2. lot dirty avec validations advisory ou docs",
        "3. repo clean mais en retard sur le remote",
        "4. regime stable sans lot local detecte",
        "",
        "## Etat Git courant",
        "",
        f"- branche: `{branch}`",
        f"- dirty paths: `{len(dirty_paths)}`",
        f"- ahead: `{ahead}`",
        f"- behind: `{behind}`",
        "",
    ]
    if dirty_paths:
        lines.append("### Fichiers dirty detectes")
        lines.append("")
        for path in dirty_paths:
            lines.append(f"- `{path}`")
        lines.append("")

    lines.append("## Gouvernance intelligence")
    lines.append("")
    if intelligence:
      lines.append(f"- status: `{intelligence.get('status', 'unknown')}`")
      lines.append(f"- open_task_count: `{intelligence.get('open_task_count', 0)}`")
      memory_artifacts = intelligence.get("memory_artifacts") or {}
      json_path = memory_artifacts.get("json") or str(INTELLIGENCE_MEMORY_JSON.relative_to(ROOT))
      lines.append(f"- memory: `{json_path}`")
      next_steps = intelligence.get("next_steps") or []
      if next_steps:
          lines.append("- next actions:")
          for step in next_steps[:3]:
              lines.append(f"  - {step}")
    else:
      lines.append("- intelligence snapshot: unavailable")
    lines.append("")

    lines.append("## Matrice lot -> owner -> dépendances -> rollback")
    lines.append("")

    lines.append("## Lots detectes")
    lines.append("")
    if not lots:
        lines.extend(
            [
                "- Aucun lot local utile detecte.",
                "- Si le repo est clean et a jour, le prochain lot utile devient un chantier decide par l'operateur.",
                "",
            ]
        )
    else:
        for index, lot in enumerate(lots, start=1):
            lines.append(f"### {index}. `{lot.key}` — {lot.title}")
            lines.append("")
            lines.append(f"- owner: team={lot.owner_team}, agent={lot.owner_agent}, repo={lot.owner_repo}")
            if lot.dependencies:
                lines.append("- dependencies: " + ", ".join(f"`{dep}`" for dep in lot.dependencies))
            else:
                lines.append("- dependencies: `none`")
            if lot.rollback_plan:
                lines.append("- rollback:")
                for entry in lot.rollback_plan:
                    lines.append(f"  - {entry}")
            lines.append(lot.description)
            lines.append("")
            refs = ", ".join(f"`{ref}`" for ref in lot.plan_refs)
            lines.append(f"- references: {refs}")
            lot_results = results.get(lot.key, [])
            if lot_results:
                done = sum(1 for item in lot_results if item["status"] == "done")
                advisory = sum(1 for item in lot_results if item["status"] == "advisory")
                blocked = sum(1 for item in lot_results if item["status"] == "blocked")
                lines.append(
                    f"- validations: `{done}` done, `{advisory}` advisory, `{blocked}` blocked"
                )
            else:
                lines.append("- validations: non executees sur ce cycle")
            lines.append(
                f"- handoff: lot_id={lot.key}, owner_repo={lot.owner_repo}, owner_agent={lot.owner_agent}, owner_subagent={lot.owner_subagent or 'none'}, status={summarize_lot_status(lot_results)}"
            )
            lines.append(f"- write_set: {', '.join(lot.handoff_write_set)}")
            lines.append("")

    blockers = sorted(
        {
            str(item["blocker"])
            for lot_items in results.values()
            for item in lot_items
            if item.get("status") == "blocked" and item.get("blocker")
        }
    )
    lines.append("## Questions a poser seulement si besoin reel")
    lines.append("")
    if blockers:
        for blocker in blockers:
            lines.append(f"- {blocker}")
    else:
        lines.append("- Aucune question bloquante detectee sur ce cycle.")
    lines.append("")

    lines.append("## Commandes operateur")
    lines.append("")
    lines.append("- `bash tools/run_autonomous_next_lots.sh status`")
    lines.append("- `bash tools/run_autonomous_next_lots.sh run`")
    lines.append("- `bash tools/run_autonomous_next_lots.sh json`")
    lines.append("- `bash tools/cockpit/render_weekly_refonte_summary.sh`")
    lines.append("")
    return "\n".join(lines)


def render_todo(
    lots: list[Lot],
    results: dict[str, list[dict[str, object]]],
    intelligence: dict[str, object] | None,
) -> str:
    lines = [
        "# 18) TODO enchainement autonome des lots utiles",
        "",
        f"Last updated: {now_label()}",
        "",
        "Ce fichier est regenere localement par `tools/autonomous_next_lots.py`.",
        "",
    ]
    if not lots:
        lines.extend(
            [
                "- done: aucun lot local utile detecte",
                "- next: attendre un nouveau delta ou choisir explicitement un chantier",
                "",
            ]
        )
        return "\n".join(lines)

    if intelligence:
        lines.append("## `intelligence-governance`")
        lines.append("")
        lines.append(f"- status: {intelligence.get('status', 'unknown')}")
        lines.append(f"- open_task_count: {intelligence.get('open_task_count', 0)}")
        for step in (intelligence.get("next_steps") or [])[:3]:
            lines.append(f"- next: {step}")
        memory_artifacts = intelligence.get("memory_artifacts") or {}
        if memory_artifacts.get("json"):
            lines.append(f"- evidence: {memory_artifacts['json']}")
        lines.append("")

    for lot in lots:
        lines.append(f"## `{lot.key}` — {lot.title}")
        lines.append("")
        lines.append(f"- done: lot detecte ({lot.description})")
        lot_results = results.get(lot.key, [])
        if not lot_results:
            lines.append("- pending: validations non executees")
        else:
            for item in lot_results:
                cmd = " ".join(item["cmd"])
                status = str(item["status"])
                summary = str(item["summary"] or "aucun detail")
                lines.append(f"- {status}: `{cmd}`")
                lines.append(f"  resume: {summary}")
        lines.append(f"- handoff lot_id: {lot.key}")
        lines.append(f"  owner_repo={lot.owner_repo}")
        lines.append(f"  owner_agent={lot.owner_agent}")
        lines.append(f"  owner_team={lot.owner_team}")
        if lot.dependencies:
            lines.append("  dependencies=" + ", ".join(f"{dep}" for dep in lot.dependencies))
        else:
            lines.append("  dependencies=none")
        if lot.rollback_plan:
            lines.append("  rollback=" + " | ".join(lot.rollback_plan))
        lines.append(f"  write_set={', '.join(lot.handoff_write_set)}")
        lines.append("")
    return "\n".join(lines)


def write_docs(plan_text: str, todo_text: str) -> None:
    PLAN_DOC.write_text(plan_text + "\n", encoding="utf-8")
    TODO_DOC.write_text(todo_text + "\n", encoding="utf-8")


def main() -> int:
    args = parse_args()
    branch, dirty_paths, ahead, behind = git_status(include_noise=args.include_noise)
    lots = detect_lots(dirty_paths)
    if args.max_lots > 0:
        lots = lots[: args.max_lots]

    results: dict[str, list[dict[str, object]]] = {}
    if args.mode == "run":
        for lot in lots:
            results[lot.key] = execute_lot(lot)

    intelligence = load_intelligence_snapshot()

    plan_text = render_plan(branch, dirty_paths, ahead, behind, lots, results, intelligence)
    todo_text = render_todo(lots, results, intelligence)
    should_write = not args.no_write and args.mode != "json"
    if should_write:
        write_docs(plan_text, todo_text)

    payload = {
        "branch": branch,
        "dirty_paths": dirty_paths,
        "ahead": ahead,
        "behind": behind,
        "lots": [
            {
                "key": lot.key,
                "title": lot.title,
                "priority": lot.priority,
                "plan_refs": list(lot.plan_refs),
                "handoff": lot_handoff_info(lot, results.get(lot.key, [])),
                "dependencies": list(lot.dependencies),
                "rollback_plan": list(lot.rollback_plan),
                "results": results.get(lot.key, []),
            }
            for lot in lots
        ],
        "plan_doc": str(PLAN_DOC.relative_to(ROOT)),
        "todo_doc": str(TODO_DOC.relative_to(ROOT)),
        "intelligence": {
            "status": intelligence.get("status", "unknown") if intelligence else "unknown",
            "open_task_count": intelligence.get("open_task_count", 0) if intelligence else 0,
            "next_steps": (intelligence.get("next_steps", []) if intelligence else []),
            "memory_artifacts": intelligence.get("memory_artifacts", {}) if intelligence else {},
        },
    }

    if args.mode == "json":
        print(json.dumps(payload, ensure_ascii=True, indent=2))
        return 0

    print(f"branch: {branch}")
    print(f"dirty_paths: {len(dirty_paths)}")
    print(f"lots: {', '.join(lot.key for lot in lots) if lots else 'none'}")
    print(f"plan_doc: {payload['plan_doc']}")
    print(f"todo_doc: {payload['todo_doc']}")
    if args.mode == "run":
        for lot in lots:
            lot_results = results.get(lot.key, [])
            done = sum(1 for item in lot_results if item["status"] == "done")
            advisory = sum(1 for item in lot_results if item["status"] == "advisory")
            blocked = sum(1 for item in lot_results if item["status"] == "blocked")
            print(f"{lot.key}: done={done} advisory={advisory} blocked={blocked}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
