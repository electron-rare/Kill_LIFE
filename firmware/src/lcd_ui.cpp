#include "lcd_ui.h"

#include <Arduino.h>

#include <esp_display_panel.hpp>

// ---------------------------------------------------------------------------
// Waveshare ESP32-S3-Touch-LCD-1.85  (360×360 round, ST77916 QSPI)
// Board define BOARD_WAVESHARE_ESP32_S3_TOUCH_LCD_1_85 is set in build_flags
// so ESP_Panel_Library auto-configures pins & init sequence.
// ---------------------------------------------------------------------------

using Board = esp_panel::board::Board;
using LCD = esp_panel::drivers::LCD;

static Board *panel = nullptr;
static LCD *lcd = nullptr;

static constexpr int kWidth = 360;
static constexpr int kHeight = 360;
static constexpr int kCenter = 180;

// Simple 16-bit RGB565 colors
static constexpr uint16_t kBlack = 0x0000;
static constexpr uint16_t kWhite = 0xFFFF;
static constexpr uint16_t kGreen = 0x07E0;
static constexpr uint16_t kRed = 0xF800;
static constexpr uint16_t kBlue = 0x001F;
static constexpr uint16_t kCyan = 0x07FF;
static constexpr uint16_t kYellow = 0xFFE0;
static constexpr uint16_t kDarkGray = 0x4208;
static constexpr uint16_t kOrange = 0xFD20;

// Framebuffer — 360×360×2 = 259 KB, fits in PSRAM.
static uint16_t *fb = nullptr;

// ---------------------------------------------------------------------------
static inline void fbPixel(int x, int y, uint16_t color) {
  if (x >= 0 && x < kWidth && y >= 0 && y < kHeight) {
    fb[y * kWidth + x] = color;
  }
}

static void fbFill(uint16_t color) {
  for (int i = 0; i < kWidth * kHeight; i++)
    fb[i] = color;
}

static void fbFillRect(int x0, int y0, int w, int h, uint16_t color) {
  for (int y = y0; y < y0 + h && y < kHeight; y++) {
    for (int x = x0; x < x0 + w && x < kWidth; x++) {
      fbPixel(x, y, color);
    }
  }
}

static void fbHLine(int x0, int y, int w, uint16_t color) {
  for (int x = x0; x < x0 + w; x++)
    fbPixel(x, y, color);
}

// Simple 8×8 font character renderer (built-in).
// For a real product, use LVGL or a proper font engine.
// This provides basic text for status display.
extern const uint8_t font8x8_basic[128][8]; // from font8x8.cpp

static void fbChar(int x0, int y0, char ch, uint16_t color, int scale) {
  if (ch < 0 || ch > 127)
    ch = '?';
  for (int row = 0; row < 8; row++) {
    uint8_t bits = font8x8_basic[(int)ch][row];
    for (int col = 0; col < 8; col++) {
      if (bits & (1 << col)) {
        for (int sy = 0; sy < scale; sy++)
          for (int sx = 0; sx < scale; sx++)
            fbPixel(x0 + col * scale + sx, y0 + row * scale + sy, color);
      }
    }
  }
}

static void fbString(int x0, int y0, const char *str, uint16_t color, int scale) {
  int x = x0;
  while (*str) {
    if (*str == '\n') {
      y0 += 8 * scale + 2;
      x = x0;
      str++;
      continue;
    }
    fbChar(x, y0, *str, color, scale);
    x += 8 * scale;
    str++;
  }
}

static int textPixelWidth(const char *str, int scale) {
  int maxw = 0, w = 0;
  while (*str) {
    if (*str == '\n') {
      if (w > maxw)
        maxw = w;
      w = 0;
    } else
      w += 8 * scale;
    str++;
  }
  return w > maxw ? w : maxw;
}

