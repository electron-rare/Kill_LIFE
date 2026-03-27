#pragma once

#include <string>

/// Result of an OTA check.
struct OtaCheckResult {
  enum class Status {
    kUpToDate,        ///< Already on latest version.
    kUpdateAvailable, ///< Newer firmware found.
    kCheckFailed,     ///< Could not reach backend.
    kFlashFailed,     ///< Download or flash error.
    kFlashOk,         ///< Flash successful — pending reboot.
  };

  Status status = Status::kCheckFailed;
  std::string latest_version;
  std::string url;
  std::string notes;
  std::string error;
};

/// OTA firmware update manager.
///
/// Usage (call from setup() or a periodic timer):
///   OtaManager ota("1.0.0");
///   ota.SetBackendUrl("http://192.168.1.42:8000");
///   auto result = ota.CheckAndUpdate();
///   if (result.status == OtaCheckResult::Status::kFlashOk) ESP.restart();
///
/// The backend endpoint:
///   POST /device/v1/firmware/check
///   Body: {"version": "<current>", "device_id": "<id>"}
///   Response: {"latest": "1.0.1", "url": "http://...", "notes": "..."}
///             or {"latest": "1.0.0"} when up-to-date
class OtaManager {
public:
  explicit OtaManager(const std::string &current_version);

  void SetBackendUrl(const std::string &url) { backend_url_ = url; }
  void SetDeviceId(const std::string &id) { device_id_ = id; }

  /// Check the backend for a newer version and flash if found.
  /// Blocks during download (typically 30–120s on good WiFi).
  OtaCheckResult CheckAndUpdate();

  /// Convenience: just check version without flashing.
  OtaCheckResult CheckOnly();

  const std::string &current_version() const { return current_version_; }

private:
  OtaCheckResult FetchLatestInfo();
  bool FlashFromUrl(const std::string &url);

  std::string current_version_;
  std::string backend_url_ = "http://192.168.1.42:8000";
  std::string device_id_ = "esp32-001";
};
