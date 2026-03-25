#!/usr/bin/env python3
"""
Freerouting Bridge — FREE alternative to paid autorouting services (T-HP-033/034).

Bridges KiCad DSN export -> Freerouting (open source Java autorouter) -> KiCad SES import.

Freerouting: https://github.com/freerouting/freerouting

Usage:
    # Route a board (auto-downloads Freerouting JAR if needed)
    python3 freerouting_bridge.py route --input board.dsn --output board.ses

    # Just download / update Freerouting
    python3 freerouting_bridge.py download

    # Verify DSN file before routing
    python3 freerouting_bridge.py check --input board.dsn

    # Specify custom JAR location
    python3 freerouting_bridge.py route --input board.dsn --jar /path/to/freerouting.jar
"""
from __future__ import annotations

import argparse
import json
import os
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path
from typing import Any, Dict, List, Optional

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
FREEROUTING_GITHUB = "freerouting/freerouting"
FREEROUTING_RELEASE_API = f"https://api.github.com/repos/{FREEROUTING_GITHUB}/releases/latest"
DEFAULT_JAR_DIR = Path.home() / ".local" / "share" / "freerouting"
DEFAULT_JAR_PATH = DEFAULT_JAR_DIR / "freerouting.jar"

# Minimum Java version
MIN_JAVA_VERSION = 17


# ---------------------------------------------------------------------------
# Java detection
# ---------------------------------------------------------------------------
def find_java() -> Optional[str]:
    """Find a suitable Java runtime."""
    # Check JAVA_HOME first
    java_home = os.environ.get("JAVA_HOME")
    if java_home:
        java_bin = Path(java_home) / "bin" / "java"
        if java_bin.exists():
            return str(java_bin)

    # Check PATH
    java = shutil.which("java")
    if java:
        return java

    # macOS: check common Homebrew / system locations
    if platform.system() == "Darwin":
        candidates = [
            "/opt/homebrew/bin/java",
            "/usr/local/bin/java",
            "/usr/bin/java",
        ]
        for c in candidates:
            if Path(c).exists():
                return c

    return None


def check_java_version(java_bin: str) -> int:
    """Return Java major version number, or 0 on failure."""
    try:
        result = subprocess.run(
            [java_bin, "-version"],
            capture_output=True,
            text=True,
            timeout=10,
        )
        output = result.stderr + result.stdout
        match = re.search(r'"(\d+)', output)
        if match:
            return int(match.group(1))
    except Exception:
        pass
    return 0


# ---------------------------------------------------------------------------
# Freerouting JAR management
# ---------------------------------------------------------------------------
def download_freerouting(dest: Path = DEFAULT_JAR_PATH, force: bool = False) -> Path:
    """Download the latest Freerouting JAR from GitHub releases."""
    dest.parent.mkdir(parents=True, exist_ok=True)

    if dest.exists() and not force:
        print(f"  Freerouting already present: {dest}")
        print(f"  Use --force to re-download")
        return dest

    print(f"  Fetching latest release from {FREEROUTING_GITHUB} ...")

    try:
        req = urllib.request.Request(
            FREEROUTING_RELEASE_API,
            headers={"Accept": "application/vnd.github.v3+json", "User-Agent": "kill-life-bridge"},
        )
        with urllib.request.urlopen(req, timeout=30) as resp:
            release = json.loads(resp.read())
    except Exception as exc:
        sys.exit(f"ERROR: failed to fetch release info: {exc}")

    # Find the JAR asset
    jar_asset = None
    for asset in release.get("assets", []):
        name = asset["name"].lower()
        if name.endswith(".jar") and "freerouting" in name:
            jar_asset = asset
            break

    if not jar_asset:
        # Some releases use the executable JAR without "freerouting" in the name
        for asset in release.get("assets", []):
            if asset["name"].lower().endswith(".jar"):
                jar_asset = asset
                break

    if not jar_asset:
        sys.exit(
            f"ERROR: no JAR found in release {release.get('tag_name', '?')}.\n"
            f"  Download manually from https://github.com/{FREEROUTING_GITHUB}/releases"
        )

    download_url = jar_asset["browser_download_url"]
    size_mb = jar_asset.get("size", 0) / (1024 * 1024)
    print(f"  Downloading {jar_asset['name']} ({size_mb:.1f} MB) ...")

    try:
        urllib.request.urlretrieve(download_url, str(dest))
    except Exception as exc:
        sys.exit(f"ERROR: download failed: {exc}")

    print(f"  -> {dest}")
    return dest


def find_jar(jar_path: Optional[str] = None) -> Path:
    """Locate the Freerouting JAR."""
    if jar_path:
        p = Path(jar_path)
        if p.exists():
            return p
        sys.exit(f"ERROR: JAR not found at {jar_path}")

    # Check environment variable
    env_jar = os.environ.get("FREEROUTING_JAR")
    if env_jar and Path(env_jar).exists():
        return Path(env_jar)

    # Check default location
    if DEFAULT_JAR_PATH.exists():
        return DEFAULT_JAR_PATH

    # Auto-download
    print("  Freerouting JAR not found, downloading ...")
    return download_freerouting()


