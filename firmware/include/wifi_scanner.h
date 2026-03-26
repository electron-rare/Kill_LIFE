#pragma once

#include "firmware_utils.h"  // WifiNetwork, FwRssiQuality, FwWifiToJson

#include <cstdint>
#include <string>
#include <vector>

/// Lightweight WiFi scanner.
///
/// Usage:
///   WifiScanner scanner;
///   auto nets = scanner.Scan(4000);
///   Serial.println(scanner.last_json().c_str());
///
/// Pure utility functions (RssiQuality, ToJson, SortByRssi) live in
/// firmware_utils.h and are tested natively via Unity.
class WifiScanner {
 public:
  /// Scan available networks, block up to timeout_ms.
  /// Returns networks sorted by RSSI descending.
  std::vector<WifiNetwork> Scan(uint32_t timeout_ms = 4000);

  /// JSON string from the last Scan() call.
  const std::string& last_json() const { return last_json_; }

  /// Duration of the last Scan() call in ms.
  uint32_t last_duration_ms() const { return last_duration_ms_; }

 private:
  std::string last_json_;
  uint32_t last_duration_ms_ = 0;
};
