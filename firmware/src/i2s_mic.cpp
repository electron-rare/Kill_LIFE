#include "i2s_mic.h"

#include <cstring>
#include <Arduino.h>

static constexpr int kDmaBufCount = 8;
static constexpr int kDmaBufLen   = 1024;

// ---------------------------------------------------------------------------
bool I2sMic::Begin(int sck, int ws, int sd, int sample_rate) {
  sample_rate_ = sample_rate;

  // Channel config — use I2S port 1 for mic (port 0 is used by Audio library)
  i2s_chan_config_t chan_cfg = {
      .id = I2S_NUM_1,
      .role = I2S_ROLE_MASTER,
      .dma_desc_num = kDmaBufCount,
      .dma_frame_num = kDmaBufLen,
      .auto_clear_after_cb = true,
      .auto_clear_before_cb = false,
      .intr_priority = 0,
  };

  esp_err_t err = i2s_new_channel(&chan_cfg, nullptr, &rx_handle_);
  if (err != ESP_OK) {
    Serial.printf("[mic] channel create failed: %d\n", err);
    return false;
  }

  // Standard mode config — mono left channel, 16-bit
  i2s_std_config_t std_cfg = {
      .clk_cfg = {
          .sample_rate_hz = (uint32_t)sample_rate_,
          .clk_src = I2S_CLK_SRC_DEFAULT,
          .ext_clk_freq_hz = 0,
          .mclk_multiple = I2S_MCLK_MULTIPLE_256,
      },
      .slot_cfg = I2S_STD_PHILIPS_SLOT_DEFAULT_CONFIG(I2S_DATA_BIT_WIDTH_16BIT,
                                                       I2S_SLOT_MODE_MONO),
      .gpio_cfg = {
          .mclk = I2S_GPIO_UNUSED,
          .bclk = (gpio_num_t)sck,
          .ws = (gpio_num_t)ws,
          .dout = I2S_GPIO_UNUSED,
          .din = (gpio_num_t)sd,
          .invert_flags = {
              .mclk_inv = false,
              .bclk_inv = false,
              .ws_inv = false,
          },
      },
  };

  err = i2s_channel_init_std_mode(rx_handle_, &std_cfg);
  if (err != ESP_OK) {
    Serial.printf("[mic] std mode init failed: %d\n", err);
    i2s_del_channel(rx_handle_);
    rx_handle_ = nullptr;
    return false;
  }

  err = i2s_channel_enable(rx_handle_);
  if (err != ESP_OK) {
    Serial.printf("[mic] channel enable failed: %d\n", err);
    i2s_del_channel(rx_handle_);
    rx_handle_ = nullptr;
    return false;
  }

  installed_ = true;
  Serial.printf("[mic] ready — SCK=%d WS=%d SD=%d @ %d Hz (new driver)\n",
                sck, ws, sd, sample_rate_);
  return true;
}

// ---------------------------------------------------------------------------
bool I2sMic::Capture(std::vector<uint8_t>& wav_out, uint32_t duration_ms) {
  if (!installed_ || !rx_handle_) return false;

  const uint32_t bytes_per_sec = sample_rate_ * sizeof(int16_t);
  const uint32_t pcm_bytes     = (bytes_per_sec * duration_ms) / 1000;

  wav_out.resize(44 + pcm_bytes);
  WriteWavHeader(wav_out.data(), pcm_bytes, sample_rate_);

  size_t total = 0;
  uint8_t* dest = wav_out.data() + 44;

  while (total < pcm_bytes) {
    size_t chunk = pcm_bytes - total;
    if (chunk > kDmaBufLen * sizeof(int16_t))
      chunk = kDmaBufLen * sizeof(int16_t);

    size_t rd = 0;
    esp_err_t err = i2s_channel_read(rx_handle_, dest + total, chunk, &rd,
                                      portMAX_DELAY);
    if (err != ESP_OK) return false;
    total += rd;
  }

  Serial.printf("[mic] captured %u bytes (%u ms)\n",
                (unsigned)total, (unsigned)duration_ms);
  return true;
}

// ---------------------------------------------------------------------------
void I2sMic::End() {
  if (installed_ && rx_handle_) {
    i2s_channel_disable(rx_handle_);
    i2s_del_channel(rx_handle_);
    rx_handle_ = nullptr;
    installed_ = false;
  }
}

// ---------------------------------------------------------------------------
void I2sMic::WriteWavHeader(uint8_t* h, uint32_t pcm_bytes, int sr) {
  const uint32_t file_size   = 36 + pcm_bytes;
  const uint16_t channels    = 1;
  const uint16_t bits        = 16;
  const uint32_t byte_rate   = sr * channels * (bits / 8);
  const uint16_t block_align = channels * (bits / 8);
  const uint32_t fmt_size    = 16;
  const uint16_t pcm_fmt     = 1;

  memcpy(h + 0,  "RIFF", 4);      memcpy(h + 4,  &file_size,   4);
  memcpy(h + 8,  "WAVE", 4);      memcpy(h + 12, "fmt ", 4);
  memcpy(h + 16, &fmt_size, 4);   memcpy(h + 20, &pcm_fmt, 2);
  memcpy(h + 22, &channels, 2);   memcpy(h + 24, &sr, 4);
  memcpy(h + 28, &byte_rate, 4);  memcpy(h + 32, &block_align, 2);
  memcpy(h + 34, &bits, 2);       memcpy(h + 36, "data", 4);
  memcpy(h + 40, &pcm_bytes, 4);
}
