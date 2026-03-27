#pragma once

#ifdef UNIT_TEST
#include <sstream>
#include <string>
using String = std::string;

static inline String escape_json_string(const String &s) {
  String out;
  out.reserve(s.size());
  for (char c : s) {
    if (c == '"')
      out += "\\\"";
    else if (c == '\\')
      out += "\\\\";
    else
      out += c;
  }
  return out;
}

static inline String itos(int n) {
  return std::to_string(n);
}

#else // Arduino
#include <Arduino.h>

static inline String escape_json_string(const String &s) {
  String out;
  out.reserve(s.length());
  for (size_t i = 0; i < s.length(); i++) {
    char c = s[i];
    if (c == '"')
      out += "\\\"";
    else if (c == '\\')
      out += "\\\\";
    else
      out += c;
  }
  return out;
}

static inline String itos(int n) {
  return String(n);
}

#endif // UNIT_TEST

// Serialize a single WiFi network entry to a JSON object string.
static inline String serialize_network(const String &ssid, int rssi, int channel, int auth) {
  return String("{\"ssid\":\"") + escape_json_string(ssid) + "\",\"rssi\":" + itos(rssi) +
         ",\"channel\":" + itos(channel) + ",\"auth\":" + itos(auth) + "}";
}
