#include "ota_manager.h"
#include "firmware_utils.h"

#include <Arduino.h>
#include <ArduinoJson.h>
#include <HTTPClient.h>
#include <Update.h>
#include <WiFi.h>
#include <WiFiClient.h>

OtaManager::OtaManager(const std::string& current_version)
    : current_version_(current_version) {}

OtaCheckResult OtaManager::CheckOnly() {
  return FetchLatestInfo();
}

OtaCheckResult OtaManager::CheckAndUpdate() {
  OtaCheckResult info = FetchLatestInfo();

  if (info.status == OtaCheckResult::Status::kCheckFailed) {
    return info;
  }
  if (info.status == OtaCheckResult::Status::kUpToDate) {
    return info;
  }

  // Update available — flash it.
  if (FlashFromUrl(info.url)) {
    info.status = OtaCheckResult::Status::kFlashOk;
  } else {
    info.status = OtaCheckResult::Status::kFlashFailed;
    info.error = "flash error";
  }
  return info;
}

OtaCheckResult OtaManager::FetchLatestInfo() {
  OtaCheckResult result;

  if (!FwIsValidBackendUrl(backend_url_)) {
    result.status = OtaCheckResult::Status::kCheckFailed;
    result.error = "invalid backend URL";
    return result;
  }

  const std::string endpoint = backend_url_ + "/device/v1/firmware/check";

  HTTPClient http;
  http.begin(endpoint.c_str());
  http.addHeader("Content-Type", "application/json");

  JsonDocument req_doc;
  req_doc["version"] = current_version_;
  req_doc["device_id"] = device_id_;
  std::string body;
  serializeJson(req_doc, body);

  const int code = http.POST(body.c_str());
  if (code != 200) {
    http.end();
    result.status = OtaCheckResult::Status::kCheckFailed;
    result.error = "HTTP " + std::to_string(code);
    return result;
  }

  const String payload = http.getString();
  http.end();

  JsonDocument resp_doc;
  if (deserializeJson(resp_doc, payload) != DeserializationError::Ok) {
    result.status = OtaCheckResult::Status::kCheckFailed;
    result.error = "JSON parse error";
    return result;
  }

  result.latest_version = resp_doc["latest"].as<std::string>();
  result.url            = resp_doc["url"].as<std::string>();
  result.notes          = resp_doc["notes"].as<std::string>();

  if (FwCompareVersions(current_version_, result.latest_version) >= 0) {
    result.status = OtaCheckResult::Status::kUpToDate;
  } else {
    result.status = OtaCheckResult::Status::kUpdateAvailable;
  }

  return result;
}

bool OtaManager::FlashFromUrl(const std::string& url) {
  if (url.empty()) return false;

  HTTPClient http;
  http.begin(url.c_str());
  const int code = http.GET();
  if (code != 200) {
    http.end();
    Serial.printf("[OTA] download failed HTTP %d\n", code);
    return false;
  }

  const int content_len = http.getSize();
  WiFiClient* stream = http.getStreamPtr();

  if (!Update.begin(content_len > 0 ? content_len : UPDATE_SIZE_UNKNOWN)) {
    http.end();
    Serial.printf("[OTA] Update.begin failed: %s\n",
                  Update.errorString());
    return false;
  }

  Serial.printf("[OTA] flashing %d bytes from %s\n", content_len, url.c_str());

  const size_t written = Update.writeStream(*stream);
  http.end();

  if (!Update.end()) {
    Serial.printf("[OTA] Update.end failed: %s\n", Update.errorString());
    return false;
  }

  if (!Update.isFinished()) {
    Serial.println("[OTA] Update not finished");
    return false;
  }

  Serial.printf("[OTA] flash OK — wrote %zu bytes. Reboot pending.\n", written);
  return true;
}