// Draw a circle outline (Bresenham).
static void fbCircle(int cx, int cy, int r, uint16_t color) {
  int x = 0, y = r, d = 3 - 2 * r;
  while (x <= y) {
    fbPixel(cx + x, cy + y, color);
    fbPixel(cx - x, cy + y, color);
    fbPixel(cx + x, cy - y, color);
    fbPixel(cx - x, cy - y, color);
    fbPixel(cx + y, cy + x, color);
    fbPixel(cx - y, cy + x, color);
    fbPixel(cx + y, cy - x, color);
    fbPixel(cx - y, cy - x, color);
    if (d < 0)
      d += 4 * x + 6;
    else {
      d += 4 * (x - y) + 10;
      y--;
    }
    x++;
  }
}

// ---------------------------------------------------------------------------
bool LcdUi::Begin() {
  Serial.println("[lcd] initializing panel...");

  panel = new Board();
  panel->init();
  panel->begin();

  lcd = panel->getLCD();
  if (!lcd) {
    Serial.println("[lcd] FAILED — no LCD device");
    return false;
  }

  // Allocate framebuffer in PSRAM.
  fb = (uint16_t *)ps_malloc(kWidth * kHeight * sizeof(uint16_t));
  if (!fb) {
    Serial.println("[lcd] FAILED — cannot allocate framebuffer");
    return false;
  }

  // Backlight on.
  auto *bl = panel->getBacklight();
  if (bl)
    bl->setBrightness(80); // 0–100

  // Clear to black.
  fbFill(kBlack);
  lcd->drawBitmap(0, 0, kWidth, kHeight, (const uint8_t *)fb);

  initialized_ = true;
  Serial.println("[lcd] ready — 360x360 ST77916 QSPI");
  return true;
}

// ---------------------------------------------------------------------------
void LcdUi::SetBrightness(uint8_t level) {
  if (!panel)
    return;
  auto *bl = panel->getBacklight();
  if (bl)
    bl->setBrightness(level);
}

// ---------------------------------------------------------------------------
void LcdUi::Render(const MediaSnapshot &media, VoicePhase phase, const std::string &headline,
                   const std::string &summary, bool show_ring) {
  if (!initialized_) {
    // Fallback to serial.
    Serial.printf("[ui] [%d] %s — %s\n", (int)phase, headline.c_str(), summary.c_str());
    return;
  }

  DrawBackground();
  DrawStatusBar(media);

  if (show_ring) {
    DrawVoiceRing(phase);
  }

  // Headline — large centered text.
  DrawCenteredText(kCenter - 30, headline.c_str(), kWhite, 3);

  // Summary — smaller, below headline (word-wrap basic).
  // Truncate if too long for the round screen.
  std::string trunc = summary.substr(0, 80);
  DrawCenteredText(kCenter + 10, trunc.c_str(), kCyan, 2);

  Flush();
}

