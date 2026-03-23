# Web research open source / MCP / AI 2026-03-22

## Delta verification officielle 2026-03-22

| Source officielle | Signal verifie | Decision Kill_LIFE |
| --- | --- | --- |
| [Model Context Protocol intro](https://modelcontextprotocol.io/docs/getting-started/intro) + [MCP registry](https://registry.modelcontextprotocol.io/) | MCP remains the preferred standard boundary for tool discovery and external tool contracts. | Keep MCP as the preferred boundary for parts search, CI triggers, artifact fetch and ops summary; do not force MCP inside Git/Yjs persistence. |
| [OpenAI tools guide](https://developers.openai.com/api/docs/guides/tools) | The current OpenAI platform groups tools, MCP/connectors, WebSocket mode, background mode and agent-oriented surfaces under one tools-first model. | If web AI assist opens, keep it tools-first and read-only at first. Use it above Git/Yjs/workers, not instead of them. |
| [OpenAI Agents SDK](https://openai.github.io/openai-agents-python/) | Official patterns center on tools, handoffs, tracing and sessions. | Keep Agents SDK as a reference for handoffs/tracing patterns only; not as the project source of truth. |
| [LangGraph overview](https://docs.langchain.com/oss/python/langgraph/overview) | LangGraph remains focused on durable execution, human-in-the-loop and long-running stateful agents. | Defer LangGraph until contracts, Git read model, artifacts and realtime are stable. |
| [VS Code Language Model Tool API](https://code.visualstudio.com/api/extension-guides/tools) + [Chat tutorial](https://code.visualstudio.com/api/extension-guides/ai/chat-tutorial) | VS Code positions built-in tools, extension tools and MCP tools as first-class building blocks. | Keep extension lanes light and cross-environment tool contracts on MCP/service boundaries. |
| [Excalidraw](https://github.com/excalidraw/excalidraw) | React embedding and JSON scene storage remain practical for Git-tracked architecture diagrams. | Keep `.excalidraw` JSON in Git. Bind collaboration through Yjs, but keep explicit snapshot/save semantics. |
| [Yjs docs](https://docs.yjs.dev/) | Yjs remains a strong CRDT choice for collaborative state and presence. | Use Yjs for room state and presence only. Git remains the product source of truth. |
| [KiCanvas embedding](https://kicanvas.org/embedding/) | The official docs still recommend vendoring the bundled `kicanvas.js` during alpha. | Keep `web/public/vendor/kicanvas.js` vendored and avoid runtime CDN coupling. |
| [KiBot](https://github.com/INTI-CMNB/KiBot) | KiBot remains the practical automation layer for reproducible outputs around KiCad. | Keep worker support for real KiBot binaries and a repo-level config path. |
| [KiAuto](https://github.com/INTI-CMNB/KiAuto) | KiAuto still fills the gap for ERC/DRC automation and GUI-driven KiCad flows. | Keep KiAuto as an explicit optional worker dependency, not an implicit runtime assumption. |
| [BullMQ docs](https://docs.bullmq.io/) | BullMQ remains a pragmatic Redis-backed queue for JS workers. | Keep BullMQ as the first queue contract for `web/`; do not introduce Kafka before real throughput pressure exists. |

## Package surface verified locally on 2026-03-22

- `@excalidraw/excalidraw`: `0.18.0`
- `next`: `16.2.1`
- `react`: `19.2.4`
- `graphql-yoga`: `5.18.1`
- `yjs`: `13.6.30`
- `y-websocket`: `3.0.0`
- `bullmq`: `5.71.0`

## Similar / usable OSS stack already aligned with the product

- `Excalidraw` for diagram editing
- `KiCanvas` for embedded board/schematic viewing
- `Yjs` for collaborative room state
- `BullMQ + Redis` for worker dispatch
- `KiBot` and `KiAuto` for EDA CI
- `KiCad` and `FreeCAD` remain the core native CAD engines behind YiACAD
