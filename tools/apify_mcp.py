#!/usr/bin/env python3
"""Local MCP server for Apify web scraping — datasheets, components, forums, docs."""

from __future__ import annotations

import asyncio
import hashlib
import json
import os
import re
import sys
from pathlib import Path
from typing import Any

from mcp_stdio import (  # type: ignore
    PROTOCOL_VERSION,
    error_tool_result,
    make_error,
    make_response,
    ok_tool_result,
    read_message,
    write_message,
)

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

APIFY_TOKEN = os.getenv("APIFY_API_TOKEN", "")
APIFY_BASE = "https://api.apify.com/v2"
USER_AGENT = "Kill_LIFE-Apify-MCP/1.0"

# ---------------------------------------------------------------------------
# HTTP helpers (httpx with fallback to urllib)
# ---------------------------------------------------------------------------

try:
    import httpx

    async def _fetch(url: str, *, method: str = "GET", json_body: dict | None = None,
                     headers: dict | None = None, timeout: float = 60.0) -> dict | str:
        h = {"User-Agent": USER_AGENT, **(headers or {})}
        async with httpx.AsyncClient(timeout=timeout, follow_redirects=True) as c:
            if method == "POST":
                r = await c.post(url, json=json_body, headers=h)
            else:
                r = await c.get(url, headers=h)
            r.raise_for_status()
            try:
                return r.json()
            except Exception:
                return r.text

    async def _fetch_text(url: str, *, timeout: float = 30.0) -> str:
        async with httpx.AsyncClient(timeout=timeout, follow_redirects=True) as c:
            r = await c.get(url, headers={"User-Agent": USER_AGENT})
            r.raise_for_status()
            return r.text

except ImportError:
    import urllib.request

    async def _fetch(url: str, **_kw: Any) -> dict | str:
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=60) as resp:
            data = resp.read().decode()
            try:
                return json.loads(data)
            except Exception:
                return data

    async def _fetch_text(url: str, **_kw: Any) -> str:
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.read().decode()


# ---------------------------------------------------------------------------
# Apify helpers
# ---------------------------------------------------------------------------

async def _run_actor(actor_id: str, input_data: dict, timeout: float = 120.0) -> dict:
    """Run an Apify Actor and wait for results."""
    if not APIFY_TOKEN:
        raise RuntimeError("APIFY_API_TOKEN not set — set it in .env or environment")
    url = f"{APIFY_BASE}/acts/{actor_id}/runs?token={APIFY_TOKEN}&waitForFinish={int(timeout)}"
    result = await _fetch(url, method="POST", json_body=input_data, timeout=timeout + 10)
    if isinstance(result, dict) and result.get("data", {}).get("status") == "SUCCEEDED":
        dataset_id = result["data"].get("defaultDatasetId")
        if dataset_id:
            items = await _fetch(f"{APIFY_BASE}/datasets/{dataset_id}/items?token={APIFY_TOKEN}")
            return {"status": "ok", "items": items if isinstance(items, list) else [items]}
    return {"status": result.get("data", {}).get("status", "UNKNOWN"), "raw": result}


async def _direct_scrape(url: str) -> str:
    """Fallback: scrape a URL directly via httpx."""
    text = await _fetch_text(url, timeout=30)
    # Strip HTML tags for a rough text extraction
    clean = re.sub(r"<script[^>]*>.*?</script>", "", text, flags=re.DOTALL)
    clean = re.sub(r"<style[^>]*>.*?</style>", "", clean, flags=re.DOTALL)
    clean = re.sub(r"<[^>]+>", " ", clean)
    clean = re.sub(r"\s+", " ", clean).strip()
    return clean[:8000]  # Limit to 8K chars


# ---------------------------------------------------------------------------
# Tool implementations
# ---------------------------------------------------------------------------

