#!/usr/bin/env python3
"""
OCR Pipeline — FREE alternative to Mistral's document parsing API (T-MS-020).

Extracts text and structured component specs from PDF datasheets using
local/open-source tools, with graceful fallback chain:

    1. marker-pdf  (best quality, GPU-accelerated)
    2. surya-ocr   (good quality, lighter)
    3. PyPDF2      (text-layer only, no OCR)

Usage:
    # Single PDF
    python3 ocr_pipeline.py --pdf datasheet.pdf --output specs.json

    # Batch directory
    python3 ocr_pipeline.py --dir datasheets/ --output-dir specs/

    # Force a specific backend
    python3 ocr_pipeline.py --pdf datasheet.pdf --backend pypdf2 --output specs.json
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import tempfile
from pathlib import Path
from typing import Any, Dict, List, Optional

# ---------------------------------------------------------------------------
# Backend: marker-pdf
# ---------------------------------------------------------------------------
def _ocr_marker(pdf_path: Path) -> str:
    """Use marker-pdf to convert PDF to markdown text."""
    try:
        from marker.converters.pdf import PdfConverter
        from marker.models import create_model_dict
    except ImportError:
        raise RuntimeError("marker-pdf not installed: pip install marker-pdf")

    models = create_model_dict()
    converter = PdfConverter(artifact_dict=models)
    rendered = converter(str(pdf_path))
    return rendered.markdown


def _ocr_marker_cli(pdf_path: Path) -> str:
    """Fallback: call marker CLI as subprocess."""
    import subprocess

    with tempfile.TemporaryDirectory() as tmp:
        result = subprocess.run(
            ["marker_single", str(pdf_path), tmp, "--batch_multiplier", "2"],
            capture_output=True,
            text=True,
            timeout=300,
        )
        if result.returncode != 0:
            raise RuntimeError(f"marker_single failed: {result.stderr[:500]}")
        # marker writes a .md file in the output dir
        md_files = list(Path(tmp).rglob("*.md"))
        if not md_files:
            raise RuntimeError("marker produced no output")
        return md_files[0].read_text(encoding="utf-8")


# ---------------------------------------------------------------------------
# Backend: surya-ocr
# ---------------------------------------------------------------------------
def _ocr_surya(pdf_path: Path) -> str:
    """Use surya for OCR."""
    try:
        from surya.ocr import run_ocr
        from surya.model.detection.model import load_model as load_det_model
        from surya.model.detection.processor import load_processor as load_det_proc
        from surya.model.recognition.model import load_model as load_rec_model
        from surya.model.recognition.processor import load_processor as load_rec_proc
        from surya.input.load import load_from_file
    except ImportError:
        raise RuntimeError("surya-ocr not installed: pip install surya-ocr")

    det_model = load_det_model()
    det_proc = load_det_proc()
    rec_model = load_rec_model()
    rec_proc = load_rec_proc()

    images, _ = load_from_file(str(pdf_path))
    langs = [["en"]] * len(images)

    results = run_ocr(
        images, langs, det_model, det_proc, rec_model, rec_proc
    )

    pages: List[str] = []
    for page_result in results:
        lines = [line.text for line in page_result.text_lines]
        pages.append("\n".join(lines))
    return "\n\n---\n\n".join(pages)


# ---------------------------------------------------------------------------
# Backend: PyPDF2 (text-layer only, no OCR)
# ---------------------------------------------------------------------------
def _ocr_pypdf2(pdf_path: Path) -> str:
    """Extract embedded text layer — no actual OCR."""
    try:
        from PyPDF2 import PdfReader
    except ImportError:
        try:
            from pypdf import PdfReader
        except ImportError:
            raise RuntimeError("PyPDF2/pypdf not installed: pip install pypdf")

    reader = PdfReader(str(pdf_path))
    pages: List[str] = []
    for page in reader.pages:
        text = page.extract_text()
        if text:
            pages.append(text)
    if not pages:
        raise RuntimeError("PDF has no embedded text layer (scanned image?)")
    return "\n\n---\n\n".join(pages)


# ---------------------------------------------------------------------------
# Backend dispatcher with fallback chain
# ---------------------------------------------------------------------------
BACKENDS = [
    ("marker", _ocr_marker),
    ("marker_cli", _ocr_marker_cli),
    ("surya", _ocr_surya),
    ("pypdf2", _ocr_pypdf2),
]


def extract_text(pdf_path: Path, backend: Optional[str] = None) -> tuple[str, str]:
    """
    Extract text from a PDF.  Returns (text, backend_used).
    Falls through the chain on failure unless a specific backend is requested.
    """
    if backend:
        # Direct backend selection
        for name, fn in BACKENDS:
            if name == backend:
                return fn(pdf_path), name
        sys.exit(f"ERROR: unknown backend '{backend}'. Choose from: {[b[0] for b in BACKENDS]}")

    errors: List[str] = []
    for name, fn in BACKENDS:
        try:
            text = fn(pdf_path)
            if text.strip():
                return text, name
            errors.append(f"{name}: empty output")
        except Exception as exc:
            errors.append(f"{name}: {exc}")

    sys.exit(
        f"ERROR: all OCR backends failed for {pdf_path.name}:\n"
        + "\n".join(f"  - {e}" for e in errors)
    )


# ---------------------------------------------------------------------------
# Structured spec extraction (regex-based, no LLM needed)
# ---------------------------------------------------------------------------
def extract_specs(text: str, filename: str = "") -> Dict[str, Any]:
    """
    Pull common component specs from OCR text via regex patterns.
    Returns a JSON-serialisable dict.
    """
    specs: Dict[str, Any] = {"source_file": filename}

    # Voltage ratings
    voltages = re.findall(
        r"(\d+(?:\.\d+)?)\s*(?:V(?:DC|AC|RMS)?|volts?)\b", text, re.IGNORECASE
    )
    if voltages:
        specs["voltages_V"] = sorted(set(float(v) for v in voltages))

    # Current ratings
    currents = re.findall(
        r"(\d+(?:\.\d+)?)\s*(?:m?A(?:DC|RMS)?|amps?)\b", text, re.IGNORECASE
    )
    if currents:
        specs["currents_A"] = sorted(set(float(c) for c in currents))

    # Temperature range
    temps = re.findall(
        r"(-?\d+)\s*(?:deg(?:ree)?s?\s*)?[°]?\s*C\b", text
    )
    if temps:
        t_vals = sorted(set(int(t) for t in temps))
        specs["temperature_range_C"] = {"min": t_vals[0], "max": t_vals[-1]}

    # Package / footprint
    packages = re.findall(
        r"\b(SOT-?\d+|QFP-?\d+|QFN-?\d+|BGA-?\d+|DIP-?\d+|SOIC-?\d+|TSSOP-?\d+|TO-?\d+)\b",
        text, re.IGNORECASE,
    )
    if packages:
        specs["packages"] = sorted(set(p.upper() for p in packages))

    # Part numbers (common patterns)
    parts = re.findall(
        r"\b([A-Z]{2,5}\d{3,}[A-Z0-9\-]*)\b", text
    )
    if parts:
        # Deduplicate and keep top 10
        seen = set()
        unique = []
        for p in parts:
            if p not in seen:
                seen.add(p)
                unique.append(p)
        specs["part_numbers"] = unique[:10]

    # Frequency / clock
    freqs = re.findall(
        r"(\d+(?:\.\d+)?)\s*(MHz|GHz|kHz)\b", text, re.IGNORECASE
    )
    if freqs:
        specs["frequencies"] = [
            {"value": float(v), "unit": u} for v, u in freqs
        ]

    # Memory sizes
    mem = re.findall(
        r"(\d+(?:\.\d+)?)\s*(KB|MB|GB|kB)\b", text, re.IGNORECASE
    )
    if mem:
        specs["memory"] = [{"value": float(v), "unit": u.upper()} for v, u in mem]

    return specs


# ---------------------------------------------------------------------------
# Process one PDF
# ---------------------------------------------------------------------------
def process_pdf(pdf_path: Path, backend: Optional[str] = None) -> Dict[str, Any]:
    """Full pipeline: OCR -> text -> structured specs."""
    print(f"  Processing {pdf_path.name} ...")
    text, used_backend = extract_text(pdf_path, backend)
    print(f"    Backend: {used_backend} | Extracted {len(text)} chars")

    specs = extract_specs(text, pdf_path.name)
    specs["_ocr_backend"] = used_backend
    specs["_text_length"] = len(text)
    # Optionally include raw text excerpt for debugging
    specs["_text_excerpt"] = text[:500] + ("..." if len(text) > 500 else "")
    return specs


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(
        description="OCR pipeline for component datasheets (free, local)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("--pdf", type=Path, help="Single PDF file")
    parser.add_argument("--dir", type=Path, help="Directory of PDFs (batch mode)")
    parser.add_argument("--output", type=Path, help="Output JSON file (single mode)")
    parser.add_argument("--output-dir", type=Path, help="Output directory (batch mode)")
    parser.add_argument(
        "--backend",
        choices=["marker", "marker_cli", "surya", "pypdf2"],
        help="Force a specific OCR backend (default: auto-fallback)",
    )

    args = parser.parse_args()

    if args.pdf:
        if not args.pdf.exists():
            sys.exit(f"ERROR: file not found: {args.pdf}")
        result = process_pdf(args.pdf, args.backend)
        out = args.output or Path(args.pdf.stem + "_specs.json")
        out.write_text(json.dumps(result, indent=2, ensure_ascii=False))
        print(f"  -> {out}")

    elif args.dir:
        if not args.dir.is_dir():
            sys.exit(f"ERROR: not a directory: {args.dir}")
        out_dir = args.output_dir or Path("specs")
        out_dir.mkdir(parents=True, exist_ok=True)

        pdfs = sorted(args.dir.glob("*.pdf"))
        if not pdfs:
            sys.exit(f"ERROR: no PDF files found in {args.dir}")

        print(f"  Found {len(pdfs)} PDFs in {args.dir}")
        all_specs: List[Dict[str, Any]] = []
        for pdf in pdfs:
            try:
                specs = process_pdf(pdf, args.backend)
                out_file = out_dir / (pdf.stem + "_specs.json")
                out_file.write_text(json.dumps(specs, indent=2, ensure_ascii=False))
                all_specs.append(specs)
            except Exception as exc:
                print(f"    WARN: failed on {pdf.name}: {exc}")

        # Summary file
        summary = out_dir / "_batch_summary.json"
        summary.write_text(json.dumps(all_specs, indent=2, ensure_ascii=False))
        print(f"\n  Batch complete: {len(all_specs)}/{len(pdfs)} succeeded -> {out_dir}")

    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
