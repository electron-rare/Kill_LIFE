#pragma once

#include "voice_controller.h"

#include <sstream>
#include <string>

// ---------------------------------------------------------------------------
// Pure C++ utility functions — no Arduino dependencies.
// Extracted here so they can be compiled and tested on native (Unity).
// ---------------------------------------------------------------------------

/// Human-readable idle summary for the LCD / UI.
inline std::string FwIdleSummary(const MediaSnapshot& media) {
  auto mode_label = [](MediaMode m) -> const char* {
    switch (m) {
      case MediaMode::kMp3:   return "MP3";
      case MediaMode::kRadio: return "Radio";
      default:                return "Idle";
    }
  };

  std::ostringstream s;
  s << mode_label(media.mode) << " | volume " << media.volume;
  if (media.mode == MediaMode::kRadio && !media.station.empty()) {
    s << " | " << media.station;
  } else if (media.mode == MediaMode::kMp3 && !media.track.empty()) {
    s << " | " << media.track;
  } else if (!media.playing) {
    s << " | pause";
  }
  return s.str();
}

/// True if a playback_started event should be emitted after applying an intent.
inline bool FwShouldPublishPlaybackStarted(const MediaSnapshot& before,
                                           const MediaSnapshot& after,
                                           const VoiceIntent& intent) {
  if (!after.playing) return false;

  if (intent.type == "play" || intent.type == "switch_mode" ||
      intent.type == "select_station" || intent.type == "next" ||
      intent.type == "previous") {
    return !before.playing || before.station != after.station ||
           before.track != after.track || before.mode != after.mode;
  }

  return false;
}

/// Compare semver strings "MAJOR.MINOR.PATCH".
/// Returns -1 / 0 / +1 (like strcmp).
inline int FwCompareVersions(const std::string& a, const std::string& b) {
  auto parse = [](const std::string& v, int out[3]) {
    int i = 0;
    std::istringstream ss(v);
    std::string tok;
    while (std::getline(ss, tok, '.') && i < 3) {
      try { out[i++] = std::stoi(tok); } catch (...) { out[i++] = 0; }
    }
    while (i < 3) out[i++] = 0;
  };
  int va[3] = {}, vb[3] = {};
  parse(a, va);
  parse(b, vb);
  for (int i = 0; i < 3; ++i) {
    if (va[i] < vb[i]) return -1;
    if (va[i] > vb[i]) return +1;
  }
  return 0;
}

/// Minimal WAV header validation — checks RIFF/WAVE magic.
inline bool FwIsValidWavHeader(const uint8_t* data, size_t len) {
  if (!data || len < 12) return false;
  // Bytes 0-3: "RIFF", bytes 8-11: "WAVE"
  return data[0] == 'R' && data[1] == 'I' && data[2] == 'F' &&
         data[3] == 'F' && data[8] == 'W' && data[9] == 'A' &&
         data[10] == 'V' && data[11] == 'E';
}

/// Validates that a backend URL starts with http:// or https://.
inline bool FwIsValidBackendUrl(const std::string& url) {
  return url.substr(0, 7) == "http://" || url.substr(0, 8) == "https://";
}

// ---------------------------------------------------------------------------
// WiFi Scanner utilities — pure C++, no Arduino.
// ---------------------------------------------------------------------------

/// Network entry produced by WifiScanner::Scan().
struct WifiNetwork {
  std::string ssid;
  int rssi    = -100;
  bool open   = false;
  int channel = 0;
};

/// Map RSSI (dBm) to a 0–100 quality score.
/// -50 dBm → 100, -100 dBm → 0, clamped.
inline int FwRssiQuality(int rssi) {
  if (rssi >= -50) return 100;
  if (rssi <= -100) return 0;
  return (rssi + 100) * 2;  // linear in [-100, -50]
}

/// Serialize a list of networks to JSON.
/// Output: {"networks":[{"ssid":"...","rssi":-62,"open":false,"channel":6,"quality":76}],"count":N,"duration_ms":T}
inline std::string FwWifiToJson(const std::vector<WifiNetwork>& nets,
                                uint32_t duration_ms) {
  std::ostringstream j;
  j << "{\"networks\":[";
  for (size_t i = 0; i < nets.size(); ++i) {
    const auto& n = nets[i];
    if (i > 0) j << ",";
    // Escape backslash and double-quote in SSID (minimal safe escaping).
    std::string ssid_esc;
    ssid_esc.reserve(n.ssid.size());
    for (char c : n.ssid) {
      if (c == '"')  { ssid_esc += "\\\""; }
      else if (c == '\\') { ssid_esc += "\\\\"; }
      else           { ssid_esc += c; }
    }
    j << "{\"ssid\":\"" << ssid_esc << "\""
      << ",\"rssi\":"   << n.rssi
      << ",\"open\":"   << (n.open ? "true" : "false")
      << ",\"channel\":" << n.channel
      << ",\"quality\":" << FwRssiQuality(n.rssi)
      << "}";
  }
  j << "],\"count\":" << nets.size()
    << ",\"duration_ms\":" << duration_ms
    << "}";
  return j.str();
}

/// Comparator: sort networks by RSSI descending (best signal first).
inline bool FwNetworkBetterSignal(const WifiNetwork& a, const WifiNetwork& b) {
  return a.rssi > b.rssi;
}
