# Diagramme agentique OpenClaw

```mermaid
flowchart TD
  Issue[Issue (label ai:*)] --> PR[Pull Request]
  PR --> Gate[Gate (tests, conformité)]
  Gate --> Evidence[Evidence Pack]
  Evidence --> CI[CI/CD]
  PR --> Agents[Agents (PM, Architect, Firmware, QA, Doc, HW)]
  Agents --> Specs[specs/]
  Agents --> Firmware[firmware/]
  Agents --> Hardware[hardware/]
  Agents --> Docs[docs/]
  Agents --> Compliance[compliance/]
  Agents --> Tools[tools/]
  Agents --> OpenClaw[openclaw/]
  OpenClaw --> Sandbox[Sandbox]
```

## Tutoriel vidéo

- [Tutoriel vidéo OpenClaw (YouTube)](https://www.youtube.com/watch?v=dQw4w9WgXcQ)

## Script de test automatisé

```python
# test_openclaw_label.py
import sys
sys.path.insert(0, "../../tools/ai")
from sanitize_issue import sanitize_text

def test_label_addition():
    input_text = "Ajout du label ai:impl sur la PR #42"
    sanitized = sanitize_text(input_text)
    assert "ai:impl" in sanitized
    assert "#42" not in sanitized
    print("Label addition test passed.")

if __name__ == "__main__":
    test_label_addition()
```

- Placez ce script dans `openclaw/onboarding/` et lancez-le pour valider la sanitisation lors de l’ajout de label.

## Ressources visuelles complémentaires

- [README openclaw/](../README.md)
- [Exemples d’utilisation](exemples.md)
- [Guide contributeur](guide_contributeur.md)
