#!/usr/bin/env python3
"""
rag_ingestor.py — Ingest machine manuals into Qdrant RAG.

Reads PDF files, chunks text into ~500 token segments with overlap,
embeds via Ollama nomic-embed-text, and stores in Qdrant collection.

Usage:
    python3 rag_ingestor.py ingest  --pdf /path/to/manual.pdf --collection factory-rag
    python3 rag_ingestor.py search  --query "how to replace bearing" --collection factory-rag
    python3 rag_ingestor.py status  --collection factory-rag

Dependencies (optional, with fallbacks):
    pip install pypdf2 qdrant-client requests
    # or: pip install pdfplumber qdrant-client requests

Part of Kill_LIFE tools/industrial — usable standalone for any project.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import logging
import os
import re
import subprocess
import sys
import uuid
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
OLLAMA_EMBED_MODEL = os.getenv("OLLAMA_EMBED_MODEL", "nomic-embed-text")
QDRANT_URL = os.getenv("QDRANT_URL", "http://localhost:6333")
QDRANT_API_KEY = os.getenv("QDRANT_API_KEY", "")
DEFAULT_COLLECTION = "factory-rag"
CHUNK_SIZE = 500  # approximate tokens (chars / 4)
CHUNK_OVERLAP = 50  # overlap in tokens
EMBEDDING_DIM = 768  # nomic-embed-text dimension

# ---------------------------------------------------------------------------
# PDF text extraction (with fallbacks)
# ---------------------------------------------------------------------------


def extract_text_pypdf2(pdf_path: str) -> str:
    """Extract text using PyPDF2."""
    from PyPDF2 import PdfReader  # type: ignore
    reader = PdfReader(pdf_path)
    pages: list[str] = []
    for page in reader.pages:
        text = page.extract_text()
        if text:
            pages.append(text)
    return "\n\n".join(pages)


def extract_text_pdfplumber(pdf_path: str) -> str:
    """Extract text using pdfplumber."""
    import pdfplumber  # type: ignore
    pages: list[str] = []
    with pdfplumber.open(pdf_path) as pdf:
        for page in pdf.pages:
            text = page.extract_text()
            if text:
                pages.append(text)
    return "\n\n".join(pages)


def extract_text_pdftotext(pdf_path: str) -> str:
    """Extract text using system pdftotext command."""
    result = subprocess.run(
        ["pdftotext", "-layout", pdf_path, "-"],
        capture_output=True, text=True, timeout=120,
    )
    if result.returncode != 0:
        raise RuntimeError(f"pdftotext failed: {result.stderr}")
    return result.stdout


def extract_pdf_text(pdf_path: str) -> str:
    """Try multiple PDF extraction methods with fallbacks."""
    errors: list[str] = []

    for name, func in [
        ("PyPDF2", extract_text_pypdf2),
        ("pdfplumber", extract_text_pdfplumber),
        ("pdftotext", extract_text_pdftotext),
    ]:
        try:
            text = func(pdf_path)
            if text.strip():
                logger.info("PDF extracted with %s (%d chars)", name, len(text))
                return text
            errors.append(f"{name}: empty output")
        except ImportError:
            errors.append(f"{name}: not installed")
        except FileNotFoundError:
            errors.append(f"{name}: command not found")
        except Exception as exc:
            errors.append(f"{name}: {exc}")

    raise RuntimeError(
        f"Could not extract text from {pdf_path}. Tried: {'; '.join(errors)}\n"
        "Install one of: pip install pypdf2 | pip install pdfplumber | apt install poppler-utils"
    )


# ---------------------------------------------------------------------------
# Text chunking
# ---------------------------------------------------------------------------

@dataclass
class TextChunk:
    """A chunk of text with metadata."""
    text: str
    chunk_index: int
    source_file: str
    char_offset: int = 0
    chunk_id: str = ""

    def __post_init__(self) -> None:
        if not self.chunk_id:
            h = hashlib.md5(f"{self.source_file}:{self.chunk_index}:{self.text[:50]}".encode()).hexdigest()[:12]
            self.chunk_id = f"chunk-{h}"


def chunk_text(text: str, source_file: str, chunk_size: int = CHUNK_SIZE, overlap: int = CHUNK_OVERLAP) -> list[TextChunk]:
    """Split text into overlapping chunks of approximately chunk_size tokens."""
    # Approximate: 1 token ~= 4 chars
    char_chunk = chunk_size * 4
    char_overlap = overlap * 4

    # Clean text
    text = re.sub(r"\n{3,}", "\n\n", text)
    text = re.sub(r" {2,}", " ", text)

    if len(text) <= char_chunk:
        return [TextChunk(text=text.strip(), chunk_index=0, source_file=source_file)]

    chunks: list[TextChunk] = []
    start = 0
    idx = 0
    while start < len(text):
        end = start + char_chunk
        # Try to break at paragraph or sentence boundary
        if end < len(text):
            # Look for paragraph break near end
            para_break = text.rfind("\n\n", start + char_chunk // 2, end + char_overlap)
            if para_break > start:
                end = para_break
            else:
                # Look for sentence break
                sent_break = text.rfind(". ", start + char_chunk // 2, end + char_overlap)
                if sent_break > start:
                    end = sent_break + 1

        chunk_text_str = text[start:end].strip()
        if chunk_text_str:
            chunks.append(TextChunk(
                text=chunk_text_str,
                chunk_index=idx,
                source_file=source_file,
                char_offset=start,
            ))
            idx += 1
        start = end - char_overlap if end < len(text) else len(text)

    return chunks


# ---------------------------------------------------------------------------
# Ollama embedding
# ---------------------------------------------------------------------------

def _ollama_embed(texts: list[str], model: str = OLLAMA_EMBED_MODEL) -> list[list[float]]:
    """Get embeddings from Ollama API."""
    import requests  # type: ignore

    url = f"{OLLAMA_BASE_URL}/api/embed"
    # Ollama /api/embed accepts a single prompt or list
    all_embeddings: list[list[float]] = []

    # Process in batches to avoid huge payloads
    batch_size = 16
    for i in range(0, len(texts), batch_size):
        batch = texts[i:i + batch_size]
        resp = requests.post(url, json={"model": model, "input": batch}, timeout=120)
        resp.raise_for_status()
        data = resp.json()
        embeddings = data.get("embeddings", [])
        if not embeddings:
            # Fallback: single-prompt mode
            for text in batch:
                r = requests.post(url, json={"model": model, "input": text}, timeout=60)
                r.raise_for_status()
                d = r.json()
                emb = d.get("embeddings", [d.get("embedding", [])])
                all_embeddings.append(emb[0] if emb else [0.0] * EMBEDDING_DIM)
            continue
        all_embeddings.extend(embeddings)

    return all_embeddings


# ---------------------------------------------------------------------------
# Qdrant operations
# ---------------------------------------------------------------------------

def _get_qdrant_client(url: str = QDRANT_URL, api_key: str = QDRANT_API_KEY):
    """Get a Qdrant client instance."""
    from qdrant_client import QdrantClient  # type: ignore
    kwargs = {"url": url, "timeout": 30}
    if api_key:
        kwargs["api_key"] = api_key
    return QdrantClient(**kwargs)


def ensure_collection(collection: str, dim: int = EMBEDDING_DIM) -> None:
    """Create Qdrant collection if it doesn't exist."""
    from qdrant_client.models import Distance, VectorParams  # type: ignore

    client = _get_qdrant_client()
    collections = [c.name for c in client.get_collections().collections]
    if collection not in collections:
        client.create_collection(
            collection_name=collection,
            vectors_config=VectorParams(size=dim, distance=Distance.COSINE),
        )
        logger.info("Created collection '%s' (dim=%d, cosine)", collection, dim)
    else:
        logger.info("Collection '%s' already exists", collection)


