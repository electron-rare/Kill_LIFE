# Kill_LIFE Evidence Pack Summary

- JSON report: `docs/evidence/ci_cd_audit_summary.json`
- Artifact snapshot: `docs/evidence/`

| Lane | RC | Status |
| --- | --- | --- |
| compliance | `0` | ok |
| esp | `0` | ok |
| linux | `0` | ok |

## esp

| Step | RC | Command | Signal |
| --- | --- | --- | --- |
| `build_firmware` | `0` | `tools/build_firmware.py esp` | Build target 'esp' via PlatformIO env 'esp32s3_arduino' (mode=native, runner=native-pio) |
| `collect_evidence` | `0` | `tools/collect_evidence.py esp` | Evidence pack généré pour esp: docs/evidence/esp |
| `verify_evidence` | `0` | `tools/verify_evidence.py esp` | Evidence pack trouvé pour esp: ['firmware/.pio/build/esp32s3_arduino/firmware.bin', 'firmware/.pio/build/esp32s3_arduino/firmware.elf', 'firmware/.pio/build/esp32s3_arduino/firmware.map', 'firmware/.pio/build/esp32s3_arduino'] |

## linux

| Step | RC | Command | Signal |
| --- | --- | --- | --- |
| `test_firmware` | `0` | `tools/test_firmware.py linux` | Tests target 'linux' via PlatformIO env 'native' (mode=native, runner=native-pio) |
| `collect_evidence` | `0` | `tools/collect_evidence.py linux` | Evidence pack généré pour linux: docs/evidence/linux |
| `verify_evidence` | `0` | `tools/verify_evidence.py linux` | Evidence pack trouvé pour linux: ['firmware/.pio/build/native'] |
