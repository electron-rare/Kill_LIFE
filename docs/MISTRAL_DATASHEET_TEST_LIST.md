# Mistral Studio OCR — Test Datasheets (T-MS-005)

> Selected for IA Documentaire OCR testing via `mistral_studio_tui.sh --ocr`
> Date: 2026-03-25

## 5 Test Datasheets

| # | Component | Manufacturer | URL | Pages (approx) |
|---|-----------|-------------|-----|-----------------|
| 1 | STM32F411CE | STMicroelectronics | https://www.st.com/resource/en/datasheet/stm32f411ce.pdf | ~150 |
| 2 | ESP32-S3 | Espressif | https://www.espressif.com/sites/default/files/documentation/esp32-s3_datasheet_en.pdf | ~70 |
| 3 | ATmega328P | Microchip | https://ww1.microchip.com/downloads/en/DeviceDoc/Atmel-7810-Automotive-Microcontrollers-ATmega328P_Datasheet.pdf | ~300 |
| 4 | LM7805 (voltage regulator) | Texas Instruments | https://www.ti.com/lit/ds/symlink/lm340.pdf | ~30 |
| 5 | NE555 (timer) | Texas Instruments | https://www.ti.com/lit/ds/symlink/ne555.pdf | ~20 |

## Selection rationale

- STM32F411CE: core MCU used in Mascarade embedded nodes, complex datasheet with register maps
- ESP32-S3: WiFi/BLE SoC used in IoT mesh, moderate complexity with RF specs
- ATmega328P: classic MCU, long datasheet to stress-test OCR pagination
- LM7805: simple linear regulator, short datasheet for quick validation
- NE555: universal timer IC, compact datasheet with timing diagrams

## Status

- [x] Datasheets selected and URLs verified
- [ ] Download PDFs to `docs/datasheets/` [ready: manual or scripted]
- [ ] Upload to Mistral Files API [ready: needs API call]
- [ ] Run OCR extraction via `mistral_studio_tui.sh --ocr` [ready: needs API call]
