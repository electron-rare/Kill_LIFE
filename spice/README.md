# Kill_LIFE SPICE Reference Circuits

SPICE netlists for the Kill_LIFE ESP32-S3 hardware.
Simulator: ngspice-42 (host), accessible via MCP ngspice server.

## Circuits

| File | Circuit | Analysis |
|------|---------|----------|
| `01_power_decoupling.sp` | ESP32-S3 VDD rail + LDO decoupling | AC impedance 1kHz–1GHz |
| `02_i2s_audio_output.sp` | PCM5101A DAC → headphone output | AC frequency response |
| `03_mems_mic_bias.sp` | ICS-43434 I2S mic VDD + SDO line | Transient timing |
| `04_i2c_pullups.sp` | I2C bus pull-ups + rise time | Transient 400kHz |

## Hardware mapping

| Component | GPIO | Role |
|-----------|------|------|
| PCM5101A DAC | BCK=48, WS=38, DOUT=47 | I2S audio output |
| ICS-43434 mic | SCK=15, WS=2, SD=39 | I2S audio input |
| I2C bus | SDA=1, SCL=2 | Peripheral control |
| LCD (Waveshare 1.85") | SPI | Display |

## Running simulations

Via MCP ngspice server (Claude Code):
```
# Run tool: run_simulation
netlist: <contents of .sp file>
```

Via CLI:
```bash
ngspice -b spice/01_power_decoupling.sp
```

## Adding new circuits

1. Name: `NN_description.sp` (sequential number)
2. Include: title comment, component specs, analysis directive, `.control`/`.endc` with `quit`
3. Ingest: `POST /v1/rag/ingest` collection=`kb-spice`
