#include "wifi_scanner.h"

#include <algorithm>
#include <Arduino.h>
#include <WiFi.h>

std::vector<WifiNetwork> WifiScanner::Scan(uint32_t timeout_ms) {
  const uint32_t t_start = millis();

  // Synchronous scan — blocks until done or timeout.
  // The ESP32 WiFi library doesn't expose a per-scan timeout directly;
  // we set channel_time to bound per-channel dwell.
  const int n = WiFi.scanNetworks(/*async=*/false, /*show_hidden=*/false,
                                  /*passive=*/false,
                                  /*max_ms_per_chan=*/120);

  const uint32_t elapsed = millis() - t_start;

  std::vector<WifiNetwork> result;

  if (n > 0) {
    result.reserve(static_cast<size_t>(n));
    for (int i = 0; i < n; ++i) {
      const String ssid = WiFi.SSID(i);
      if (ssid.isEmpty()) continue;  // skip hidden networks

      WifiNetwork net;
      net.ssid    = ssid.c_str();
      net.rssi    = WiFi.RSSI(i);
      net.open    = (WiFi.encryptionType(i) == WIFI_AUTH_OPEN);
      net.channel = WiFi.channel(i);
      result.push_back(std::move(net));
    }

    // Best signal first.
    std::sort(result.begin(), result.end(), FwNetworkBetterSignal);
  }

  // Cap elapsed if scan returned very fast (sanity).
  last_duration_ms_ = elapsed;
  last_json_        = FwWifiToJson(result, elapsed);

  Serial.printf("[wifi_scan] found %zu network(s) in %u ms\n",
                result.size(), elapsed);
  Serial.println(last_json_.c_str());

  WiFi.scanDelete();
  return result;
}
