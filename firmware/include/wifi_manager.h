#pragma once

#include <functional>
#include <string>
#include <vector>

/// WiFi connection manager with AP fallback and captive portal.
///
/// Flow:
///   1. On boot, try saved credentials from NVS
///   2. If no credentials or connection fails → start AP mode
///   3. AP mode: captive portal web UI for config
///   4. Long-press BOOT button (3s) → force AP mode
///
/// NVS keys: "wifi_ssid", "wifi_pass", "backend_url"
class WifiManager {
public:
  enum class State {
    kIdle,
    kConnecting,
    kConnected,
    kApMode,
    kFailed,
  };

  struct ScanResult {
    std::string ssid;
    int rssi;
    bool open; // no encryption
  };

  using OnStateChange = std::function<void(State state, const std::string &info)>;

  /// AP mode settings.
  void SetApCredentials(const std::string &ssid, const std::string &password);

  /// Register callback for state changes (for LCD updates).
  void SetOnStateChange(OnStateChange cb) { on_state_change_ = cb; }

  /// Load saved credentials and try to connect.
  /// Falls back to AP mode if no credentials or connection fails.
  void Begin();

  /// Call from loop() — handles AP mode web server.
  void Loop();

  /// Force switch to AP mode (e.g. from long-press).
  void StartApMode();

  /// Current state.
  State state() const { return state_; }
  bool IsConnected() const { return state_ == State::kConnected; }
  bool IsApMode() const { return state_ == State::kApMode; }

  /// Connected network info.
  std::string ssid() const { return current_ssid_; }
  std::string ip() const;
  int rssi() const;

  /// AP mode info.
  std::string apSsid() const { return ap_ssid_; }
  std::string apPassword() const { return ap_password_; }
  std::string apIp() const;

  /// Saved backend URL.
  std::string backendUrl() const { return backend_url_; }

  /// Scan available networks (blocking, ~2s).
  std::vector<ScanResult> Scan();

private:
  void LoadCredentials();
  void SaveCredentials(const std::string &ssid, const std::string &pass,
                       const std::string &backend);
  bool TryConnect(const std::string &ssid, const std::string &pass, uint32_t timeout_ms = 12000);
  void SetupApWebServer();
  void StopApWebServer();
  void SetState(State s, const std::string &info = "");

  State state_ = State::kIdle;
  OnStateChange on_state_change_;

  std::string saved_ssid_;
  std::string saved_pass_;
  std::string backend_url_ = "http://192.168.1.42:8000";
  std::string current_ssid_;

  std::string ap_ssid_ = "KillLife-Setup";
  std::string ap_password_ = "killlife";

  bool server_running_ = false;
};