// ---------------------------------------------------------------------------
void LcdUi::RenderWifi(WifiManager::State state, const std::string &info,
                       const std::string &ap_ssid, const std::string &ap_pass,
                       const std::string &ap_ip) {
  if (!initialized_)
    return;

  DrawBackground();

  switch (state) {
  case WifiManager::State::kConnecting:
    // Pulsing cyan ring.
    for (int r = kCenter - 8; r <= kCenter - 4; r++)
      fbCircle(kCenter, kCenter, r, kCyan);
    DrawCenteredText(kCenter - 40, "WiFi", kWhite, 3);
    DrawCenteredText(kCenter, "Connexion...", kCyan, 2);
    if (!info.empty()) {
      DrawCenteredText(kCenter + 30, info.c_str(), kDarkGray, 2);
    }
    break;

  case WifiManager::State::kApMode:
    // Orange ring for AP mode.
    for (int r = kCenter - 8; r <= kCenter - 4; r++)
      fbCircle(kCenter, kCenter, r, kOrange);
    DrawCenteredText(60, "MODE CONFIG", kOrange, 2);
    DrawCenteredText(kCenter - 50, "WiFi:", kWhite, 2);
    DrawCenteredText(kCenter - 25, ap_ssid.c_str(), kCyan, 2);
    DrawCenteredText(kCenter + 5, "Pass:", kWhite, 2);
    DrawCenteredText(kCenter + 30, ap_pass.c_str(), kCyan, 2);
    DrawCenteredText(kCenter + 65, "http://", kDarkGray, 1);
    DrawCenteredText(kCenter + 80, ap_ip.c_str(), kGreen, 2);
    DrawCenteredText(kHeight - 50, "Connectez-vous au", kDarkGray, 1);
    DrawCenteredText(kHeight - 38, "WiFi ci-dessus", kDarkGray, 1);
    break;

  case WifiManager::State::kConnected:
    for (int r = kCenter - 8; r <= kCenter - 4; r++)
      fbCircle(kCenter, kCenter, r, kGreen);
    DrawCenteredText(kCenter - 20, "Connecte!", kGreen, 3);
    DrawCenteredText(kCenter + 20, info.c_str(), kWhite, 2);
    break;

  case WifiManager::State::kFailed:
    for (int r = kCenter - 8; r <= kCenter - 4; r++)
      fbCircle(kCenter, kCenter, r, kRed);
    DrawCenteredText(kCenter - 20, "Echec WiFi", kRed, 3);
    DrawCenteredText(kCenter + 20, info.c_str(), kDarkGray, 2);
    DrawCenteredText(kCenter + 50, "Appui long=config", kYellow, 1);
    break;

  default:
    break;
  }

  Flush();
}

// ---------------------------------------------------------------------------
void LcdUi::Flush() {
  if (initialized_ && lcd && fb) {
    lcd->drawBitmap(0, 0, kWidth, kHeight, (const uint8_t *)fb);
  }
}

// ---------------------------------------------------------------------------
void LcdUi::DrawBackground() {
  fbFill(kBlack);
  // Circular mask hint — draw a subtle circle border.
  fbCircle(kCenter, kCenter, kCenter - 1, kDarkGray);
  fbCircle(kCenter, kCenter, kCenter - 2, kDarkGray);
}

void LcdUi::DrawCenteredText(int y, const char *text, uint16_t color, int sz) {
  int w = textPixelWidth(text, sz);
  int x = (kWidth - w) / 2;
  if (x < 10)
    x = 10;
  fbString(x, y, text, color, sz);
}

void LcdUi::DrawStatusBar(const MediaSnapshot &media) {
  // Top area: mode + volume.
  char buf[48];
  const char *mode_str = "IDLE";
  if (media.mode == MediaMode::kMp3)
    mode_str = "MP3";
  if (media.mode == MediaMode::kRadio)
    mode_str = "RADIO";
  snprintf(buf, sizeof(buf), "%s  vol:%d", mode_str, media.volume);
  DrawCenteredText(40, buf, kYellow, 2);

  // Battery indicator (bottom).
  if (media.battery_pct >= 0) {
    snprintf(buf, sizeof(buf), "BAT %d%%", media.battery_pct);
    uint16_t bat_color = media.battery_pct > 20 ? kGreen : kRed;
    DrawCenteredText(kHeight - 60, buf, bat_color, 2);
  }

  // WiFi RSSI (bottom).
  if (media.wifi_rssi != 0) {
    snprintf(buf, sizeof(buf), "WiFi %ddBm", media.wifi_rssi);
    DrawCenteredText(kHeight - 40, buf, kDarkGray, 1);
  }
}

void LcdUi::DrawVoiceRing(VoicePhase phase) {
  uint16_t color = kBlue;
  switch (phase) {
  case VoicePhase::kRecording:
    color = kRed;
    break;
  case VoicePhase::kThinking:
    color = kOrange;
    break;
  case VoicePhase::kSpeaking:
    color = kGreen;
    break;
  case VoicePhase::kError:
    color = kRed;
    break;
  default:
    color = kBlue;
    break;
  }
  for (int r = kCenter - 10; r <= kCenter - 5; r++) {
    fbCircle(kCenter, kCenter, r, color);
  }
}
