# Mistral Tower Guide

> How Tower manages knowledge in the Kill_LIFE / Mascarade ecosystem

**Agent**: Tower
**Agent ID**: `ag_019d124e760877359ad3ff5031179ebc`
**Model**: `magistral-medium-latest` (temperature 0.4)
**Domains**: docs, readme, specs, content, email, crm, training, research

---

## Overview

Tower is the knowledge and content agent of the Mascarade mesh.
Its primary responsibilities are:

1. **Knowledge management** via the knowledge-base MCP server (Memos + Docmost backends)
2. **RAG-assisted document retrieval** using Mistral Document Library (Beta Libraries)
3. **Commercial content generation** (formation docs, slide decks, product sheets)
4. **Research and analysis** tasks (veille technologique, market analysis)

Tower operates with higher creativity (temperature 0.4) than other agents, tuned for long-form text generation and nuanced content production.

---

## Knowledge Base MCP Server

**Spec**: `specs/knowledge_base_mcp_spec.md`
**MCP config**: `mcp.json` (entry `knowledge-base`)
**Runner**: `tools/run_knowledge_base_mcp.sh`
**Backend**: `mascarade/core/mascarade/integrations/knowledge_base.py`

### Architecture

The knowledge-base MCP server bridges two wiki/note backends:

| Backend | Role | URL |
|---------|------|-----|
| **Memos** | Quick notes, operational memos | Self-hosted |
| **Docmost** | Structured documentation, long-form wiki | Self-hosted |

### MCP tools exposed

| Tool | Description |
|------|-------------|
| `search_pages` | Full-text search across both backends |
| `read_page` | Retrieve a specific page by ID |

These tools are validated via `test/test_knowledge_base_mcp.py` which confirms server initialization and tool registration.

### Integration with Mascarade core

The knowledge-base MCP is used by:
- Core routes: `knowledge-base/*`
- Knowledge scribe agent: `agents/knowledge-scribe/run-and-push`
- Tower agent: for RAG context injection before generating content

---

## Mistral Document Library (RAG)

**Task**: T-MS-013 (Plan 24)
**Client**: `mascarade/agents/mistral_agents_beta_api.py` (MistralLibraryClient)

### What it is

Mistral Document Library (Beta Libraries) is Mistral's native RAG solution. Documents uploaded via the Files API are associated with an agent and become searchable context.

### How Tower uses it

1. Commercial documents from `docs/commercial/` are uploaded to Mistral Files API (T-MS-004)
2. Documents are associated with the Tower agent via Library configuration
3. When Tower receives a query, it automatically searches the library for relevant context
4. RAG-augmented responses include citations from uploaded documents

### Commercial documents available

| Document | Path |
|----------|------|
| Factory 4.0 Starter | `docs/commercial/factory_4_0_starter.md` |
| Factory 4.0 Pro | `docs/commercial/factory_4_0_pro.md` |
| Factory 4.0 Enterprise | `docs/commercial/factory_4_0_enterprise.md` |
| Factory 4.0 Slide Deck | `docs/commercial/factory_4_0_slide_deck.md` |

### Status

- Documents exported to `docs/commercial/` (done)
- Upload to Mistral Files API: pending (T-MS-004, requires API call)
- Library association with Tower agent: pending (T-MS-013, depends on T-MS-004)

---

## Content Generation Profiles

Tower operates in three content profiles, selectable via `dispatch_to_agent.sh`:

### Writer profile (`docs`, `readme`, `specs`, `content`, `wiki`, `markdown`)

```bash
bash tools/ai/dispatch_to_agent.sh --lot T-MS-032 --domain docs
```

Tasks: documentation pages, README files, technical specifications, wiki content.

### Commercial profile (`email`, `crm`, `commercial`, `training`, `formation`)

```bash
bash tools/ai/dispatch_to_agent.sh --lot T-MS-004 --domain commercial
```

Tasks: formation documents, product sheets, email templates, CRM content, lead scoring with RAG context.

### Researcher profile (`research`, `veille`, `analysis`)

```bash
bash tools/ai/dispatch_to_agent.sh --lot T-MS-032 --domain research
```

Tasks: technology watch, competitor analysis, market research synthesis.

---

## Dispatch via `dispatch_to_agent.sh`

**Location**: `tools/ai/dispatch_to_agent.sh`

```bash
# Documentation task
bash tools/ai/dispatch_to_agent.sh --lot T-MS-032 --domain docs --prompt "Draft the Mistral Studio Overview page"

# Commercial content with local model (zero cost)
bash tools/ai/dispatch_to_agent.sh --lot T-MS-004 --domain commercial --local

# Research task
bash tools/ai/dispatch_to_agent.sh --lot T-MS-032 --domain research

# Dry run to inspect prompt
bash tools/ai/dispatch_to_agent.sh --lot T-MS-032 --domain docs --dry-run
```

---

## RAG Pipeline (future state)

Once T-MS-004 and T-MS-013 are completed, the Tower RAG pipeline will operate as follows:

```
User query
  |
  v
Tower agent (magistral-medium-latest, temp 0.4)
  |
  +-> Mistral Document Library search (RAG)
  |     |
  |     +-> docs/commercial/* (uploaded PDFs/markdown)
  |     +-> Outline wiki pages (if connected)
  |
  +-> knowledge-base MCP search
  |     |
  |     +-> Memos (quick notes)
  |     +-> Docmost (structured docs)
  |
  v
RAG-augmented response with citations
```

---

## Key files

| File | Purpose |
|------|---------|
| `tools/ai/dispatch_to_agent.sh` | Agent dispatch (Tower domains: docs, commercial, research) |
| `tools/run_knowledge_base_mcp.sh` | Knowledge-base MCP server runner |
| `specs/knowledge_base_mcp_spec.md` | MCP server specification |
| `test/test_knowledge_base_mcp.py` | MCP server tests |
| `docs/commercial/*.md` | Commercial documents for RAG upload |
| `mcp.json` | MCP server configuration (includes knowledge-base entry) |
