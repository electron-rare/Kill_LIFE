#ifndef UNIT_TEST
#include <Arduino.h>

#include <WiFi.h>

#include "wifi_scanner.h"

static const uint32_t SCAN_INTERVAL_MS = 30000;

static String build_scan_json(int n) {
  if (n < 0)
    return "{\"error\":\"scan_failed\"}";
  if (n == 0)
    return "[]";
  String json = "[";
  for (int i = 0; i < n; i++) {
    if (i > 0)
      json += ",";
    json += serialize_network(WiFi.SSID(i), WiFi.RSSI(i), WiFi.channel(i),
                              static_cast<int>(WiFi.encryptionType(i)));
  }
  json += "]";
  WiFi.scanDelete();
  return json;
}

void setup() {
  Serial.begin(115200);
  delay(200);
  Serial.println("[boot] wifi-scanner v1");
  WiFi.mode(WIFI_STA);
  WiFi.disconnect();
  delay(100);
}

void loop() {
  Serial.println("[scan] start");
  int n = WiFi.scanNetworks(false);
  String result = build_scan_json(n);
  Serial.print("[scan] ");
  Serial.println(result);
  delay(SCAN_INTERVAL_MS);
}
#endif // UNIT_TEST
