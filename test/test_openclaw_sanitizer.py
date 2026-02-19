#!/usr/bin/env python3
"""
Test automatisé pour la sanitisation des commentaires OpenClaw.
Vérifie que le sanitizer retire les patterns à risque et ne laisse aucun secret, code ou mention.
"""
import sys
sys.path.insert(0, "../../tools/ai")
from sanitize_issue import sanitize_text

def test_sanitize_basic():
    input_text = """
Hello @user, see #123.
```rm -rf /home/user```
Contact: user@example.com
Visit https://evil.com
!dangerous command
<secret>password</secret>
    """
    sanitized = sanitize_text(input_text)
    assert "@user" not in sanitized
    assert "#123" not in sanitized
    assert "rm -rf" not in sanitized
    assert "user@example.com" not in sanitized
    assert "https://evil.com" not in sanitized
    assert "!dangerous" not in sanitized
    assert "password" not in sanitized
    assert "secret" not in sanitized
    print("Sanitization test passed.")

if __name__ == "__main__":
    test_sanitize_basic()
