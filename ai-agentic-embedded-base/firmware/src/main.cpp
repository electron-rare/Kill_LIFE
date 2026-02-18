#include <Arduino.h>

static uint32_t last_ms = 0;

void setup() {
  Serial.begin(115200);
  delay(200);
  Serial.println("[base] boot");
}

void loop() {
  const uint32_t now = millis();
  if (now - last_ms >= 1000) {
    last_ms = now;
    Serial.println("[base] tick");
  }
}
