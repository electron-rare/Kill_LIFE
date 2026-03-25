#!/usr/bin/env python3
"""
STT Pipeline — FREE alternative to paid speech-to-text APIs (T-MS-021).

Transcribes audio to text and extracts action items, using local engines
with graceful fallback:

    1. whisper.cpp  (fastest, via subprocess — requires compiled binary)
    2. openai-whisper (Python, GPU-accelerated)
    3. vosk          (lightweight, CPU-only, offline)

Usage:
    # Transcribe audio
    python3 stt_pipeline.py transcribe --audio meeting.wav --output transcript.md

    # Extract action items from transcript
    python3 stt_pipeline.py actions --transcript transcript.md --output actions.json

    # Full pipeline (transcribe + extract)
    python3 stt_pipeline.py full --audio meeting.wav --output-dir results/
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

# ---------------------------------------------------------------------------
# Transcription backends
# ---------------------------------------------------------------------------

def _find_whisper_cpp() -> Optional[str]:
    """Locate whisper.cpp main binary."""
    import shutil

    # Check common locations
    candidates = [
        os.environ.get("WHISPER_CPP_BIN", ""),
        "whisper-cpp",
        "main",  # default binary name in whisper.cpp build
        str(Path.home() / "whisper.cpp" / "main"),
        "/usr/local/bin/whisper-cpp",
    ]
    for c in candidates:
        if c and shutil.which(c):
            return c
    return None


def _find_whisper_cpp_model() -> Optional[str]:
    """Locate a whisper.cpp GGML model file."""
    search_dirs = [
        Path(os.environ.get("WHISPER_CPP_MODELS", "")),
        Path.home() / "whisper.cpp" / "models",
        Path.home() / ".cache" / "whisper-cpp",
        Path("/usr/local/share/whisper-cpp/models"),
    ]
    preferred = ["ggml-base.en.bin", "ggml-base.bin", "ggml-small.en.bin", "ggml-small.bin"]

    for d in search_dirs:
        if not d.is_dir():
            continue
        for name in preferred:
            p = d / name
            if p.exists():
                return str(p)
        # Any .bin file
        bins = list(d.glob("ggml-*.bin"))
        if bins:
            return str(bins[0])
    return None


def transcribe_whisper_cpp(audio_path: Path, model_path: Optional[str] = None) -> str:
    """Transcribe using whisper.cpp subprocess."""
    binary = _find_whisper_cpp()
    if not binary:
        raise RuntimeError(
            "whisper.cpp not found. Install from https://github.com/ggerganov/whisper.cpp\n"
            "  or set WHISPER_CPP_BIN=/path/to/main"
        )

    model = model_path or _find_whisper_cpp_model()
    if not model:
        raise RuntimeError(
            "No whisper.cpp model found. Download one:\n"
            "  cd ~/whisper.cpp && bash ./models/download-ggml-model.sh base.en\n"
            "  or set WHISPER_CPP_MODELS=/path/to/models/"
        )

    # whisper.cpp expects 16kHz WAV; convert if needed
    wav_path = _ensure_wav_16k(audio_path)

    with tempfile.NamedTemporaryFile(suffix=".txt", delete=False) as tmp:
        tmp_out = tmp.name

    try:
        cmd = [binary, "-m", model, "-f", str(wav_path), "-otxt", "-of", tmp_out.replace(".txt", "")]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
        if result.returncode != 0:
            raise RuntimeError(f"whisper.cpp failed: {result.stderr[:500]}")
        return Path(tmp_out).read_text(encoding="utf-8")
    finally:
        Path(tmp_out).unlink(missing_ok=True)
        if wav_path != audio_path:
            wav_path.unlink(missing_ok=True)


def transcribe_openai_whisper(audio_path: Path, model_size: str = "base") -> str:
    """Transcribe using openai-whisper Python package."""
    try:
        import whisper
    except ImportError:
        raise RuntimeError("openai-whisper not installed: pip install openai-whisper")

    model = whisper.load_model(model_size)
    result = model.transcribe(str(audio_path))
    return result["text"]


def transcribe_vosk(audio_path: Path, model_path: Optional[str] = None) -> str:
    """Transcribe using Vosk (lightweight, CPU-only)."""
    try:
        from vosk import Model, KaldiRecognizer
    except ImportError:
        raise RuntimeError("vosk not installed: pip install vosk")

    import wave

    wav_path = _ensure_wav_16k(audio_path)

    if model_path:
        model = Model(model_path)
    else:
        # Vosk auto-downloads a small model
        try:
            model = Model(lang="en-us")
        except Exception:
            raise RuntimeError(
                "No Vosk model found. Download from https://alphacephei.com/vosk/models\n"
                "  or: pip install vosk  (auto-downloads small model)"
            )

    wf = wave.open(str(wav_path), "rb")
    if wf.getnchannels() != 1 or wf.getsampwidth() != 2 or wf.getframerate() != 16000:
        wf.close()
        raise RuntimeError("Audio must be mono 16kHz 16-bit WAV for Vosk")

    rec = KaldiRecognizer(model, 16000)
    rec.SetWords(True)

    texts: List[str] = []
    while True:
        data = wf.readframes(4000)
        if len(data) == 0:
            break
        if rec.AcceptWaveform(data):
            res = json.loads(rec.Result())
            if res.get("text"):
                texts.append(res["text"])

    final = json.loads(rec.FinalResult())
    if final.get("text"):
        texts.append(final["text"])

    wf.close()
    if wav_path != audio_path:
        wav_path.unlink(missing_ok=True)

    return " ".join(texts)


# ---------------------------------------------------------------------------
# Audio format helper
# ---------------------------------------------------------------------------
def _ensure_wav_16k(audio_path: Path) -> Path:
    """Convert audio to 16kHz mono WAV if needed (requires ffmpeg)."""
    import shutil

    if audio_path.suffix.lower() == ".wav":
        # Quick check — might already be 16k mono
        return audio_path

    if not shutil.which("ffmpeg"):
        print("  WARN: ffmpeg not found, hoping input is already valid WAV")
        return audio_path

    tmp = Path(tempfile.mktemp(suffix=".wav"))
    subprocess.run(
        ["ffmpeg", "-y", "-i", str(audio_path), "-ar", "16000", "-ac", "1", "-f", "wav", str(tmp)],
        capture_output=True,
        timeout=120,
    )
    return tmp


# ---------------------------------------------------------------------------
# Transcription dispatcher with fallback
# ---------------------------------------------------------------------------
BACKENDS = [
    ("whisper_cpp", transcribe_whisper_cpp),
    ("openai_whisper", transcribe_openai_whisper),
    ("vosk", transcribe_vosk),
]


def transcribe(audio_path: Path, backend: Optional[str] = None) -> Tuple[str, str]:
    """Transcribe audio. Returns (text, backend_used)."""
    if backend:
        for name, fn in BACKENDS:
            if name == backend:
                return fn(audio_path), name
        sys.exit(f"ERROR: unknown backend '{backend}'. Choose from: {[b[0] for b in BACKENDS]}")

    errors: List[str] = []
    for name, fn in BACKENDS:
        try:
            text = fn(audio_path)
            if text.strip():
                return text, name
            errors.append(f"{name}: empty output")
        except Exception as exc:
            errors.append(f"{name}: {exc}")

    sys.exit(
        f"ERROR: all STT backends failed for {audio_path.name}:\n"
        + "\n".join(f"  - {e}" for e in errors)
    )


# ---------------------------------------------------------------------------
# Action item extraction (regex-based, no LLM)
# ---------------------------------------------------------------------------
ACTION_PATTERNS = [
    # "TODO: ..."
    re.compile(r"(?:TODO|FIXME|ACTION|A[Cc]tion\s*[Ii]tem)[:\s]+(.+?)(?:\.|$)", re.MULTILINE),
    # "we need to ..."
    re.compile(r"(?:we\s+(?:need|should|must|have)\s+to|il\s+faut)\s+(.+?)(?:\.|$)", re.IGNORECASE),
    # "X will ..." / "X va ..."
    re.compile(r"(\w+)\s+(?:will|va|doit)\s+(.+?)(?:\.|$)", re.IGNORECASE),
    # "let's ..." / "on va ..."
    re.compile(r"(?:let'?s|on\s+va)\s+(.+?)(?:\.|$)", re.IGNORECASE),
    # Deadline patterns
    re.compile(r"(?:deadline|before|by|avant)\s+(\w+\s+\d+|\d{4}-\d{2}-\d{2})", re.IGNORECASE),
]


def extract_actions(text: str) -> List[Dict[str, str]]:
    """Extract action items from transcript text."""
    actions: List[Dict[str, str]] = []
    seen: set = set()

    for pattern in ACTION_PATTERNS:
        for match in pattern.finditer(text):
            full = match.group(0).strip()
            if full and full not in seen:
                seen.add(full)
                actions.append({
                    "action": full,
                    "context": _get_context(text, match.start(), window=100),
                })

    return actions


def _get_context(text: str, pos: int, window: int = 100) -> str:
    """Get surrounding text for context."""
    start = max(0, pos - window)
    end = min(len(text), pos + window)
    return text[start:end].strip()


# ---------------------------------------------------------------------------
# Output formatters
# ---------------------------------------------------------------------------
def format_transcript_md(text: str, audio_name: str, backend: str) -> str:
    """Format transcript as markdown."""
    now = datetime.now().strftime("%Y-%m-%d %H:%M")
    return (
        f"# Transcript: {audio_name}\n\n"
        f"- **Date**: {now}\n"
        f"- **Backend**: {backend}\n"
        f"- **Length**: {len(text)} chars\n\n"
        f"---\n\n"
        f"{text}\n"
    )


# ---------------------------------------------------------------------------
# CLI commands
# ---------------------------------------------------------------------------
def cmd_transcribe(args):
    """Transcribe audio to text."""
    if not args.audio.exists():
        sys.exit(f"ERROR: file not found: {args.audio}")

    print(f"  Transcribing {args.audio.name} ...")
    text, backend = transcribe(args.audio, getattr(args, "backend", None))
    print(f"    Backend: {backend} | {len(text)} chars")

    md = format_transcript_md(text, args.audio.name, backend)
    out = args.output or Path(args.audio.stem + "_transcript.md")
    out.write_text(md, encoding="utf-8")
    print(f"  -> {out}")


def cmd_actions(args):
    """Extract action items from a transcript."""
    if not args.transcript.exists():
        sys.exit(f"ERROR: file not found: {args.transcript}")

    text = args.transcript.read_text(encoding="utf-8")
    print(f"  Extracting actions from {args.transcript.name} ({len(text)} chars) ...")

    actions = extract_actions(text)
    print(f"    Found {len(actions)} action items")

    result = {
        "source": str(args.transcript),
        "extracted_at": datetime.now().isoformat(),
        "actions": actions,
    }

    out = args.output or Path(args.transcript.stem + "_actions.json")
    out.write_text(json.dumps(result, indent=2, ensure_ascii=False))
    print(f"  -> {out}")


def cmd_full(args):
    """Full pipeline: transcribe + extract actions."""
    if not args.audio.exists():
        sys.exit(f"ERROR: file not found: {args.audio}")

    out_dir = args.output_dir or Path(".")
    out_dir.mkdir(parents=True, exist_ok=True)

    # Transcribe
    print(f"  Transcribing {args.audio.name} ...")
    text, backend = transcribe(args.audio, getattr(args, "backend", None))
    print(f"    Backend: {backend} | {len(text)} chars")

    md = format_transcript_md(text, args.audio.name, backend)
    transcript_path = out_dir / (args.audio.stem + "_transcript.md")
    transcript_path.write_text(md, encoding="utf-8")
    print(f"  -> {transcript_path}")

    # Actions
    actions = extract_actions(text)
    print(f"    Found {len(actions)} action items")

    result = {
        "source": str(args.audio),
        "backend": backend,
        "extracted_at": datetime.now().isoformat(),
        "actions": actions,
    }
    actions_path = out_dir / (args.audio.stem + "_actions.json")
    actions_path.write_text(json.dumps(result, indent=2, ensure_ascii=False))
    print(f"  -> {actions_path}")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(
        description="STT pipeline — free, local speech-to-text + action extraction",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    sub = parser.add_subparsers(dest="command")

    # transcribe
    p_tr = sub.add_parser("transcribe", help="Transcribe audio to text")
    p_tr.add_argument("--audio", type=Path, required=True)
    p_tr.add_argument("--output", type=Path)
    p_tr.add_argument("--backend", choices=["whisper_cpp", "openai_whisper", "vosk"])
    p_tr.set_defaults(func=cmd_transcribe)

    # actions
    p_ac = sub.add_parser("actions", help="Extract action items from transcript")
    p_ac.add_argument("--transcript", type=Path, required=True)
    p_ac.add_argument("--output", type=Path)
    p_ac.set_defaults(func=cmd_actions)

    # full
    p_fu = sub.add_parser("full", help="Transcribe + extract actions")
    p_fu.add_argument("--audio", type=Path, required=True)
    p_fu.add_argument("--output-dir", type=Path)
    p_fu.add_argument("--backend", choices=["whisper_cpp", "openai_whisper", "vosk"])
    p_fu.set_defaults(func=cmd_full)

    args = parser.parse_args()
    if not args.command:
        parser.print_help()
        sys.exit(1)

    args.func(args)


if __name__ == "__main__":
    main()
