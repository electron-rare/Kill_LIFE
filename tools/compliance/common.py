from __future__ import annotations
from pathlib import Path

try:
    import yaml
except ModuleNotFoundError as exc:  # pragma: no cover - dependency guard
    yaml = None
    _yaml_import_error = exc
else:
    _yaml_import_error = None

ROOT = Path(__file__).resolve().parents[2]


def _require_yaml() -> None:
    if yaml is None:
        raise SystemExit(
            "ERROR: PyYAML is required. Install with: "
            f"'{Path(__file__).resolve().parents[2] / '.venv/bin/python'} -m pip install PyYAML' "
            f"or 'python3 -m pip install PyYAML' ({_yaml_import_error})"
        )

def load_yaml(path: Path):
    _require_yaml()
    return yaml.safe_load(path.read_text(encoding="utf-8"))

def save_yaml(path: Path, data):
    _require_yaml()
    path.write_text(yaml.safe_dump(data, sort_keys=False, allow_unicode=True), encoding="utf-8")

def repo_path(rel: str) -> Path:
    return ROOT / rel

def load_active_profile_name() -> str:
    p = repo_path("compliance/active_profile.yaml")
    data = load_yaml(p)
    name = (data or {}).get("profile")
    if not name:
        raise SystemExit(f"ERROR: missing 'profile' in {p}")
    return str(name)

def load_profile(name: str) -> dict:
    p = repo_path(f"compliance/profiles/{name}.yaml")
    if not p.exists():
        raise SystemExit(f"ERROR: profile not found: {p}")
    return load_yaml(p) or {}

def load_catalog() -> dict:
    p = repo_path("compliance/standards_catalog.yaml")
    return load_yaml(p) or {}
