#include "http_backend.h"

#include <Arduino.h>

#include <HTTPClient.h>
#include <WiFi.h>

// ArduinoJson for parsing responses
#include <ArduinoJson.h>

HttpBackend::HttpBackend(const std::string &base_url) : base_url_(base_url) {
  // Strip trailing slash.
  while (!base_url_.empty() && base_url_.back() == '/') {
    base_url_.pop_back();
  }
}

// ---------------------------------------------------------------------------
// POST /device/v1/player/event  (JSON body)
// ---------------------------------------------------------------------------
bool HttpBackend::SendPlayerEvent(const std::string &device_id, const std::string &event_name,
                                  const MediaSnapshot &media, const std::string &detail) {
  HTTPClient http;
  const std::string url = base_url_ + "/device/v1/player/event";
  http.begin(url.c_str());
  http.addHeader("Content-Type", "application/json");
  http.setTimeout(5000);

  JsonDocument doc;
  doc["device_id"] = device_id;
  doc["event"] = event_name;
  doc["detail"] = detail;

  // Media state fields
  switch (media.mode) {
  case MediaMode::kMp3:
    doc["mode"] = "mp3";
    break;
  case MediaMode::kRadio:
    doc["mode"] = "radio";
    break;
  default:
    doc["mode"] = "idle";
    break;
  }
  doc["playing"] = media.playing;
  doc["volume"] = media.volume;
  if (!media.station.empty())
    doc["station"] = media.station;
  if (!media.track.empty())
    doc["track"] = media.track;
  if (media.battery_pct >= 0)
    doc["battery_pct"] = media.battery_pct;
  if (!media.wifi_ssid.empty())
    doc["wifi_ssid"] = media.wifi_ssid;
  if (media.wifi_rssi != 0)
    doc["wifi_rssi"] = media.wifi_rssi;

  String body;
  serializeJson(doc, body);

  int code = http.POST(body);
  http.end();

  if (code == 200) {
    Serial.printf("[http] event OK: %s\n", event_name.c_str());
    return true;
  }
  Serial.printf("[http] event FAIL: %d\n", code);
  return false;
}

