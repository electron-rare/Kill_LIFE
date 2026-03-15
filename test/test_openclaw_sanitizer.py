#!/usr/bin/env python3
"""
Test automatisé pour la sanitisation des commentaires OpenClaw.
Vérifie que le sanitizer retire les patterns à risque et ne laisse aucun secret, code ou mention.
"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools" / "ai"))
from sanitize_issue import sanitize_text


class OpenClawSanitizerTests(unittest.TestCase):
    def test_sanitize_basic(self):
        input_text = """
Hello @user, see #123.
```rm -rf /home/user```
Contact: user@example.com
Visit https://evil.com
!dangerous command
<secret>password</secret>
        """
        sanitized = sanitize_text(input_text)
        self.assertNotIn("@user", sanitized)
        self.assertNotIn("#123", sanitized)
        self.assertNotIn("rm -rf", sanitized)
        self.assertNotIn("user@example.com", sanitized)
        self.assertNotIn("https://evil.com", sanitized)
        self.assertNotIn("!dangerous", sanitized)
        self.assertNotIn("password", sanitized)
        self.assertNotIn("secret", sanitized)


if __name__ == "__main__":
    unittest.main()
