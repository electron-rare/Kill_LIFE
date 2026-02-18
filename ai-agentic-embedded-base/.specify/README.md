# Spec-driven development (compat Spec Kit)

Ce repo adopte un style **spec-first** : avant de coder, on écrit la spec et le plan.

Pour rester compatible avec l'approche **Spec Kit**, on expose un dossier `.specify/` qui contient
des templates minimalistes.

## Générer un dossier de spec

```bash
python tools/ai/specify_init.py --name <feature-or-epic>
```

Cela crée :

```
specs/<feature-or-epic>/
  00_prd.md
  01_tech_plan.md
  02_tasks.md
```

## Règles

- Un dossier `specs/<name>/` par feature/epic.
- La PR doit référencer la spec (lien relatif).
- Les tests/exports (firmware CI + hardware CI) doivent être verts.
