#!/usr/bin/env python3
"""
Local fine-tuning via Unsloth + QLoRA — FREE alternative to Mistral paid fine-tune API.

Target hardware: KXKM RTX 4090 (24 GB VRAM).
Supported bases: Mistral-7B-v0.3, Codestral-22B-v0.1 (HuggingFace weights).

Usage:
    python3 local_finetune.py \
        --base mistral-7b \
        --dataset datasets/kicad_merged.jsonl \
        --output models/kicad_qlora

    python3 local_finetune.py \
        --base codestral-22b \
        --dataset datasets/embedded/stm32_merged.jsonl \
        --output models/embedded_qlora \
        --steps 200 --lr 3e-5

    # Export to GGUF for Ollama after training:
    python3 local_finetune.py \
        --export-gguf models/kicad_qlora \
        --ollama-name mascarade-kicad
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

# ---------------------------------------------------------------------------
# Model registry — maps friendly names to HuggingFace repo IDs
# ---------------------------------------------------------------------------
BASE_MODELS: Dict[str, str] = {
    "mistral-7b": "mistralai/Mistral-7B-v0.3",
    "codestral-22b": "mistralai/Codestral-22B-v0.1",
}

# QLoRA defaults (4-bit, rank 16)
QLORA_DEFAULTS = dict(
    r=16,
    lora_alpha=16,
    lora_dropout=0.0,
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj"],
    bias="none",
    task_type="CAUSAL_LM",
)

TEMPLATE_DIR = Path(__file__).resolve().parent


# ---------------------------------------------------------------------------
# Dataset helpers
# ---------------------------------------------------------------------------
def load_jsonl(path: Path) -> List[Dict[str, Any]]:
    """Load a JSONL file (one JSON object per line)."""
    records: List[Dict[str, Any]] = []
    with open(path, "r", encoding="utf-8") as fh:
        for lineno, line in enumerate(fh, 1):
            line = line.strip()
            if not line:
                continue
            try:
                records.append(json.loads(line))
            except json.JSONDecodeError as exc:
                print(f"  WARN: skipping line {lineno} in {path.name}: {exc}")
    return records


def prepare_dataset(path: Path):
    """Return a HuggingFace Dataset from a JSONL file.

    Expected JSONL format (chat-style):
        {"messages": [{"role":"user","content":"..."}, {"role":"assistant","content":"..."}]}
    OR simple instruction/output:
        {"instruction": "...", "output": "..."}
    """
    try:
        from datasets import Dataset
    except ImportError:
        sys.exit("ERROR: pip install datasets  (required for training)")

    records = load_jsonl(path)
    if not records:
        sys.exit(f"ERROR: dataset {path} is empty")

    # Normalise to a single 'text' column using ChatML formatting
    texts: List[str] = []
    for rec in records:
        if "messages" in rec:
            parts = []
            for msg in rec["messages"]:
                role = msg.get("role", "user")
                content = msg.get("content", "")
                parts.append(f"<|im_start|>{role}\n{content}<|im_end|>")
            texts.append("\n".join(parts))
        elif "instruction" in rec:
            texts.append(
                f"<|im_start|>user\n{rec['instruction']}<|im_end|>\n"
                f"<|im_start|>assistant\n{rec.get('output', '')}<|im_end|>"
            )
        elif "text" in rec:
            texts.append(rec["text"])
        else:
            # Best-effort: serialise the whole object
            texts.append(json.dumps(rec, ensure_ascii=False))

    print(f"  Loaded {len(texts)} training examples from {path.name}")
    return Dataset.from_dict({"text": texts})


# ---------------------------------------------------------------------------
# Training
# ---------------------------------------------------------------------------
def train(
    base_name: str,
    dataset_path: Path,
    output_dir: Path,
    max_steps: int = 100,
    lr: float = 2e-5,
    batch_size: int = 4,
    grad_accum: int = 4,
    max_seq_length: int = 2048,
):
    """Run QLoRA fine-tuning with Unsloth (fast LoRA for consumer GPUs)."""

    # --- Lazy imports so the script can still show --help without GPU libs ---
    try:
        from unsloth import FastLanguageModel
    except ImportError:
        sys.exit(
            "ERROR: Unsloth not installed.\n"
            "  pip install 'unsloth[colab-new] @ git+https://github.com/unslothai/unsloth.git'\n"
            "  pip install --no-deps trl peft accelerate bitsandbytes"
        )
    try:
        from trl import SFTTrainer
        from transformers import TrainingArguments
    except ImportError:
        sys.exit("ERROR: pip install trl transformers")

    model_id = BASE_MODELS.get(base_name)
    if model_id is None:
        sys.exit(
            f"ERROR: unknown base '{base_name}'. "
            f"Choose from: {', '.join(BASE_MODELS)}"
        )

    output_dir.mkdir(parents=True, exist_ok=True)

    # 1. Load base model in 4-bit
    print(f"\n==> Loading {model_id} in 4-bit quantisation ...")
    model, tokenizer = FastLanguageModel.from_pretrained(
        model_name=model_id,
        max_seq_length=max_seq_length,
        dtype=None,  # auto
        load_in_4bit=True,
    )

    # 2. Attach LoRA adapters
    print("==> Attaching QLoRA adapters ...")
    model = FastLanguageModel.get_peft_model(
        model,
        r=QLORA_DEFAULTS["r"],
        lora_alpha=QLORA_DEFAULTS["lora_alpha"],
        lora_dropout=QLORA_DEFAULTS["lora_dropout"],
        target_modules=QLORA_DEFAULTS["target_modules"],
        bias=QLORA_DEFAULTS["bias"],
    )

    # 3. Prepare dataset
    print(f"==> Preparing dataset from {dataset_path} ...")
    ds = prepare_dataset(dataset_path)

    # 4. Train
    print(f"==> Training for {max_steps} steps (lr={lr}, bs={batch_size}x{grad_accum}) ...")
    training_args = TrainingArguments(
        output_dir=str(output_dir / "checkpoints"),
        max_steps=max_steps,
        learning_rate=lr,
        per_device_train_batch_size=batch_size,
        gradient_accumulation_steps=grad_accum,
        fp16=True,
        logging_steps=10,
        save_steps=max_steps,  # save at the end
        warmup_steps=min(10, max_steps // 10),
        optim="adamw_8bit",
        seed=42,
        report_to="none",
    )

    trainer = SFTTrainer(
        model=model,
        tokenizer=tokenizer,
        train_dataset=ds,
        dataset_text_field="text",
        max_seq_length=max_seq_length,
        args=training_args,
    )

    trainer.train()

    # 5. Save adapter weights
    adapter_dir = output_dir / "adapter"
    print(f"==> Saving LoRA adapter to {adapter_dir} ...")
    model.save_pretrained(str(adapter_dir))
    tokenizer.save_pretrained(str(adapter_dir))

    # 6. Save training metadata
    meta = {
        "base_model": model_id,
        "base_alias": base_name,
        "dataset": str(dataset_path),
        "qlora": QLORA_DEFAULTS,
        "training": {
            "max_steps": max_steps,
            "lr": lr,
            "batch_size": batch_size,
            "grad_accum": grad_accum,
            "max_seq_length": max_seq_length,
        },
    }
    meta_path = output_dir / "training_meta.json"
    meta_path.write_text(json.dumps(meta, indent=2, ensure_ascii=False))
    print(f"==> Metadata saved to {meta_path}")

    print("\n==> Training complete!")
    print(f"    Adapter:  {adapter_dir}")
    print(f"    Metadata: {meta_path}")
    print(
        f"\n    Next step — export to GGUF for Ollama:\n"
        f"      python3 {Path(__file__).name} --export-gguf {output_dir} --ollama-name mascarade-kicad"
    )
    return output_dir


# ---------------------------------------------------------------------------
# GGUF export + Ollama import
# ---------------------------------------------------------------------------
def export_gguf(model_dir: Path, ollama_name: Optional[str] = None):
    """Merge LoRA adapter back into base, quantise to GGUF, optionally register in Ollama."""
    try:
        from unsloth import FastLanguageModel
    except ImportError:
        sys.exit("ERROR: Unsloth not installed (needed for GGUF export).")

    meta_path = model_dir / "training_meta.json"
    if not meta_path.exists():
        sys.exit(f"ERROR: {meta_path} not found — is this a local_finetune output dir?")
    meta = json.loads(meta_path.read_text())

    adapter_dir = model_dir / "adapter"
    gguf_dir = model_dir / "gguf"
    gguf_dir.mkdir(exist_ok=True)

    print(f"==> Loading base model + adapter from {adapter_dir} ...")
    model, tokenizer = FastLanguageModel.from_pretrained(
        model_name=str(adapter_dir),
        max_seq_length=meta["training"]["max_seq_length"],
        dtype=None,
        load_in_4bit=True,
    )

    # Unsloth provides a convenient save_pretrained_gguf helper
    print(f"==> Exporting merged GGUF to {gguf_dir} ...")
    model.save_pretrained_gguf(
        str(gguf_dir),
        tokenizer,
        quantization_method="q4_k_m",  # good quality / size trade-off
    )

    gguf_files = list(gguf_dir.glob("*.gguf"))
    if not gguf_files:
        print("WARN: No .gguf file produced — check Unsloth version.")
        return

    gguf_path = gguf_files[0]
    print(f"==> GGUF ready: {gguf_path}")

    # Generate Modelfile from template
    template_path = TEMPLATE_DIR / "Modelfile.template"
    modelfile_path = model_dir / "Modelfile"
    if template_path.exists():
        content = template_path.read_text()
        content = content.replace("{{GGUF_PATH}}", str(gguf_path))
        content = content.replace("{{MODEL_NAME}}", ollama_name or model_dir.name)
        content = content.replace("{{BASE_MODEL}}", meta.get("base_model", "unknown"))
        modelfile_path.write_text(content)
        print(f"==> Modelfile written: {modelfile_path}")
    else:
        # Inline fallback
        modelfile_path.write_text(
            f"FROM {gguf_path}\n"
            f"PARAMETER temperature 0.2\n"
            f"PARAMETER top_p 0.9\n"
            f"SYSTEM You are a specialised engineering assistant fine-tuned on KXKM hardware data.\n"
        )
        print(f"==> Modelfile written (inline): {modelfile_path}")

    # Optionally register in Ollama
    if ollama_name and shutil.which("ollama"):
        print(f"==> Registering in Ollama as '{ollama_name}' ...")
        result = subprocess.run(
            ["ollama", "create", ollama_name, "-f", str(modelfile_path)],
            capture_output=True,
            text=True,
        )
        if result.returncode == 0:
            print(f"    OK — run: ollama run {ollama_name}")
        else:
            print(f"    WARN: ollama create failed: {result.stderr.strip()}")
    elif ollama_name:
        print(f"    Ollama CLI not found. Import manually:\n      ollama create {ollama_name} -f {modelfile_path}")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(
        description="Local QLoRA fine-tuning (Unsloth) — free Mistral alternative",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )

    # Training mode
    parser.add_argument("--base", choices=list(BASE_MODELS), default="mistral-7b",
                        help="Base model alias (default: mistral-7b)")
    parser.add_argument("--dataset", type=Path,
                        help="Path to JSONL training dataset")
    parser.add_argument("--output", type=Path, default=Path("models/finetune_qlora"),
                        help="Output directory for adapter + GGUF")
    parser.add_argument("--steps", type=int, default=100, help="Max training steps")
    parser.add_argument("--lr", type=float, default=2e-5, help="Learning rate")
    parser.add_argument("--batch-size", type=int, default=4)
    parser.add_argument("--grad-accum", type=int, default=4)
    parser.add_argument("--max-seq-length", type=int, default=2048)

    # Export mode
    parser.add_argument("--export-gguf", type=Path, metavar="MODEL_DIR",
                        help="Export an existing adapter dir to GGUF")
    parser.add_argument("--ollama-name", type=str,
                        help="Register the GGUF model in Ollama with this name")

    args = parser.parse_args()

    if args.export_gguf:
        export_gguf(args.export_gguf, args.ollama_name)
    elif args.dataset:
        train(
            base_name=args.base,
            dataset_path=args.dataset,
            output_dir=args.output,
            max_steps=args.steps,
            lr=args.lr,
            batch_size=args.batch_size,
            grad_accum=args.grad_accum,
            max_seq_length=args.max_seq_length,
        )
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
