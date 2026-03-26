/// @file test_basic.cpp
/// Unity tests for pure C++ firmware logic (no Arduino deps).
/// Covers: IdleSummary, ShouldPublishPlaybackStarted, version comparison,
///         WAV header validation, backend URL validation.

#include <unity.h>
#include <algorithm>
#include <cstring>
#include "../../include/firmware_utils.h"

// ---------------------------------------------------------------------------
// IdleSummary
// ---------------------------------------------------------------------------

void test_idle_summary_idle_mode() {
  MediaSnapshot m;
  m.mode = MediaMode::kIdle;
  m.volume = 40;
  m.playing = true;  // playing flag ignored in Idle mode
  std::string s = FwIdleSummary(m);
  TEST_ASSERT_EQUAL_STRING("Idle | volume 40", s.c_str());
}

void test_idle_summary_idle_paused() {
  MediaSnapshot m;
  m.mode = MediaMode::kIdle;
  m.volume = 40;
  m.playing = false;
  std::string s = FwIdleSummary(m);
  TEST_ASSERT_EQUAL_STRING("Idle | volume 40 | pause", s.c_str());
}

void test_idle_summary_radio_with_station() {
  MediaSnapshot m;
  m.mode = MediaMode::kRadio;
  m.volume = 60;
  m.station = "FIP";
  m.playing = true;
  std::string s = FwIdleSummary(m);
  TEST_ASSERT_EQUAL_STRING("Radio | volume 60 | FIP", s.c_str());
}

void test_idle_summary_mp3_with_track() {
  MediaSnapshot m;
  m.mode = MediaMode::kMp3;
  m.volume = 50;
  m.track = "song.mp3";
  m.playing = true;
  std::string s = FwIdleSummary(m);
  TEST_ASSERT_EQUAL_STRING("MP3 | volume 50 | song.mp3", s.c_str());
}

void test_idle_summary_mp3_no_track() {
  MediaSnapshot m;
  m.mode = MediaMode::kMp3;
  m.volume = 30;
  m.track = "";
  m.playing = false;
  std::string s = FwIdleSummary(m);
  TEST_ASSERT_EQUAL_STRING("MP3 | volume 30 | pause", s.c_str());
}

// ---------------------------------------------------------------------------
// ShouldPublishPlaybackStarted
// ---------------------------------------------------------------------------

void test_publish_started_not_playing() {
  MediaSnapshot before, after;
  before.playing = false;
  after.playing = false;
  VoiceIntent intent;
  intent.type = "play";
  TEST_ASSERT_FALSE(FwShouldPublishPlaybackStarted(before, after, intent));
}

void test_publish_started_wrong_intent() {
  MediaSnapshot before, after;
  after.playing = true;
  VoiceIntent intent;
  intent.type = "volume_up";
  TEST_ASSERT_FALSE(FwShouldPublishPlaybackStarted(before, after, intent));
}

void test_publish_started_new_station() {
  MediaSnapshot before, after;
  before.playing = true;
  before.station = "FIP";
  before.mode = MediaMode::kRadio;
  after.playing = true;
  after.station = "Nova";
  after.mode = MediaMode::kRadio;
  VoiceIntent intent;
  intent.type = "select_station";
  TEST_ASSERT_TRUE(FwShouldPublishPlaybackStarted(before, after, intent));
}

void test_publish_started_same_station_playing() {
  MediaSnapshot before, after;
  before.playing = true;
  before.station = "FIP";
  before.mode = MediaMode::kRadio;
  after.playing = true;
  after.station = "FIP";
  after.mode = MediaMode::kRadio;
  VoiceIntent intent;
  intent.type = "select_station";
  // Same station, same mode, was already playing -> no event
  TEST_ASSERT_FALSE(FwShouldPublishPlaybackStarted(before, after, intent));
}

void test_publish_started_play_from_idle() {
  MediaSnapshot before, after;
  before.playing = false;
  after.playing = true;
  after.station = "FIP";
  after.mode = MediaMode::kRadio;
  VoiceIntent intent;
  intent.type = "play";
  TEST_ASSERT_TRUE(FwShouldPublishPlaybackStarted(before, after, intent));
}

void test_publish_started_mode_switch() {
  MediaSnapshot before, after;
  before.playing = true;
  before.mode = MediaMode::kMp3;
  after.playing = true;
  after.mode = MediaMode::kRadio;
  VoiceIntent intent;
  intent.type = "switch_mode";
  TEST_ASSERT_TRUE(FwShouldPublishPlaybackStarted(before, after, intent));
}

// ---------------------------------------------------------------------------
// Version comparison
// ---------------------------------------------------------------------------

void test_versions_equal() {
  TEST_ASSERT_EQUAL_INT(0, FwCompareVersions("1.0.0", "1.0.0"));
  TEST_ASSERT_EQUAL_INT(0, FwCompareVersions("2.3.4", "2.3.4"));
}