# ---------------------------------------------------------------------------
# DSN validation
# ---------------------------------------------------------------------------
def check_dsn(dsn_path: Path) -> Dict[str, Any]:
    """Basic validation of a KiCad DSN file."""
    if not dsn_path.exists():
        sys.exit(f"ERROR: file not found: {dsn_path}")

    text = dsn_path.read_text(encoding="utf-8", errors="replace")

    info: Dict[str, Any] = {
        "file": str(dsn_path),
        "size_bytes": dsn_path.stat().st_size,
        "valid": False,
    }

    # Check for DSN header
    if not text.strip().startswith("(pcb"):
        info["error"] = "File does not start with (pcb — not a valid DSN export"
        return info

    # Count components and nets
    components = re.findall(r"\(component\s", text)
    nets = re.findall(r"\(net\s", text)
    wires = re.findall(r"\(wire\s", text)
    vias = re.findall(r"\(via\s", text)

    info.update({
        "valid": True,
        "components": len(components),
        "nets": len(nets),
        "existing_wires": len(wires),
        "existing_vias": len(vias),
    })

    # Check paren balance
    opens = text.count("(")
    closes = text.count(")")
    if opens != closes:
        info["warning"] = f"Unbalanced parentheses: {opens} open vs {closes} close"

    return info


# ---------------------------------------------------------------------------
# Routing
# ---------------------------------------------------------------------------
def route(
    dsn_path: Path,
    output_path: Optional[Path] = None,
    jar_path: Optional[str] = None,
    java_bin: Optional[str] = None,
    timeout_seconds: int = 600,
    extra_args: Optional[List[str]] = None,
) -> Path:
    """Run Freerouting on a DSN file, producing a SES file."""
    dsn_path = dsn_path.resolve()
    if not dsn_path.exists():
        sys.exit(f"ERROR: DSN file not found: {dsn_path}")

    # Validate DSN
    info = check_dsn(dsn_path)
    if not info["valid"]:
        sys.exit(f"ERROR: invalid DSN file: {info.get('error', 'unknown')}")
    print(f"  DSN: {info['components']} components, {info['nets']} nets")

    # Find Java
    java = java_bin or find_java()
    if not java:
        sys.exit(
            "ERROR: Java not found. Install Java >= 17:\n"
            "  macOS: brew install openjdk@17\n"
            "  Linux: sudo apt install openjdk-17-jre-headless"
        )
    version = check_java_version(java)
    if version and version < MIN_JAVA_VERSION:
        print(f"  WARN: Java {version} detected, Freerouting needs >= {MIN_JAVA_VERSION}")

    # Find JAR
    jar = find_jar(jar_path)

    # Output path
    if output_path is None:
        output_path = dsn_path.with_suffix(".ses")

    # Build command
    cmd = [
        java,
        "-jar", str(jar),
        "-de", str(dsn_path),      # design input
        "-do", str(output_path),   # design output (SES)
        "-mp", "20",               # max passes
    ]
    if extra_args:
        cmd.extend(extra_args)

    print(f"  Running Freerouting (timeout={timeout_seconds}s) ...")
    print(f"    {' '.join(cmd)}")

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout_seconds,
            env={**os.environ, "DISPLAY": ""},  # headless
        )
    except subprocess.TimeoutExpired:
        sys.exit(f"ERROR: Freerouting timed out after {timeout_seconds}s")

    if result.returncode != 0:
        stderr = result.stderr.strip()
        stdout = result.stdout.strip()
        # Freerouting may still produce output even with non-zero exit
        if output_path.exists() and output_path.stat().st_size > 0:
            print(f"  WARN: Freerouting exited with code {result.returncode} but produced output")
        else:
            sys.exit(
                f"ERROR: Freerouting failed (exit {result.returncode}):\n"
                f"  stderr: {stderr[:500]}\n"
                f"  stdout: {stdout[:500]}"
            )

    if not output_path.exists():
        sys.exit("ERROR: Freerouting produced no SES output")

    print(f"  -> {output_path} ({output_path.stat().st_size} bytes)")
    print(f"\n  Import into KiCad:")
    print(f"    File -> Import -> Specctra Session (.ses)")
    return output_path


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(
        description="Freerouting bridge for KiCad (free autorouting)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    sub = parser.add_subparsers(dest="command")

    # route
    p_route = sub.add_parser("route", help="Route a DSN file")
    p_route.add_argument("--input", type=Path, required=True, help="KiCad DSN export")
    p_route.add_argument("--output", type=Path, help="SES output (default: same name .ses)")
    p_route.add_argument("--jar", type=str, help="Path to freerouting.jar")
    p_route.add_argument("--java", type=str, help="Path to java binary")
    p_route.add_argument("--timeout", type=int, default=600, help="Timeout in seconds")

    # download
    p_dl = sub.add_parser("download", help="Download/update Freerouting JAR")
    p_dl.add_argument("--dest", type=Path, default=DEFAULT_JAR_PATH)
    p_dl.add_argument("--force", action="store_true")

    # check
    p_chk = sub.add_parser("check", help="Validate a DSN file")
    p_chk.add_argument("--input", type=Path, required=True)

    args = parser.parse_args()

    if args.command == "route":
        route(
            dsn_path=args.input,
            output_path=args.output,
            jar_path=args.jar,
            java_bin=args.java,
            timeout_seconds=args.timeout,
        )
    elif args.command == "download":
        download_freerouting(dest=args.dest, force=args.force)
    elif args.command == "check":
        info = check_dsn(args.input)
        print(json.dumps(info, indent=2))
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