def upsert_chunks(chunks: list[TextChunk], embeddings: list[list[float]], collection: str) -> int:
    """Upsert embedded chunks into Qdrant."""
    from qdrant_client.models import PointStruct  # type: ignore

    client = _get_qdrant_client()
    points = []
    for chunk, emb in zip(chunks, embeddings):
        point_id = str(uuid.uuid5(uuid.NAMESPACE_URL, chunk.chunk_id))
        points.append(PointStruct(
            id=point_id,
            vector=emb,
            payload={
                "text": chunk.text,
                "source_file": chunk.source_file,
                "chunk_index": chunk.chunk_index,
                "char_offset": chunk.char_offset,
                "chunk_id": chunk.chunk_id,
            },
        ))

    # Upsert in batches
    batch_size = 64
    for i in range(0, len(points), batch_size):
        client.upsert(collection_name=collection, points=points[i:i + batch_size])

    return len(points)


def search_collection(query: str, collection: str, top_k: int = 5) -> list[dict]:
    """Search Qdrant collection with a natural language query."""
    embeddings = _ollama_embed([query])
    if not embeddings or not embeddings[0]:
        raise RuntimeError("Failed to embed query")

    client = _get_qdrant_client()
    results = client.search(
        collection_name=collection,
        query_vector=embeddings[0],
        limit=top_k,
    )

    hits: list[dict] = []
    for r in results:
        hits.append({
            "score": round(r.score, 4),
            "text": r.payload.get("text", "")[:500],
            "source_file": r.payload.get("source_file", ""),
            "chunk_index": r.payload.get("chunk_index", 0),
        })
    return hits


