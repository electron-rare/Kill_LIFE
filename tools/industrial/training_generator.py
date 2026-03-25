#!/usr/bin/env python3
"""
training_generator.py — Generate maintenance procedures from machine logs.

Reads log files (syslog, CSV, JSON), extracts recurring failure patterns,
and generates step-by-step maintenance procedures in Markdown.
Supports multilingual output (FR/EN/DE) via simple template system.

Usage:
    python3 training_generator.py generate --logs /path/to/logs --lang fr --output procedure.md
    python3 training_generator.py analyze  --logs /path/to/logs

Part of Kill_LIFE tools/industrial — usable standalone for any project.
"""

from __future__ import annotations

import argparse
import csv
import json
import logging
import os
import re
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Optional

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Multilingual templates
# ---------------------------------------------------------------------------

TEMPLATES: dict[str, dict[str, str]] = {
    "fr": {
        "title": "Procedure de Maintenance",
        "generated_on": "Genere le",
        "source_logs": "Journaux source",
        "summary": "Resume",
        "failure_patterns": "Schemas de defaillance detectes",
        "pattern": "Schema",
        "occurrences": "Occurrences",
        "severity": "Severite",
        "first_seen": "Premiere occurrence",
        "last_seen": "Derniere occurrence",
        "procedure": "Procedure corrective",
        "step": "Etape",
        "prerequisites": "Prerequis",
        "safety": "Securite : couper l'alimentation et verrouiller (LOTO) avant intervention.",
        "tools_needed": "Outils necessaires",
        "estimated_time": "Temps estime",
        "minutes": "min",
        "high": "HAUTE",
        "medium": "MOYENNE",
        "low": "BASSE",
        "no_patterns": "Aucun schema de defaillance detecte dans les journaux fournis.",
        "total_entries": "Entrees totales analysees",
        "unique_patterns": "Schemas uniques detectes",
        "top_failures": "Top defaillances",
        "analysis_title": "Analyse des journaux machines",
    },
    "en": {
        "title": "Maintenance Procedure",
        "generated_on": "Generated on",
        "source_logs": "Source logs",
        "summary": "Summary",
        "failure_patterns": "Detected Failure Patterns",
        "pattern": "Pattern",
        "occurrences": "Occurrences",
        "severity": "Severity",
        "first_seen": "First seen",
        "last_seen": "Last seen",
        "procedure": "Corrective Procedure",
        "step": "Step",
        "prerequisites": "Prerequisites",
        "safety": "Safety: disconnect power supply and lockout/tagout (LOTO) before intervention.",
        "tools_needed": "Tools needed",
        "estimated_time": "Estimated time",
        "minutes": "min",
        "high": "HIGH",
        "medium": "MEDIUM",
        "low": "LOW",
        "no_patterns": "No failure patterns detected in provided logs.",
        "total_entries": "Total entries analyzed",
        "unique_patterns": "Unique patterns detected",
        "top_failures": "Top failures",
        "analysis_title": "Machine Log Analysis",
    },
    "de": {
        "title": "Wartungsverfahren",
        "generated_on": "Erstellt am",
        "source_logs": "Quellprotokolle",
        "summary": "Zusammenfassung",
        "failure_patterns": "Erkannte Fehlermuster",
        "pattern": "Muster",
        "occurrences": "Vorkommen",
        "severity": "Schweregrad",
        "first_seen": "Erstmals gesehen",
        "last_seen": "Zuletzt gesehen",
        "procedure": "Korrekturverfahren",
        "step": "Schritt",
        "prerequisites": "Voraussetzungen",
        "safety": "Sicherheit: Stromversorgung trennen und Lockout/Tagout (LOTO) vor Eingriff.",
        "tools_needed": "Benoetigte Werkzeuge",
        "estimated_time": "Geschaetzte Zeit",
        "minutes": "min",
        "high": "HOCH",
        "medium": "MITTEL",
        "low": "NIEDRIG",
        "no_patterns": "Keine Fehlermuster in den bereitgestellten Protokollen erkannt.",
        "total_entries": "Gesamteintraege analysiert",
        "unique_patterns": "Eindeutige Muster erkannt",
        "top_failures": "Haeufigste Fehler",
        "analysis_title": "Maschinenprotokoll-Analyse",
    },
}

