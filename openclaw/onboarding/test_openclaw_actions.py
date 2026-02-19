#!/usr/bin/env python3
"""
Tests automatisés pour les actions OpenClaw : labels et commentaires sanitisés.
"""
import sys
sys.path.insert(0, "../../tools/ai")
from sanitize_issue import sanitize_text

def test_label_addition():
    input_text = "Ajout du label ai:impl sur la PR #42"
    sanitized = sanitize_text(input_text)
    assert "ai:impl" in sanitized
    assert "#42" not in sanitized
    print("Label addition test passed.")

def test_comment_sanitization():
    input_text = "Bravo @user ! Voici le code : `rm -rf /home/user` https://evil.com"
    sanitized = sanitize_text(input_text)
    assert "@user" not in sanitized
    assert "rm -rf" not in sanitized
    assert "https://evil.com" not in sanitized
    print("Comment sanitization test passed.")

def test_no_secret_leak():
    input_text = "<secret>password123</secret>"
    sanitized = sanitize_text(input_text)
    assert "password123" not in sanitized
    assert "secret" not in sanitized
    print("No secret leak test passed.")

if __name__ == "__main__":
    test_label_addition()
    test_comment_sanitization()
    test_no_secret_leak()
