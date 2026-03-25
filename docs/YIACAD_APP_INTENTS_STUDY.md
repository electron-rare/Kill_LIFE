# YiACAD App Intents and On-Device Models Study (T-UX-008)

> Date: 2026-03-25 | Source: Plan 20 - UI/UX Apple-native

---

## 1. App Intents / Shortcuts for YiACAD Automation

### 1.1 What App Intents provide

App Intents (iOS 16+ / macOS 13+) let native apps expose structured actions to:
- Siri voice commands
- Shortcuts.app (visual automation builder)
- Spotlight suggestions
- Focus filters and automation triggers

### 1.2 Applicability to YiACAD

| Capability | YiACAD use case | Feasibility |
|---|---|---|
| `@AppIntent` struct | Expose "Run ERC/DRC", "Check BOM", "Sync ECAD/MCAD" as system-wide actions | HIGH -- requires Swift wrapper around backend client |
| `@AppShortcutsProvider` | Pre-built shortcuts for common review workflows | HIGH |
| `@Parameter` with entity queries | Let user pick a KiCad project or FreeCAD document from Shortcuts | MEDIUM -- requires project index |
| Siri invocation | "Hey Siri, run YiACAD review on current project" | MEDIUM -- needs active project context |
| Focus filter | Auto-run status check when entering "Engineering" Focus | LOW priority but trivial |

### 1.3 Architecture for App Intents integration

```
Shortcuts.app / Siri
    |
    v
YiACAD macOS helper app (Swift, sandboxed)
    |  -- calls local HTTP backend on 127.0.0.1:38435
    v
yiacad_backend_service.py (already exists)
    |
    v
yiacad_native_ops.py -> artifacts/cad-ai-native/
```

The helper app is a thin Swift binary that:
1. Declares `AppIntent` structs for each YiACAD command
2. Calls the existing backend HTTP API (`POST /run`)
3. Returns structured results to Shortcuts (summary, status, severity)

### 1.4 Required work

| Task | Effort | Dependency |
|---|---|---|
| Create `YiACADHelper.app` Swift project with App Intents | 2-3 days | Xcode, macOS 13+ SDK |
| Define `YiACADStatusIntent`, `YiACADReviewIntent`, `YiACADSyncIntent` | 1 day | Backend client API stable |
| Add `@AppShortcutsProvider` with default shortcuts | 0.5 day | Intents defined |
| Test with Shortcuts.app and Siri | 0.5 day | Helper app built |
| Sign and notarize for distribution | 1 day | Apple Developer account |

Total estimated effort: 4-5 days.

### 1.5 Alternatives considered

| Alternative | Pros | Cons |
|---|---|---|
| AppleScript / osascript bridge | No Swift needed, works today | No Siri, no Shortcuts discovery, no parameters |
| Automator actions | Legacy but functional | Deprecated by Apple, no future |
| CLI-only (current) | Already works via `yiacad_backend_client.py` | Not discoverable, no voice, no Shortcuts |

**Recommendation**: Build the Swift helper as a lightweight companion. The HTTP backend already exists; the helper is pure glue code.

---

## 2. On-Device Models for Review Assistance

### 2.1 Apple CoreML

| Aspect | Assessment |
|---|---|
| What it does | Runs ML models on Apple Neural Engine (ANE), GPU, or CPU |
| Model format | `.mlmodel` / `.mlpackage` (converted from PyTorch/ONNX/TF) |
| Relevant models | Text classification (severity triage), embedding (semantic search), small generative (code review hints) |
| Integration path | Swift `MLModel` API or Python `coremltools` |
| Strengths | Zero network latency, privacy-preserving, ANE acceleration on M-series |
| Limitations | Model size constrained (~4GB practical max), no large LLM inference, conversion can lose accuracy |

### 2.2 MLX (Apple ML Research framework)

| Aspect | Assessment |
|---|---|
| What it does | NumPy-like framework optimized for Apple Silicon unified memory |
| Model support | LLaMA, Mistral, Phi, Gemma, Qwen families via `mlx-lm` |
| Quantization | 4-bit/8-bit GGUF or MLX native format |
| Integration path | Python `mlx` package, runs directly in the YiACAD Python environment |
| Strengths | Full LLM inference on-device, fast on M1+, no cloud dependency |
| Limitations | Apple Silicon only, Python-only API, memory-bound for >13B models |

### 2.3 Recommended on-device models for YiACAD

| Use case | Model | Size | Framework | Expected speed (M2 Pro) |
|---|---|---|---|---|
| Review severity triage | Fine-tuned `Phi-3-mini-4k` (3.8B, Q4) | ~2.2 GB | MLX | ~30 tok/s |
| ERC/DRC explanation | `Mistral-7B-Instruct` (Q4) | ~4.1 GB | MLX | ~20 tok/s |
| Semantic search on project docs | `nomic-embed-text` (137M) | ~0.3 GB | CoreML or MLX | <50ms per query |
| Quick summarization | `Qwen2-1.5B-Instruct` (Q8) | ~1.7 GB | MLX | ~45 tok/s |

### 2.4 Integration architecture

```
YiACAD review pipeline
    |
    +-- severity triage (on-device, MLX Phi-3-mini)
    |       input: ERC/DRC raw output
    |       output: severity label + confidence
    |
    +-- explanation generation (on-device, MLX Mistral-7B)
    |       input: violation + board context
    |       output: human-readable explanation
    |
    +-- semantic project search (on-device, CoreML nomic-embed)
    |       input: user query
    |       output: ranked relevant files/components
    |
    +-- complex review (cloud fallback, Mascarade mesh)
            input: full project context
            output: deep architectural review
```

### 2.5 Implementation path

| Step | Task | Effort |
|---|---|---|
| 1 | Add `mlx` and `mlx-lm` to YiACAD Python deps | 0.5 day |
| 2 | Create `tools/cad/yiacad_local_model.py` wrapping MLX inference | 1-2 days |
| 3 | Download and quantize target models (Phi-3-mini, Mistral-7B) | 0.5 day |
| 4 | Wire severity triage into `yiacad_native_ops.py` review pipeline | 1 day |
| 5 | Wire explanation generation into review center output | 1 day |
| 6 | Add CoreML embedding for semantic search | 1-2 days |
| 7 | Benchmark on M1/M2/M3 and set model-size gates | 0.5 day |

Total estimated effort: 5-7 days.

### 2.6 Decision criteria for on-device vs cloud

| Factor | On-device | Cloud (Mascarade) |
|---|---|---|
| Latency | <2s for triage, <10s for explanation | 5-30s depending on mesh load |
| Privacy | Full -- no data leaves machine | Depends on mesh topology |
| Quality | Good for triage/explanation, limited for deep review | Best for complex multi-file analysis |
| Availability | Always (no network needed) | Requires mesh connectivity |
| Cost | Zero marginal cost | Token-based |

**Recommendation**: Use on-device models for fast-path triage and explanation. Fall back to Mascarade cloud mesh for deep multi-file reviews. The backend service can route automatically based on task complexity.

---

*Generated 2026-03-25 for Plan 20 T-UX-008*