TOOLS = [
    {
        "name": "scrape_datasheet",
        "description": "Scrape a component datasheet from a URL. Extracts text content from the page or PDF link.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "url": {"type": "string", "description": "URL of the datasheet page (e.g., ti.com, st.com, espressif.com)"},
                "component": {"type": "string", "description": "Component name/part number for context"},
            },
            "required": ["url"],
        },
    },
    {
        "name": "search_components",
        "description": "Search for electronic components — find alternatives, check availability, get specs.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Component search query (e.g., 'STM32F4 LQFP48 3.3V')"},
                "source": {
                    "type": "string",
                    "enum": ["lcsc", "octopart", "digikey"],
                    "description": "Search source (default: lcsc for JLCPCB compatibility)",
                },
            },
            "required": ["query"],
        },
    },
    {
        "name": "scrape_forum",
        "description": "Scrape electronics forum threads for technical knowledge (EEVBlog, StackOverflow Electronics, Reddit).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Search query for forum posts"},
                "source": {
                    "type": "string",
                    "enum": ["eevblog", "stackoverflow", "reddit"],
                    "description": "Forum to search (default: stackoverflow)",
                },
                "max_results": {"type": "integer", "description": "Max results (default: 5)"},
            },
            "required": ["query"],
        },
    },
    {
        "name": "scrape_docs",
        "description": "Scrape technical documentation (Espressif ESP-IDF, STM32 HAL, KiCad docs, PlatformIO).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "url": {"type": "string", "description": "Documentation URL to scrape"},
                "topic": {"type": "string", "description": "Topic to focus on (filters content)"},
            },
            "required": ["url"],
        },
    },
    {
        "name": "monitor_updates",
        "description": "Check a URL for updates since last visit. Useful for tracking component EOL notices, library updates.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "url": {"type": "string", "description": "URL to monitor"},
                "label": {"type": "string", "description": "Human label for this monitor (e.g., 'ESP32-S3 errata')"},
            },
            "required": ["url"],
        },
    },
    {
        "name": "feed_dataset",
        "description": "Format scraped data for Mascarade HuggingFace datasets (SPICE, KiCad, STM32, EMC).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "domain": {
                    "type": "string",
                    "enum": ["spice", "kicad", "stm32", "emc", "esp32", "pcb", "general"],
                    "description": "Target dataset domain",
                },
                "instruction": {"type": "string", "description": "The instruction/question"},
                "response": {"type": "string", "description": "The expected response/answer"},
                "source_url": {"type": "string", "description": "Source URL of the data"},
            },
            "required": ["domain", "instruction", "response"],
        },
    },
]


async def handle_scrape_datasheet(args: dict) -> str:
    url = args["url"]
    component = args.get("component", "")
    if APIFY_TOKEN:
        try:
            result = await _run_actor("apify/web-scraper", {
                "startUrls": [{"url": url}],
                "pageFunction": "async function pageFunction(context) { return { title: document.title, text: document.body.innerText.substring(0, 10000) }; }",
            })
            if result["status"] == "ok" and result.get("items"):
                item = result["items"][0] if isinstance(result["items"], list) else result["items"]
                return json.dumps({"component": component, "title": item.get("title", ""), "content": item.get("text", "")[:6000], "source": url})
        except Exception:
            pass
    # Fallback: direct scrape
    text = await _direct_scrape(url)
    return json.dumps({"component": component, "content": text[:6000], "source": url})


async def handle_search_components(args: dict) -> str:
    query = args["query"]
    source = args.get("source", "lcsc")
    search_urls = {
        "lcsc": f"https://www.lcsc.com/search?q={query.replace(' ', '+')}",
        "octopart": f"https://octopart.com/search?q={query.replace(' ', '+')}",
        "digikey": f"https://www.digikey.com/en/products/result?keywords={query.replace(' ', '+')}",
    }
    url = search_urls.get(source, search_urls["lcsc"])
    text = await _direct_scrape(url)
    return json.dumps({"query": query, "source": source, "url": url, "results": text[:4000]})


async def handle_scrape_forum(args: dict) -> str:
    query = args["query"]
    source = args.get("source", "stackoverflow")
    max_results = args.get("max_results", 5)
    if source == "stackoverflow":
        api_url = f"https://api.stackexchange.com/2.3/search/advanced?order=desc&sort=relevance&q={query.replace(' ', '+')}&site=electronics&pagesize={max_results}&filter=withbody"
        try:
            data = await _fetch(api_url)
            if isinstance(data, dict) and "items" in data:
                results = []
                for item in data["items"][:max_results]:
                    results.append({
                        "title": item.get("title", ""),
                        "link": item.get("link", ""),
                        "score": item.get("score", 0),
                        "answer_count": item.get("answer_count", 0),
                        "body": re.sub(r"<[^>]+>", "", item.get("body", ""))[:500],
                    })
                return json.dumps({"query": query, "source": source, "results": results})
        except Exception:
            pass
    # Fallback for eevblog/reddit
    search_urls = {
        "eevblog": f"https://www.eevblog.com/forum/index.php?action=search2;search={query.replace(' ', '+')}",
        "reddit": f"https://www.reddit.com/r/AskElectronics/search/?q={query.replace(' ', '+')}&restrict_sr=1",
    }
    url = search_urls.get(source, search_urls["eevblog"])
    text = await _direct_scrape(url)
    return json.dumps({"query": query, "source": source, "results": text[:4000]})


