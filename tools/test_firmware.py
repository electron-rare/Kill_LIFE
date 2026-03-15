#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.ci_runtime import pio_mode, resolve_target, resolved_pio_runner, run_platformio_step


def test_firmware(target: str) -> int:
    spec = resolve_target(target, expected_mode="test")
    print(
        f"Tests target '{spec.requested}' via PlatformIO env '{spec.env}' "
        f"(mode={pio_mode()}, runner={resolved_pio_runner(spec, 'test')})"
    )
    rc = run_platformio_step(spec, "test")
    if rc == 0:
        print(f"Tests terminés pour {spec.requested}")
    return rc


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit("usage: test_firmware.py <target>")
    raise SystemExit(test_firmware(sys.argv[1]))
