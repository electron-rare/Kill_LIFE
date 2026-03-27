#pragma once

#include "voice_controller.h"
#include "wifi_manager.h"

/// LCD UI renderer for the Waveshare 1.85" round display (ST77916 QSPI).
/// Uses ESP32_Display_Panel for hardware abstraction.
class LcdUi : public UiRenderer {
public:
  /// Initialise the display panel and backlight.
  bool Begin();

  /// UiRenderer implementation — draw current state on the round LCD.
  void Render(const MediaSnapshot &media, VoicePhase phase, const std::string &headline,
              const std::string &summary, bool show_ring) override;

  /// Show WiFi status screen (connecting, AP mode, etc.).
  void RenderWifi(WifiManager::State state, const std::string &info,
                  const std::string &ap_ssid = "", const std::string &ap_pass = "",
                  const std::string &ap_ip = "");

  /// Set backlight brightness (0–100).
  void SetBrightness(uint8_t level);

  /// Push current framebuffer to LCD.
  void Flush();

private:
  void DrawBackground();
  void DrawCenteredText(int y, const char *text, uint16_t color, int size);
  void DrawStatusBar(const MediaSnapshot &media);
  void DrawVoiceRing(VoicePhase phase);

  bool initialized_ = false;
};