async def handle_scrape_docs(args: dict) -> str:
    url = args["url"]
    topic = args.get("topic", "")
    text = await _direct_scrape(url)
    if topic:
        # Filter paragraphs that mention the topic
        paragraphs = text.split(". ")
        relevant = [p for p in paragraphs if topic.lower() in p.lower()]
        if relevant:
            text = ". ".join(relevant[:20])
    return json.dumps({"url": url, "topic": topic, "content": text[:6000]})


async def handle_monitor_updates(args: dict) -> str:
    url = args["url"]
    label = args.get("label", url)
    cache_dir = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "apify-mcp" / "monitors"
    cache_dir.mkdir(parents=True, exist_ok=True)
    cache_file = cache_dir / re.sub(r"[^\w]", "_", url)[:100]
    text = await _direct_scrape(url)
    content_hash = hashlib.md5(text.encode()).hexdigest()
    changed = False
    if cache_file.exists():
        old_hash = cache_file.read_text().strip()
        changed = old_hash != content_hash
    cache_file.write_text(content_hash)
    return json.dumps({"url": url, "label": label, "changed": changed, "preview": text[:500]})


async def handle_feed_dataset(args: dict) -> str:
    domain = args["domain"]
    instruction = args["instruction"]
    response = args["response"]
    source_url = args.get("source_url", "")
    entry = {
        "instruction": instruction,
        "output": response,
        "domain": domain,
        "source": source_url,
    }
    # Append to local JSONL file
    dataset_dir = Path(os.environ.get("MASCARADE_DIR", ".")) / "datasets" / domain
    dataset_dir.mkdir(parents=True, exist_ok=True)
    dataset_file = dataset_dir / "scraped.jsonl"
    with open(dataset_file, "a") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    with open(dataset_file) as fcount:
        count = sum(1 for _ in fcount)
    return json.dumps({"status": "ok", "domain": domain, "file": str(dataset_file), "total_entries": count})


async def handle_get_runtime_info(_args: dict) -> str:
    apify_key = os.environ.get("APIFY_API_KEY", "")
    mode = "apify-api" if apify_key and len(apify_key) > 10 else "direct-scrape"
    return json.dumps({
        "ok": True,
        "mode": mode,
        "apify_key_configured": bool(apify_key),
        "tools": [t["name"] for t in TOOLS],
    })


async def handle_fetch_espressif_docs(args: dict) -> str:
    """Fetch Espressif ESP-IDF / ESP32 documentation for a given topic."""
    topic = args.get("topic", "")
    chip = args.get("chip", "esp32s3")
    base = f"https://docs.espressif.com/projects/esp-idf/en/latest/{chip}"
    url = args.get("url", base)
    return await handle_scrape_docs({"url": url, "topic": topic})


async def handle_fetch_platformio_registry(args: dict) -> str:
    """Fetch PlatformIO library registry entry for a library name or ID."""
    library = args.get("library", "")
    url = args.get("url", f"https://registry.platformio.org/search?q={library}")
    return await handle_scrape_docs({"url": url, "topic": library})


async def handle_fetch_kicad_library_info(args: dict) -> str:
    """Fetch KiCad component library information (symbols, footprints)."""
    component = args.get("component", "")
    url = args.get("url", f"https://www.kicad.org/libraries/search/?q={component}")
    return await handle_scrape_docs({"url": url, "topic": component})


