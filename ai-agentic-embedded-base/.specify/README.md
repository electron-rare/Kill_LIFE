# Spec-driven development (Spec Kit compatible)

This repo adopts a **spec-first** style: before coding, we write the spec and the plan.

To remain compatible with the **Spec Kit** approach, we expose a `.specify/` folder that contains
minimalist templates.

## Generate a spec folder

```bash
python tools/ai/specify_init.py --name <feature-or-epic>
```

This creates:

```raw
specs/<feature-or-epic>/
  00_prd.md
  01_tech_plan.md
  02_tasks.md
```

## Rules

- One `specs/<name>/` folder per feature/epic.
- The PR must reference the spec (relative link).
- Tests/exports (firmware CI + hardware CI) must be green.

<iframe src="https://github.com/sponsors/electron-rare/card" title="Sponsor electron-rare" height="225" width="600" style="border: 0;"></iframe>
