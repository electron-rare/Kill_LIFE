#pragma once

#include <cstdint>
#include <driver/i2s_std.h>
#include <vector>

/// I2S microphone capture only (ICS-43434 on the Waveshare board).
/// Uses the new I2S channel driver (ESP-IDF 5.x) to avoid conflicts
/// with the ESP32-audioI2S library (RadioPlayer) which also uses it.
class I2sMic {
public:
  /// Initialise I2S1 for mic capture.
  /// Default pins for Waveshare ESP32-S3-LCD-1.85: SCK=15, WS=2, SD=39
  bool Begin(int sck = 15, int ws = 2, int sd = 39, int sample_rate = 16000);

  /// Record duration_ms of audio → complete WAV buffer (44-byte header + PCM).
  bool Capture(std::vector<uint8_t> &wav_out, uint32_t duration_ms);

  void End();

  int sample_rate() const { return sample_rate_; }

private:
  static void WriteWavHeader(uint8_t *dest, uint32_t pcm_bytes, int sr);
  int sample_rate_ = 16000;
  bool installed_ = false;
  i2s_chan_handle_t rx_handle_ = nullptr;
};