void test_version_major_greater() {
  TEST_ASSERT_EQUAL_INT(1, FwCompareVersions("2.0.0", "1.9.9"));
}

void test_version_major_lesser() {
  TEST_ASSERT_EQUAL_INT(-1, FwCompareVersions("1.0.0", "2.0.0"));
}

void test_version_minor_bump() {
  TEST_ASSERT_EQUAL_INT(-1, FwCompareVersions("1.0.0", "1.1.0"));
}

void test_version_patch_bump() {
  TEST_ASSERT_EQUAL_INT(-1, FwCompareVersions("1.0.0", "1.0.1"));
}

void test_version_patch_downgrade() {
  TEST_ASSERT_EQUAL_INT(1, FwCompareVersions("1.0.2", "1.0.1"));
}

// ---------------------------------------------------------------------------
// WAV header validation
// ---------------------------------------------------------------------------

void test_wav_valid_header() {
  // Minimal 12-byte RIFF/WAVE header
  const uint8_t data[] = {
    'R', 'I', 'F', 'F',  // chunk id
    0x24, 0x00, 0x00, 0x00,  // chunk size (36 bytes data)
    'W', 'A', 'V', 'E',  // format
  };
  TEST_ASSERT_TRUE(FwIsValidWavHeader(data, sizeof(data)));
}

void test_wav_too_short() {
  const uint8_t data[] = { 'R', 'I', 'F', 'F', 0x00 };
  TEST_ASSERT_FALSE(FwIsValidWavHeader(data, sizeof(data)));
}

void test_wav_wrong_magic() {
  const uint8_t data[] = {
    0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,
  };
  TEST_ASSERT_FALSE(FwIsValidWavHeader(data, sizeof(data)));
}

void test_wav_empty_buffer() {
  TEST_ASSERT_FALSE(FwIsValidWavHeader(nullptr, 0));
}

// ---------------------------------------------------------------------------
// Backend URL validation
// ---------------------------------------------------------------------------

void test_url_http_valid() {
  TEST_ASSERT_TRUE(FwIsValidBackendUrl("http://192.168.1.42:8000"));
}

void test_url_https_valid() {
  TEST_ASSERT_TRUE(FwIsValidBackendUrl("https://mascarade.example.com"));
}

void test_url_empty_invalid() {
  TEST_ASSERT_FALSE(FwIsValidBackendUrl(""));
}

void test_url_no_scheme_invalid() {
  TEST_ASSERT_FALSE(FwIsValidBackendUrl("192.168.1.42:8000"));
}

void test_url_ftp_invalid() {
  TEST_ASSERT_FALSE(FwIsValidBackendUrl("ftp://192.168.1.42/firmware.bin"));
}

// ---------------------------------------------------------------------------
// WiFi Scanner -- pure C++ utilities
// ---------------------------------------------------------------------------

void test_rssi_quality_best() {
  TEST_ASSERT_EQUAL_INT(100, FwRssiQuality(-50));
}

void test_rssi_quality_worst() {
  TEST_ASSERT_EQUAL_INT(0, FwRssiQuality(-100));
}

void test_rssi_quality_midpoint() {
  TEST_ASSERT_EQUAL_INT(50, FwRssiQuality(-75));
}

void test_rssi_quality_clamped_above() {
  TEST_ASSERT_EQUAL_INT(100, FwRssiQuality(-30));
}

void test_rssi_quality_clamped_below() {
  TEST_ASSERT_EQUAL_INT(0, FwRssiQuality(-110));
}

void test_rssi_quality_near_threshold() {
  TEST_ASSERT_EQUAL_INT(2, FwRssiQuality(-99));
  TEST_ASSERT_EQUAL_INT(98, FwRssiQuality(-51));
}

void test_wifi_json_empty() {
  std::vector<WifiNetwork> nets;
  std::string j = FwWifiToJson(nets, 123);
  TEST_ASSERT_NOT_NULL(strstr(j.c_str(), "\"networks\":[]"));
  TEST_ASSERT_NOT_NULL(strstr(j.c_str(), "\"count\":0"));
  TEST_ASSERT_NOT_NULL(strstr(j.c_str(), "\"duration_ms\":123"));
}

void test_wifi_json_single_network() {
  WifiNetwork n;
  n.ssid = "TestNet";
  n.rssi = -62;
  n.open = false;
  n.channel = 6;
  std::vector<WifiNetwork> nets = {n};
  std::string j = FwWifiToJson(nets, 2000);
  TEST_ASSERT_NOT_NULL(strstr(j.c_str(), "\"ssid\":\"TestNet\""));
  TEST_ASSERT_NOT_NULL(strstr(j.c_str(), "\"rssi\":-62"));
  TEST_ASSERT_NOT_NULL(strstr(j.c_str(), "\"open\":false"));
  TEST_ASSERT_NOT_NULL(strstr(j.c_str(), "\"channel\":6"));
  TEST_ASSERT_NOT_NULL(strstr(j.c_str(), "\"quality\":76"));
  TEST_ASSERT_NOT_NULL(strstr(j.c_str(), "\"count\":1"));
}