// ---------------------------------------------------------------------------
// POST /device/v1/voice/session  (multipart/form-data)
//   Fields: device_id, mode, current_media (JSON), audio (WAV file)
// ---------------------------------------------------------------------------
VoiceSessionResponse HttpBackend::SubmitVoiceSession(const std::string &device_id,
                                                     const MediaSnapshot &media,
                                                     const std::vector<uint8_t> &wav_data) {

  VoiceSessionResponse result;

  // Build current_media JSON string.
  JsonDocument media_doc;
  switch (media.mode) {
  case MediaMode::kMp3:
    media_doc["mode"] = "mp3";
    break;
  case MediaMode::kRadio:
    media_doc["mode"] = "radio";
    break;
  default:
    media_doc["mode"] = "idle";
    break;
  }
  media_doc["playing"] = media.playing;
  media_doc["volume"] = media.volume;
  if (!media.station.empty())
    media_doc["station"] = media.station;
  if (!media.track.empty())
    media_doc["track"] = media.track;
  if (media.battery_pct >= 0)
    media_doc["battery_pct"] = media.battery_pct;
  if (!media.wifi_ssid.empty())
    media_doc["wifi_ssid"] = media.wifi_ssid;
  if (media.wifi_rssi != 0)
    media_doc["wifi_rssi"] = media.wifi_rssi;

  JsonArray stations = media_doc["available_stations"].to<JsonArray>();
  for (const auto &s : media.available_stations) {
    stations.add(s);
  }

  String media_json;
  serializeJson(media_doc, media_json);

  // Mode string.
  const char *mode_str = "idle";
  if (media.mode == MediaMode::kMp3)
    mode_str = "mp3";
  if (media.mode == MediaMode::kRadio)
    mode_str = "radio";

  // Build multipart body manually (ESP32 HTTPClient has no multipart helper).
  const String boundary = "----KillLife" + String(millis());
  String head;
  head += "--" + boundary + "\r\n";
  head += "Content-Disposition: form-data; name=\"device_id\"\r\n\r\n";
  head += String(device_id.c_str()) + "\r\n";

  head += "--" + boundary + "\r\n";
  head += "Content-Disposition: form-data; name=\"mode\"\r\n\r\n";
  head += String(mode_str) + "\r\n";

  head += "--" + boundary + "\r\n";
  head += "Content-Disposition: form-data; name=\"current_media\"\r\n\r\n";
  head += media_json + "\r\n";

  head += "--" + boundary + "\r\n";
  head += "Content-Disposition: form-data; name=\"audio\"; filename=\"recording.wav\"\r\n";
  head += "Content-Type: audio/wav\r\n\r\n";

  String tail = "\r\n--" + boundary + "--\r\n";

  const size_t total_len = head.length() + wav_data.size() + tail.length();

  // Use WiFiClient for streaming.
  WiFiClient tcp;
  HTTPClient http;
  const std::string url = base_url_ + "/device/v1/voice/session";
  http.begin(tcp, url.c_str());
  http.addHeader("Content-Type", "multipart/form-data; boundary=" + boundary);
  http.addHeader("Content-Length", String((unsigned long)total_len));
  http.setTimeout(30000); // STT + LLM + TTS can take a while.

  // sendRequest allows streaming the body in parts.
  // We must use the low-level approach.
  if (!tcp.connect(WiFi.gatewayIP(), 8000)) {
    // Fallback: extract host/port from base_url.
    Serial.println("[http] voice session: TCP connect failed, trying url");
  }

  // Use the simpler POST approach — concatenate head + wav + tail.
  // For ESP32 with PSRAM this is fine up to ~256 KB.
  std::vector<uint8_t> body;
  body.reserve(total_len);
  body.insert(body.end(), (uint8_t *)head.c_str(), (uint8_t *)head.c_str() + head.length());
  body.insert(body.end(), wav_data.begin(), wav_data.end());
  body.insert(body.end(), (uint8_t *)tail.c_str(), (uint8_t *)tail.c_str() + tail.length());

  int code = http.POST(body.data(), body.size());

  if (code != 200) {
    Serial.printf("[http] voice session FAIL: %d\n", code);
    result.ok = false;
    result.error = "http_" + std::string(String(code).c_str());
    http.end();
    return result;
  }

  // Parse JSON response.
  String resp = http.getString();
  http.end();

  JsonDocument resp_doc;
  DeserializationError err = deserializeJson(resp_doc, resp);
  if (err) {
    Serial.printf("[http] JSON parse error: %s\n", err.c_str());
    result.ok = false;
    result.error = "json_parse_error";
    return result;
  }

  result.ok = resp_doc["ok"] | false;
  result.session_id = resp_doc["session_id"] | "";
  result.transcript = resp_doc["transcript"] | "";
  result.reply_text = resp_doc["reply_text"] | "";
  result.provider = resp_doc["provider"] | "none";
  result.error = resp_doc["error"] | "";

  // Reply audio URL.
  const char *audio_url = resp_doc["reply_audio_url"];
  if (audio_url) {
    result.reply_audio_url = std::string(audio_url);
  }

  // Intent.
  JsonObject intent = resp_doc["intent"];
  if (intent) {
    result.intent.type = intent["type"] | "none";
    result.intent.target = intent["target"] | "";
    result.intent.value = intent["value"] | "";
    result.intent.spoken_confirmation = intent["spoken_confirmation"] | "";
    result.intent.resume_media_after_tts = intent["resume_media_after_tts"] | false;
  }

  // Player action.
  const char *pa = resp_doc["player_action"];
  if (pa) {
    std::string pa_str(pa);
    if (pa_str == "duck")
      result.player_action = PlayerAction::kDuck;
    else if (pa_str == "stop_resume")
      result.player_action = PlayerAction::kStopResume;
    else
      result.player_action = PlayerAction::kNone;
  }

  Serial.printf("[http] voice session OK — transcript: %s\n", result.transcript.c_str());
  return result;
}

// ---------------------------------------------------------------------------
// GET reply audio WAV
// ---------------------------------------------------------------------------
bool HttpBackend::DownloadReplyAudio(const std::string &audio_url, std::vector<uint8_t> *wav_data) {
  HTTPClient http;
  http.begin(audio_url.c_str());
  http.setTimeout(10000);

  int code = http.GET();
  if (code != 200) {
    Serial.printf("[http] download reply FAIL: %d\n", code);
    http.end();
    return false;
  }

  int len = http.getSize();
  WiFiClient *stream = http.getStreamPtr();
  if (!stream) {
    http.end();
    return false;
  }

  wav_data->clear();
  if (len > 0) {
    wav_data->reserve(len);
  }

  uint8_t buf[1024];
  while (http.connected() && (len > 0 || len == -1)) {
    size_t avail = stream->available();
    if (avail == 0) {
      delay(1);
      continue;
    }
    size_t to_read = avail;
    if (to_read > sizeof(buf))
      to_read = sizeof(buf);
    size_t read = stream->readBytes(buf, to_read);
    wav_data->insert(wav_data->end(), buf, buf + read);
    if (len > 0)
      len -= read;
  }

  http.end();
  Serial.printf("[http] downloaded %u bytes reply audio\n", (unsigned)wav_data->size());
  return wav_data->size() > 44; // At least a WAV header.
}