# ---------------------------------------------------------------------------
# Failure keywords for pattern detection
# ---------------------------------------------------------------------------

FAILURE_KEYWORDS = [
    # English
    "error", "fault", "fail", "alarm", "warning", "critical", "emergency",
    "overload", "overheat", "overcurrent", "timeout", "disconnect",
    "shutdown", "stopped", "stall", "jam", "leak", "vibration",
    "bearing", "misalignment", "cavitation",
    # French
    "erreur", "defaut", "panne", "alarme", "avertissement", "critique",
    "surcharge", "surchauffe", "surintensité", "deconnexion",
    "arret", "blocage", "fuite", "roulement",
    # German
    "fehler", "stoerung", "ausfall", "warnung", "ueberlast",
    "ueberhitzung", "abschaltung", "lager",
]

SEVERITY_KEYWORDS = {
    "high": ["critical", "emergency", "shutdown", "fail", "critique", "arret", "ausfall", "abschaltung"],
    "medium": ["error", "fault", "alarm", "overload", "erreur", "defaut", "alarme", "fehler", "stoerung"],
    "low": ["warning", "avertissement", "warnung", "timeout"],
}

# ---------------------------------------------------------------------------
# Data structures
# ---------------------------------------------------------------------------


@dataclass
class LogEntry:
    """A single parsed log entry."""
    timestamp: Optional[str] = None
    level: Optional[str] = None
    source: Optional[str] = None
    message: str = ""
    raw: str = ""
    file_origin: str = ""


@dataclass
class FailurePattern:
    """A recurring failure detected in logs."""
    signature: str = ""
    keyword: str = ""
    occurrences: int = 0
    severity: str = "low"
    first_seen: str = ""
    last_seen: str = ""
    sample_messages: list[str] = field(default_factory=list)


# ---------------------------------------------------------------------------
# Log parsers
# ---------------------------------------------------------------------------

# Syslog: "Mar 24 10:15:03 host process[pid]: message"
RE_SYSLOG = re.compile(
    r"^(\w{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})\s+(\S+)\s+(\S+?)(?:\[\d+\])?:\s+(.*)$"
)

# Generic timestamped: "2024-03-24 10:15:03 [ERROR] message"
RE_TIMESTAMPED = re.compile(
    r"^(\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}\S*)\s+\[?(\w+)\]?\s+(.*)$"
)


def parse_syslog_line(line: str, filepath: str) -> Optional[LogEntry]:
    m = RE_SYSLOG.match(line.strip())
    if not m:
        return None
    return LogEntry(
        timestamp=m.group(1),
        source=m.group(3),
        message=m.group(4),
        raw=line.strip(),
        file_origin=filepath,
    )


def parse_timestamped_line(line: str, filepath: str) -> Optional[LogEntry]:
    m = RE_TIMESTAMPED.match(line.strip())
    if not m:
        return None
    return LogEntry(
        timestamp=m.group(1),
        level=m.group(2),
        message=m.group(3),
        raw=line.strip(),
        file_origin=filepath,
    )


def parse_text_file(filepath: str) -> list[LogEntry]:
    """Parse a text log file (syslog or generic timestamped format)."""
    entries: list[LogEntry] = []
    try:
        with open(filepath, "r", errors="replace") as f:
            for line in f:
                entry = parse_syslog_line(line, filepath) or parse_timestamped_line(line, filepath)
                if entry:
                    entries.append(entry)
                elif line.strip():
                    entries.append(LogEntry(message=line.strip(), raw=line.strip(), file_origin=filepath))
    except Exception as exc:
        logger.warning("Could not read %s: %s", filepath, exc)
    return entries