void test_wifi_json_escapes_quotes() {
  WifiNetwork n;
  n.ssid = "Net\"Work";
  n.rssi = -70;
  std::vector<WifiNetwork> nets = {n};
  std::string j = FwWifiToJson(nets, 0);
  TEST_ASSERT_NOT_NULL(strstr(j.c_str(), "Net\\\"Work"));
}

void test_wifi_sort_by_rssi() {
  WifiNetwork a; a.ssid = "weak";  a.rssi = -80;
  WifiNetwork b; b.ssid = "good";  b.rssi = -55;
  WifiNetwork c; c.ssid = "ok";    c.rssi = -70;
  std::vector<WifiNetwork> nets = {a, b, c};
  std::sort(nets.begin(), nets.end(), FwNetworkBetterSignal);
  TEST_ASSERT_EQUAL_STRING("good", nets[0].ssid.c_str());
  TEST_ASSERT_EQUAL_STRING("ok",   nets[1].ssid.c_str());
  TEST_ASSERT_EQUAL_STRING("weak", nets[2].ssid.c_str());
}

void test_wifi_json_open_network() {
  WifiNetwork n;
  n.ssid = "Open";
  n.rssi = -50;
  n.open = true;
  n.channel = 1;
  std::vector<WifiNetwork> nets = {n};
  std::string j = FwWifiToJson(nets, 1500);
  TEST_ASSERT_NOT_NULL(strstr(j.c_str(), "\"open\":true"));
}

// ---------------------------------------------------------------------------
// MediaSnapshot defaults
// ---------------------------------------------------------------------------

void test_media_snapshot_defaults() {
  MediaSnapshot m;
  TEST_ASSERT_EQUAL(static_cast<int>(MediaMode::kIdle),
                    static_cast<int>(m.mode));
  TEST_ASSERT_FALSE(m.playing);
  TEST_ASSERT_EQUAL_INT(40, m.volume);
  TEST_ASSERT_EQUAL_INT(-1, m.battery_pct);
}

void test_voice_intent_defaults() {
  VoiceIntent v;
  TEST_ASSERT_EQUAL_STRING("none", v.type.c_str());
  TEST_ASSERT_FALSE(v.resume_media_after_tts);
}

// ---------------------------------------------------------------------------

int main(int, char**) {
  UNITY_BEGIN();

  // IdleSummary
  RUN_TEST(test_idle_summary_idle_mode);
  RUN_TEST(test_idle_summary_idle_paused);
  RUN_TEST(test_idle_summary_radio_with_station);
  RUN_TEST(test_idle_summary_mp3_with_track);
  RUN_TEST(test_idle_summary_mp3_no_track);

  // ShouldPublishPlaybackStarted
  RUN_TEST(test_publish_started_not_playing);
  RUN_TEST(test_publish_started_wrong_intent);
  RUN_TEST(test_publish_started_new_station);
  RUN_TEST(test_publish_started_same_station_playing);
  RUN_TEST(test_publish_started_play_from_idle);
  RUN_TEST(test_publish_started_mode_switch);

  // Version comparison
  RUN_TEST(test_versions_equal);
  RUN_TEST(test_version_major_greater);
  RUN_TEST(test_version_major_lesser);
  RUN_TEST(test_version_minor_bump);
  RUN_TEST(test_version_patch_bump);
  RUN_TEST(test_version_patch_downgrade);

  // WAV header validation
  RUN_TEST(test_wav_valid_header);
  RUN_TEST(test_wav_too_short);
  RUN_TEST(test_wav_wrong_magic);
  RUN_TEST(test_wav_empty_buffer);

  // Backend URL validation
  RUN_TEST(test_url_http_valid);
  RUN_TEST(test_url_https_valid);
  RUN_TEST(test_url_empty_invalid);
  RUN_TEST(test_url_no_scheme_invalid);
  RUN_TEST(test_url_ftp_invalid);

  // WiFi Scanner
  RUN_TEST(test_rssi_quality_best);
  RUN_TEST(test_rssi_quality_worst);
  RUN_TEST(test_rssi_quality_midpoint);
  RUN_TEST(test_rssi_quality_clamped_above);
  RUN_TEST(test_rssi_quality_clamped_below);
  RUN_TEST(test_rssi_quality_near_threshold);
  RUN_TEST(test_wifi_json_empty);
  RUN_TEST(test_wifi_json_single_network);
  RUN_TEST(test_wifi_json_escapes_quotes);
  RUN_TEST(test_wifi_sort_by_rssi);
  RUN_TEST(test_wifi_json_open_network);

  // Struct defaults
  RUN_TEST(test_media_snapshot_defaults);
  RUN_TEST(test_voice_intent_defaults);

  return UNITY_END();
}