def collection_status(collection: str) -> dict:
    """Get collection status and stats."""
    client = _get_qdrant_client()
    try:
        info = client.get_collection(collection_name=collection)
        return {
            "collection": collection,
            "points_count": info.points_count,
            "vectors_count": info.vectors_count,
            "status": str(info.status),
            "config": {
                "vector_size": info.config.params.vectors.size if hasattr(info.config.params.vectors, "size") else "unknown",
                "distance": str(info.config.params.vectors.distance) if hasattr(info.config.params.vectors, "distance") else "unknown",
            },
        }
    except Exception as exc:
        return {"collection": collection, "error": str(exc)}


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="rag_ingestor",
        description="Ingest machine manuals (PDF) into Qdrant RAG. "
                    "Chunks text, embeds via Ollama nomic-embed-text, stores in Qdrant.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""Examples:
  python3 rag_ingestor.py ingest  --pdf /path/to/manual.pdf --collection factory-rag
  python3 rag_ingestor.py ingest  --pdf /path/to/manuals/ --collection factory-rag
  python3 rag_ingestor.py search  --query "how to replace bearing" --collection factory-rag
  python3 rag_ingestor.py status  --collection factory-rag

Environment variables:
  OLLAMA_BASE_URL    Ollama API URL (default: http://localhost:11434)
  OLLAMA_EMBED_MODEL Embedding model (default: nomic-embed-text)
  QDRANT_URL         Qdrant URL (default: http://localhost:6333)
  QDRANT_API_KEY     Qdrant API key (optional)
""",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    # ingest
    ing = sub.add_parser("ingest", help="Ingest PDF(s) into Qdrant collection")
    ing.add_argument("--pdf", required=True, help="Path to PDF file or directory of PDFs")
    ing.add_argument("--collection", default=DEFAULT_COLLECTION, help=f"Qdrant collection name (default: {DEFAULT_COLLECTION})")
    ing.add_argument("--chunk-size", type=int, default=CHUNK_SIZE, help=f"Chunk size in tokens (default: {CHUNK_SIZE})")
    ing.add_argument("--chunk-overlap", type=int, default=CHUNK_OVERLAP, help=f"Chunk overlap in tokens (default: {CHUNK_OVERLAP})")
    ing.add_argument("--dry-run", action="store_true", help="Extract and chunk only, don't embed or store")

    # search
    sea = sub.add_parser("search", help="Search collection with natural language query")
    sea.add_argument("--query", required=True, help="Search query")
    sea.add_argument("--collection", default=DEFAULT_COLLECTION, help=f"Qdrant collection name (default: {DEFAULT_COLLECTION})")
    sea.add_argument("--top-k", type=int, default=5, help="Number of results (default: 5)")

    # status
    sta = sub.add_parser("status", help="Show collection status and stats")
    sta.add_argument("--collection", default=DEFAULT_COLLECTION, help=f"Qdrant collection name (default: {DEFAULT_COLLECTION})")

    return parser


def cmd_ingest(args: argparse.Namespace) -> None:
    """Ingest PDF files into Qdrant."""
    pdf_path = Path(args.pdf)
    if pdf_path.is_file():
        pdf_files = [pdf_path]
    elif pdf_path.is_dir():
        pdf_files = sorted(pdf_path.rglob("*.pdf"))
    else:
        logger.error("Path not found: %s", args.pdf)
        sys.exit(1)

    if not pdf_files:
        logger.error("No PDF files found at: %s", args.pdf)
        sys.exit(1)

    logger.info("Found %d PDF file(s)", len(pdf_files))

    all_chunks: list[TextChunk] = []
    for pdf_file in pdf_files:
        logger.info("Extracting text from: %s", pdf_file.name)
        try:
            text = extract_pdf_text(str(pdf_file))
        except RuntimeError as exc:
            logger.error("  %s", exc)
            continue

        chunks = chunk_text(text, str(pdf_file), args.chunk_size, args.chunk_overlap)
        logger.info("  -> %d chunks (%d chars)", len(chunks), len(text))
        all_chunks.extend(chunks)

    if not all_chunks:
        logger.error("No text extracted from any PDF")
        sys.exit(1)

    logger.info("Total chunks to ingest: %d", len(all_chunks))

    if args.dry_run:
        print(f"\n[DRY RUN] Would ingest {len(all_chunks)} chunks into '{args.collection}'")
        print(f"\nSample chunks:")
        for c in all_chunks[:3]:
            print(f"\n--- Chunk {c.chunk_index} from {Path(c.source_file).name} ---")
            print(c.text[:300] + ("..." if len(c.text) > 300 else ""))
        return

    # Embed
    logger.info("Embedding %d chunks with %s ...", len(all_chunks), OLLAMA_EMBED_MODEL)
    texts = [c.text for c in all_chunks]
    try:
        embeddings = _ollama_embed(texts)
    except Exception as exc:
        logger.error("Embedding failed: %s", exc)
        logger.error("Make sure Ollama is running with model '%s'", OLLAMA_EMBED_MODEL)
        sys.exit(1)

    if len(embeddings) != len(all_chunks):
        logger.error("Embedding count mismatch: %d embeddings for %d chunks", len(embeddings), len(all_chunks))
        sys.exit(1)

    # Store
    logger.info("Storing in Qdrant collection '%s' ...", args.collection)
    try:
        ensure_collection(args.collection, dim=len(embeddings[0]))
        count = upsert_chunks(all_chunks, embeddings, args.collection)
        logger.info("Successfully ingested %d chunks", count)
    except Exception as exc:
        logger.error("Qdrant storage failed: %s", exc)
        logger.error("Make sure Qdrant is running at %s", QDRANT_URL)
        sys.exit(1)


def cmd_search(args: argparse.Namespace) -> None:
    """Search the Qdrant collection."""
    logger.info("Searching '%s' for: %s", args.collection, args.query)
    try:
        hits = search_collection(args.query, args.collection, args.top_k)
    except Exception as exc:
        logger.error("Search failed: %s", exc)
        sys.exit(1)

    if not hits:
        print("No results found.")
        return

    print(f"\n{'=' * 70}")
    print(f"  Search results for: {args.query}")
    print(f"  Collection: {args.collection} | Top {args.top_k}")
    print(f"{'=' * 70}\n")

    for i, hit in enumerate(hits, 1):
        print(f"  [{i}] Score: {hit['score']}  |  Source: {Path(hit['source_file']).name}  |  Chunk #{hit['chunk_index']}")
        print(f"  {'-' * 66}")
        # Wrap text nicely
        text = hit["text"].replace("\n", " ")
        print(f"  {text[:400]}")
        print()


def cmd_status(args: argparse.Namespace) -> None:
    """Show collection status."""
    try:
        info = collection_status(args.collection)
    except Exception as exc:
        logger.error("Status check failed: %s", exc)
        sys.exit(1)

    print(json.dumps(info, indent=2))


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")

    if args.command == "ingest":
        cmd_ingest(args)
    elif args.command == "search":
        cmd_search(args)
    elif args.command == "status":
        cmd_status(args)


if __name__ == "__main__":
    main()