def parse_csv_file(filepath: str) -> list[LogEntry]:
    """Parse a CSV log file. Looks for message/error/event columns."""
    entries: list[LogEntry] = []
    try:
        with open(filepath, "r", errors="replace") as f:
            reader = csv.DictReader(f)
            if not reader.fieldnames:
                return entries
            fields_lower = {fn.lower(): fn for fn in reader.fieldnames}
            # Find relevant columns
            ts_col = fields_lower.get("timestamp") or fields_lower.get("time") or fields_lower.get("date")
            msg_col = (
                fields_lower.get("message") or fields_lower.get("msg") or
                fields_lower.get("error") or fields_lower.get("event") or
                fields_lower.get("description")
            )
            level_col = fields_lower.get("level") or fields_lower.get("severity")
            for row in reader:
                msg = row.get(msg_col, "") if msg_col else " | ".join(row.values())
                entries.append(LogEntry(
                    timestamp=row.get(ts_col, "") if ts_col else None,
                    level=row.get(level_col, "") if level_col else None,
                    message=msg,
                    raw=str(row),
                    file_origin=filepath,
                ))
    except Exception as exc:
        logger.warning("Could not read CSV %s: %s", filepath, exc)
    return entries


def parse_json_file(filepath: str) -> list[LogEntry]:
    """Parse a JSON log file. Supports JSON-lines or array of objects."""
    entries: list[LogEntry] = []
    try:
        with open(filepath, "r", errors="replace") as f:
            content = f.read().strip()
        # Try JSON lines first
        records: list[dict] = []
        if content.startswith("["):
            records = json.loads(content)
        else:
            for line in content.splitlines():
                line = line.strip()
                if line:
                    try:
                        records.append(json.loads(line))
                    except json.JSONDecodeError:
                        pass
        for rec in records:
            if not isinstance(rec, dict):
                continue
            msg = (
                rec.get("message") or rec.get("msg") or
                rec.get("error") or rec.get("event") or str(rec)
            )
            entries.append(LogEntry(
                timestamp=rec.get("timestamp") or rec.get("time") or rec.get("@timestamp"),
                level=rec.get("level") or rec.get("severity"),
                source=rec.get("source") or rec.get("host") or rec.get("machine"),
                message=str(msg),
                raw=json.dumps(rec),
                file_origin=filepath,
            ))
    except Exception as exc:
        logger.warning("Could not read JSON %s: %s", filepath, exc)
    return entries


def parse_log_file(filepath: str) -> list[LogEntry]:
    """Auto-detect format and parse a log file."""
    p = Path(filepath)
    ext = p.suffix.lower()
    if ext == ".csv":
        return parse_csv_file(filepath)
    if ext == ".json" or ext == ".jsonl":
        return parse_json_file(filepath)
    # Default: text (syslog, generic)
    return parse_text_file(filepath)


def collect_log_files(path: str) -> list[str]:
    """Collect all log files from a path (file or directory)."""
    p = Path(path)
    if p.is_file():
        return [str(p)]
    if p.is_dir():
        files: list[str] = []
        for ext in ("*.log", "*.txt", "*.csv", "*.json", "*.jsonl", "*.syslog"):
            files.extend(str(f) for f in p.rglob(ext))
        return sorted(files)
    logger.warning("Path not found: %s", path)
    return []


# ---------------------------------------------------------------------------
# Pattern extraction
# ---------------------------------------------------------------------------