async def handle_ingest_to_rag(args: dict) -> str:
    """Ingest scraped content into the Mascarade RAG pipeline."""
    collection = args.get("collection", "kb-firmware")
    content = args.get("content", "")
    source = args.get("source", "apify-scrape")
    if not content:
        return json.dumps({"ok": False, "error": "content is required"})
    rag_url = os.environ.get("MASCARADE_URL", "http://localhost:8100")
    payload = {"collection": collection, "text": content, "metadata": {"source": source}}
    try:
        import urllib.request as _req
        data = json.dumps(payload).encode()
        req = _req.Request(f"{rag_url}/v1/rag/ingest", data=data,
                           headers={"Content-Type": "application/json"}, method="POST")
        with _req.urlopen(req, timeout=30) as r:
            resp = json.loads(r.read().decode())
        return json.dumps({"ok": True, "collection": collection, "response": resp})
    except Exception as exc:
        return json.dumps({"ok": False, "error": str(exc)})


# Append Kill_LIFE-specific tools to the shared list.
TOOLS.extend([
    {
        "name": "get_runtime_info",
        "description": "Return Apify MCP runtime info: mode (apify-api vs direct-scrape), key status, registered tools.",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "fetch_espressif_docs",
        "description": "Fetch Espressif ESP-IDF / ESP32-S3 documentation for a topic or URL.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "topic": {"type": "string", "description": "Documentation topic to fetch"},
                "chip": {"type": "string", "description": "Target chip (default: esp32s3)"},
                "url": {"type": "string", "description": "Override URL"},
            },
        },
    },
    {
        "name": "fetch_platformio_registry",
        "description": "Fetch PlatformIO library registry info for a library name.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "library": {"type": "string", "description": "Library name or search query"},
                "url": {"type": "string", "description": "Override URL"},
            },
        },
    },
    {
        "name": "fetch_kicad_library_info",
        "description": "Fetch KiCad component library info (symbols, footprints) for a component.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "component": {"type": "string", "description": "Component name or search query"},
                "url": {"type": "string", "description": "Override URL"},
            },
        },
    },
    {
        "name": "ingest_to_rag",
        "description": "Ingest scraped content into the Mascarade RAG pipeline (Qdrant).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "collection": {"type": "string", "description": "RAG collection (e.g. kb-firmware, kb-kicad)"},
                "content": {"type": "string", "description": "Text content to ingest"},
                "source": {"type": "string", "description": "Source label (e.g. espressif-docs)"},
            },
            "required": ["content"],
        },
    },
])

HANDLERS = {
    "scrape_datasheet": handle_scrape_datasheet,
    "search_components": handle_search_components,
    "scrape_forum": handle_scrape_forum,
    "scrape_docs": handle_scrape_docs,
    "monitor_updates": handle_monitor_updates,
    "feed_dataset": handle_feed_dataset,
    "get_runtime_info": handle_get_runtime_info,
    "fetch_espressif_docs": handle_fetch_espressif_docs,
    "fetch_platformio_registry": handle_fetch_platformio_registry,
    "fetch_kicad_library_info": handle_fetch_kicad_library_info,
    "ingest_to_rag": handle_ingest_to_rag,
}

# ---------------------------------------------------------------------------
# MCP stdio protocol loop
# ---------------------------------------------------------------------------

SERVER_INFO = {"name": "apify", "version": "1.0.0"}


async def handle_message(msg: dict) -> dict | None:
    method = msg.get("method", "")
    mid = msg.get("id")

    if method == "initialize":
        return make_response(mid, {
            "protocolVersion": PROTOCOL_VERSION,
            "capabilities": {"tools": {"listChanged": False}},
            "serverInfo": SERVER_INFO,
        })

    if method == "notifications/initialized":
        return None

    if method == "tools/list":
        return make_response(mid, {"tools": TOOLS})

    if method == "tools/call":
        params = msg.get("params", {})
        name = params.get("name", "")
        args = params.get("arguments", {})
        handler = HANDLERS.get(name)
        if not handler:
            return make_response(mid, error_tool_result(f"Unknown tool: {name}", {}))
        try:
            result = await handler(args)
            structured = json.loads(result) if isinstance(result, str) else result
            return make_response(mid, ok_tool_result(result if isinstance(result, str) else json.dumps(result), structured if isinstance(structured, dict) else {}))
        except Exception as exc:
            return make_response(mid, error_tool_result(f"{type(exc).__name__}: {exc}", {}))

    return make_error(mid, -32601, f"Method not found: {method}")


async def main() -> None:
    while True:
        msg = read_message()
        if msg is None:
            break
        resp = await handle_message(msg)
        if resp is not None:
            write_message(resp)


if __name__ == "__main__":
    asyncio.run(main())
