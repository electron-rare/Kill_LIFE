from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIRMWARE_DIR = ROOT / "firmware"
EVIDENCE_ROOT = ROOT / "docs" / "evidence"
CAD_STACK = ROOT / "tools" / "hw" / "cad_stack.sh"
PIO_MODE_ENV = "KILL_LIFE_PIO_MODE"

BUILD_ENV_BY_TARGET = {
    "esp": "esp32s3_arduino",
    "esp32s3_arduino": "esp32s3_arduino",
    "esp32_arduino": "esp32_arduino",
}

TEST_ENV_BY_TARGET = {
    "linux": "native",
    "native": "native",
}


@dataclass(frozen=True)
class TargetSpec:
    requested: str
    env: str
    mode: str


def now_utc() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def relative_to_root(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(ROOT)).replace("\\", "/")
    except ValueError:
        return str(path.resolve())


def ensure_evidence_dir(target: str) -> Path:
    path = EVIDENCE_ROOT / target
    path.mkdir(parents=True, exist_ok=True)
    return path


def pio_mode() -> str:
    value = os.environ.get(PIO_MODE_ENV, "auto").strip().lower() or "auto"
    if value not in {"auto", "native", "container"}:
        raise SystemExit(
            f"Unsupported {PIO_MODE_ENV}='{value}'. Supported values: auto, native, container"
        )
    return value


def repo_local_pio_candidates(root: Path | None = None) -> list[Path]:
    base = root or ROOT
    return [
        base / ".venv" / "bin" / "pio",
        base / ".venv" / "Scripts" / "pio.exe",
    ]


def native_pio_command(root: Path | None = None) -> list[str] | None:
    host_pio = shutil.which("pio")
    if host_pio:
        return [host_pio]

    for candidate in repo_local_pio_candidates(root):
        if candidate.exists() and os.access(candidate, os.X_OK):
            return [str(candidate)]

    try:
        import platformio  # noqa: F401
    except ImportError:
        return None
    return [sys.executable, "-m", "platformio"]


def native_pio_available() -> bool:
    return native_pio_command() is not None


def container_pio_available() -> bool:
    return CAD_STACK.exists() and shutil.which("bash") is not None and shutil.which("docker") is not None


def firmware_project_dir() -> str:
    return relative_to_root(FIRMWARE_DIR)


def resolve_target(target: str, expected_mode: str | None = None) -> TargetSpec:
    if target in BUILD_ENV_BY_TARGET:
        spec = TargetSpec(requested=target, env=BUILD_ENV_BY_TARGET[target], mode="build")
    elif target in TEST_ENV_BY_TARGET:
        spec = TargetSpec(requested=target, env=TEST_ENV_BY_TARGET[target], mode="test")
    else:
        supported = sorted({*BUILD_ENV_BY_TARGET.keys(), *TEST_ENV_BY_TARGET.keys()})
        raise SystemExit(f"Unsupported target '{target}'. Supported targets: {', '.join(supported)}")

    if expected_mode and spec.mode != expected_mode:
        raise SystemExit(f"Target '{target}' only supports mode '{spec.mode}', not '{expected_mode}'")
    return spec


def platformio_command(spec: TargetSpec, step: str) -> tuple[list[str], Path, str]:
    mode = pio_mode()
    native_available = native_pio_available()
    use_container = mode == "container" or (mode == "auto" and not native_available)

    pio_subcommand = "run" if step == "build" else "test"
    project_dir = firmware_project_dir()
    args = [pio_subcommand, "-d", project_dir, "-e", spec.env]

    if use_container:
        return ["bash", str(CAD_STACK), "pio", *args], ROOT, "cad-stack-container"

    native_cmd = native_pio_command()
    if native_cmd is None:
        return ["bash", str(CAD_STACK), "pio", *args], ROOT, "cad-stack-container"

    return [*native_cmd, *args], ROOT, "native-pio"


def resolved_pio_runner(spec: TargetSpec, step: str) -> str:
    return platformio_command(spec, step)[2]


def run_logged_command(spec: TargetSpec, step: str, cmd: list[str], cwd: Path = FIRMWARE_DIR) -> int:
    evidence_dir = ensure_evidence_dir(spec.requested)
    runner = "subprocess"
    try:
        result = subprocess.run(cmd, cwd=str(cwd), capture_output=True, text=True)
        stdout = result.stdout
        stderr = result.stderr
        returncode = result.returncode
    except FileNotFoundError as exc:
        stdout = ""
        stderr = str(exc)
        returncode = 127
    (evidence_dir / f"{step}.stdout.txt").write_text(stdout, encoding="utf-8")
    (evidence_dir / f"{step}.stderr.txt").write_text(stderr, encoding="utf-8")
    write_json(
        evidence_dir / f"{step}.result.json",
        {
            "target": spec.requested,
            "env": spec.env,
            "mode": spec.mode,
            "step": step,
            "cwd": relative_to_root(cwd),
            "command": cmd,
            "runner": runner,
            "returncode": returncode,
            "generated_at_utc": now_utc(),
        },
    )
    return returncode


def run_platformio_step(spec: TargetSpec, step: str) -> int:
    cmd, cwd, runner = platformio_command(spec, step)
    evidence_dir = ensure_evidence_dir(spec.requested)
    try:
        result = subprocess.run(cmd, cwd=str(cwd), capture_output=True, text=True)
        stdout = result.stdout
        stderr = result.stderr
        returncode = result.returncode
    except FileNotFoundError as exc:
        stdout = ""
        stderr = str(exc)
        returncode = 127

    (evidence_dir / f"{step}.stdout.txt").write_text(stdout, encoding="utf-8")
    (evidence_dir / f"{step}.stderr.txt").write_text(stderr, encoding="utf-8")
    write_json(
        evidence_dir / f"{step}.result.json",
        {
            "target": spec.requested,
            "env": spec.env,
            "mode": spec.mode,
            "step": step,
            "cwd": relative_to_root(cwd),
            "project_dir": firmware_project_dir(),
            "command": cmd,
            "runner": runner,
            "returncode": returncode,
            "generated_at_utc": now_utc(),
        },
    )
    return returncode


def collect_artifacts(spec: TargetSpec) -> list[str]:
    base = FIRMWARE_DIR / ".pio" / "build" / spec.env
    if spec.mode == "build":
        candidates = [
            base / "firmware.bin",
            base / "firmware.elf",
            base / "firmware.map",
            base,
        ]
    else:
        candidates = [base]
    return [relative_to_root(path) for path in candidates if path.exists()]