def _normalize_message(msg: str) -> str:
    """Normalize a message for grouping: lowercase, strip numbers/timestamps."""
    s = msg.lower()
    s = re.sub(r"\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}\S*", "<TIMESTAMP>", s)
    s = re.sub(r"\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b", "<IP>", s)
    s = re.sub(r"\b0x[0-9a-f]+\b", "<HEX>", s)
    s = re.sub(r"\b\d+\b", "<N>", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s


def _classify_severity(msg: str) -> str:
    lower = msg.lower()
    for sev, keywords in SEVERITY_KEYWORDS.items():
        if any(kw in lower for kw in keywords):
            return sev
    return "low"


def extract_failure_patterns(entries: list[LogEntry], min_occurrences: int = 2) -> list[FailurePattern]:
    """Extract recurring failure patterns from log entries."""
    # Filter entries containing failure keywords
    failure_entries: list[LogEntry] = []
    for e in entries:
        lower_msg = e.message.lower()
        if any(kw in lower_msg for kw in FAILURE_KEYWORDS):
            failure_entries.append(e)

    if not failure_entries:
        return []

    # Group by normalized signature
    groups: dict[str, list[LogEntry]] = defaultdict(list)
    for e in failure_entries:
        sig = _normalize_message(e.message)
        groups[sig].append(e)

    patterns: list[FailurePattern] = []
    for sig, group_entries in groups.items():
        if len(group_entries) < min_occurrences:
            continue
        # Find matching keyword
        keyword = ""
        lower_sig = sig.lower()
        for kw in FAILURE_KEYWORDS:
            if kw in lower_sig:
                keyword = kw
                break
        timestamps = [e.timestamp for e in group_entries if e.timestamp]
        samples = list({e.message for e in group_entries[:5]})
        patterns.append(FailurePattern(
            signature=sig,
            keyword=keyword,
            occurrences=len(group_entries),
            severity=_classify_severity(sig),
            first_seen=timestamps[0] if timestamps else "",
            last_seen=timestamps[-1] if timestamps else "",
            sample_messages=samples[:3],
        ))

    patterns.sort(key=lambda p: (-{"high": 3, "medium": 2, "low": 1}.get(p.severity, 0), -p.occurrences))
    return patterns


# ---------------------------------------------------------------------------
# Procedure generation
# ---------------------------------------------------------------------------

GENERIC_PROCEDURES: dict[str, list[str]] = {
    "bearing": [
        "Inspect bearing for wear, noise, or excessive play",
        "Check lubrication level and quality",
        "Measure vibration levels with accelerometer",
        "Replace bearing if worn beyond tolerance",
        "Re-lubricate with manufacturer-specified grease",
        "Verify alignment after reassembly",
    ],
    "overheat": [
        "Check cooling system (fans, radiators, coolant level)",
        "Inspect thermal paste / thermal pads",
        "Clean dust filters and heat sinks",
        "Verify ambient temperature is within spec",
        "Check thermal sensor calibration",
        "Reduce load or duty cycle if persistent",
    ],
    "overload": [
        "Check motor current draw against nameplate rating",
        "Inspect drive belt / coupling for slippage or damage",
        "Verify load is within machine capacity",
        "Check VFD / soft-starter parameters",
        "Inspect mechanical linkage for binding or friction",
        "Reset overload relay after clearing root cause",
    ],
    "vibration": [
        "Perform vibration analysis (FFT spectrum)",
        "Check mounting bolts and foundation",
        "Inspect coupling alignment (laser align if needed)",
        "Check for bearing defects (BPFO/BPFI frequencies)",
        "Inspect impeller/rotor for imbalance",
        "Verify isolation mounts are not degraded",
    ],
    "jam": [
        "Clear jammed material from conveyor / mechanism",
        "Inspect guides and clearances for foreign objects",
        "Check sensor alignment (photoelectric / proximity)",
        "Verify pneumatic / hydraulic pressure is correct",
        "Inspect wear parts (blades, rollers, pushers)",
        "Reset fault and run in manual mode to verify",
    ],
    "leak": [
        "Identify leak source (visual, UV dye, pressure test)",
        "Check gaskets, seals, and O-rings",
        "Verify fitting torque to spec",
        "Inspect hoses and tubing for cracks or abrasion",
        "Check pressure relief valve operation",
        "Clean area and monitor for recurrence",
    ],
    "disconnect": [
        "Check cable connections and terminal blocks",
        "Inspect network cables / fiber for damage",
        "Verify power supply voltage and fuse status",
        "Check communication settings (baud rate, address)",
        "Test with known-good cable / port",
        "Check for EMI / grounding issues",
    ],
    "timeout": [
        "Check network connectivity (ping, traceroute)",
        "Verify PLC / controller scan time",
        "Inspect communication bus for errors",
        "Check for resource exhaustion (CPU, memory, buffer)",
        "Increase timeout parameter if load justifies it",
        "Review recent configuration changes",
    ],
}

DEFAULT_PROCEDURE = [
    "Identify the root cause from error logs and observations",
    "Isolate the affected subsystem",
    "Perform visual inspection of components",
    "Check relevant sensor readings and calibrations",
    "Replace or repair faulty component",
    "Test in manual mode before returning to production",
    "Document the repair and update maintenance log",
]


def _get_procedure_steps(pattern: FailurePattern) -> list[str]:
    """Select appropriate procedure steps based on failure keyword."""
    kw = pattern.keyword.lower()
    for proc_key, steps in GENERIC_PROCEDURES.items():
        if proc_key in kw or proc_key in pattern.signature.lower():
            return steps
    # Check signature for any known procedure key
    for proc_key, steps in GENERIC_PROCEDURES.items():
        if proc_key in pattern.signature.lower():
            return steps
    return DEFAULT_PROCEDURE


def generate_procedure_markdown(
    patterns: list[FailurePattern],
    lang: str,
    log_sources: list[str],
    total_entries: int,
) -> str:
    """Generate a Markdown maintenance procedure document."""
    t = TEMPLATES.get(lang, TEMPLATES["en"])
    sev_label = {"high": t["high"], "medium": t["medium"], "low": t["low"]}
    now = datetime.now().strftime("%Y-%m-%d %H:%M")

    lines: list[str] = []
    lines.append(f"# {t['title']}")
    lines.append("")
    lines.append(f"**{t['generated_on']}** : {now}")
    lines.append("")
    lines.append(f"**{t['source_logs']}** : {len(log_sources)} fichiers")
    lines.append("")

    # Summary
    lines.append(f"## {t['summary']}")
    lines.append("")
    lines.append(f"- {t['total_entries']} : {total_entries}")
    lines.append(f"- {t['unique_patterns']} : {len(patterns)}")
    if patterns:
        high = sum(1 for p in patterns if p.severity == "high")
        med = sum(1 for p in patterns if p.severity == "medium")
        low = sum(1 for p in patterns if p.severity == "low")
        lines.append(f"- {t['high']} : {high} | {t['medium']} : {med} | {t['low']} : {low}")
    lines.append("")

    if not patterns:
        lines.append(f"> {t['no_patterns']}")
        return "\n".join(lines)

    # Failure patterns table
    lines.append(f"## {t['failure_patterns']}")
    lines.append("")
    lines.append(f"| # | {t['pattern']} | {t['occurrences']} | {t['severity']} | {t['first_seen']} | {t['last_seen']} |")
    lines.append("|---|---|---|---|---|---|")
    for i, p in enumerate(patterns, 1):
        sig_short = p.signature[:60] + ("..." if len(p.signature) > 60 else "")
        lines.append(
            f"| {i} | `{sig_short}` | {p.occurrences} | **{sev_label.get(p.severity, p.severity)}** "
            f"| {p.first_seen or '-'} | {p.last_seen or '-'} |"
        )
    lines.append("")

    # Procedures
    for i, p in enumerate(patterns, 1):
        lines.append(f"## {t['procedure']} #{i} — `{p.keyword or 'general'}`")
        lines.append("")
        lines.append(f"> **{t['pattern']}** : {p.signature[:80]}")
        lines.append(f"> **{t['severity']}** : {sev_label.get(p.severity, p.severity)} | "
                      f"**{t['occurrences']}** : {p.occurrences}")
        lines.append("")
        lines.append(f"### {t['prerequisites']}")
        lines.append("")
        lines.append(f"- {t['safety']}")
        lines.append(f"- {t['tools_needed']} : standard maintenance toolkit")
        lines.append(f"- {t['estimated_time']} : 30-60 {t['minutes']}")
        lines.append("")

        steps = _get_procedure_steps(p)
        for j, step in enumerate(steps, 1):
            lines.append(f"**{t['step']} {j}.** {step}")
            lines.append("")

        if p.sample_messages:
            lines.append("**Log samples:**")
            lines.append("")
            for sample in p.sample_messages:
                lines.append(f"  - `{sample[:120]}`")
            lines.append("")

        lines.append("---")
        lines.append("")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Analysis report (console)
# ---------------------------------------------------------------------------

def print_analysis(
    patterns: list[FailurePattern],
    lang: str,
    log_sources: list[str],
    total_entries: int,
) -> None:
    """Print failure analysis to stdout."""
    t = TEMPLATES.get(lang, TEMPLATES["en"])

    print(f"\n{'=' * 60}")
    print(f"  {t['analysis_title']}")
    print(f"{'=' * 60}")
    print(f"  {t['source_logs']}: {len(log_sources)}")
    print(f"  {t['total_entries']}: {total_entries}")
    print(f"  {t['unique_patterns']}: {len(patterns)}")
    print(f"{'=' * 60}\n")

    if not patterns:
        print(f"  {t['no_patterns']}\n")
        return

    print(f"  {t['top_failures']}:\n")
    for i, p in enumerate(patterns[:15], 1):
        sev = {"high": t["high"], "medium": t["medium"], "low": t["low"]}.get(p.severity, p.severity)
        print(f"  {i:3d}. [{sev:>7s}] x{p.occurrences:<4d}  {p.signature[:70]}")
        if p.sample_messages:
            print(f"       -> {p.sample_messages[0][:80]}")
    print()


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="training_generator",
        description="Generate maintenance procedures from machine logs. "
                    "Reads syslog, CSV, JSON log files, extracts failure patterns, "
                    "and outputs step-by-step procedures in Markdown.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""Examples:
  python3 training_generator.py generate --logs /var/log/machines/ --lang fr --output procedure.md
  python3 training_generator.py analyze  --logs ./errors.csv
  python3 training_generator.py generate --logs ./logs/ --lang de --min-occurrences 3
""",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    # generate
    gen = sub.add_parser("generate", help="Generate maintenance procedure document from logs")
    gen.add_argument("--logs", required=True, help="Path to log file or directory of log files")
    gen.add_argument("--lang", choices=["fr", "en", "de"], default="en", help="Output language (default: en)")
    gen.add_argument("--output", "-o", help="Output Markdown file (default: stdout)")
    gen.add_argument("--min-occurrences", type=int, default=2,
                     help="Minimum occurrences for a pattern to be included (default: 2)")

    # analyze
    ana = sub.add_parser("analyze", help="Analyze logs and show failure pattern summary")
    ana.add_argument("--logs", required=True, help="Path to log file or directory of log files")
    ana.add_argument("--lang", choices=["fr", "en", "de"], default="en", help="Output language (default: en)")
    ana.add_argument("--min-occurrences", type=int, default=2,
                     help="Minimum occurrences for a pattern to be included (default: 2)")

    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")

    # Collect and parse logs
    log_files = collect_log_files(args.logs)
    if not log_files:
        logger.error("No log files found at: %s", args.logs)
        sys.exit(1)

    logger.info("Found %d log file(s)", len(log_files))
    all_entries: list[LogEntry] = []
    for lf in log_files:
        entries = parse_log_file(lf)
        logger.info("  %s: %d entries", Path(lf).name, len(entries))
        all_entries.extend(entries)

    if not all_entries:
        logger.error("No log entries parsed from %d file(s)", len(log_files))
        sys.exit(1)

    # Extract patterns
    patterns = extract_failure_patterns(all_entries, min_occurrences=args.min_occurrences)
    logger.info("Detected %d failure pattern(s)", len(patterns))

    if args.command == "analyze":
        print_analysis(patterns, args.lang, log_files, len(all_entries))
    elif args.command == "generate":
        md = generate_procedure_markdown(patterns, args.lang, log_files, len(all_entries))
        if args.output:
            Path(args.output).write_text(md, encoding="utf-8")
            logger.info("Procedure written to %s", args.output)
        else:
            print(md)


if __name__ == "__main__":
    main()
