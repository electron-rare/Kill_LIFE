/// @file test_radio_state.cpp
/// Unity tests for RadioPlayer state-machine logic (station navigation,
/// volume, snapshot, intent handling, prepare/restore cycle).
/// Compiles on the native (Linux x86_64) target with -D UNIT_TEST=1.
/// No real Audio/I2S/LittleFS hardware used — audio_ pointer stays null;
/// every method that calls audio_ is already guarded by null / initialized_ checks.

#include <algorithm>
#include <cstdarg>
#include <cstdio>
#include <string>
#include <unity.h>
#include <utility>
#include <vector>

// ---------------------------------------------------------------------------
// Minimal Arduino stubs
// ---------------------------------------------------------------------------
inline void yield() {}
inline void delay(unsigned long) {}
inline unsigned long millis() {
  return 0;
}
template <typename T> inline T constrain(T v, T lo, T hi) {
  return v < lo ? lo : (v > hi ? hi : v);
}

struct _SerialStub {
  void printf(const char *, ...) {}
  void println(const char *) {}
  void print(const char *) {}
} Serial;

// ---------------------------------------------------------------------------
// Audio stub — forward-declared in radio_player.h; provide a no-op body.
// ---------------------------------------------------------------------------
class Audio {
public:
  int last_volume = 0;
  const char *last_fs_path = nullptr;
  void setPinout(int, int, int) {}
  void setVolume(int v) { last_volume = v; }
  bool connecttohost(const char *) { return true; }
  // connecttoFS used for both SD MP3 and LittleFS TTS
  template <typename FS> bool connecttoFS(FS &, const char *path) {
    last_fs_path = path;
    return true;
  }
  void stopSong() {}
  bool isRunning() { return false; }
  void loop() {}
};

// Minimal SD stub so radio_player.h compiles (SD not used in native tests).
struct _SDStub {
} SD;

// ---------------------------------------------------------------------------
// Pure-C++ headers (no Arduino deps)
// Open private members for white-box state testing.
// ---------------------------------------------------------------------------
#define private public
#include "../../include/radio_player.h"
#include "../../include/voice_controller.h"
#undef private

// ---------------------------------------------------------------------------
// RadioPlayer implementation — inlined here to avoid including radio_player.cpp
// which pulls in Arduino.h / Audio.h / LittleFS.h.
// Only the state-machine methods that are safe with audio_=nullptr.
// ---------------------------------------------------------------------------

RadioPlayer::RadioPlayer() {}
RadioPlayer::~RadioPlayer() {
  delete audio_;
}

bool RadioPlayer::Begin(int bck, int ws, int dout) {
  audio_ = new Audio();
  audio_->setPinout(bck, ws, dout);
  audio_->setVolume(volume_ * 21 / 100);
  initialized_ = true;
  return true;
}

void RadioPlayer::Loop() {
  if (initialized_ && audio_)
    audio_->loop();
}

MediaSnapshot RadioPlayer::Snapshot() const {
  MediaSnapshot snap;
  snap.mode = mode_;
  snap.playing = playing_;
  snap.volume = volume_;
  snap.wifi_ssid = wifi_ssid_;
  snap.wifi_rssi = wifi_rssi_;
  snap.battery_pct = battery_pct_;
  if (!stations_.empty() && current_station_ >= 0 && current_station_ < (int)stations_.size()) {
    snap.station = stations_[current_station_].first;
  }
  snap.track = current_title_;
  for (const auto &s : stations_)
    snap.available_stations.push_back(s.first);
  return snap;
}

void RadioPlayer::ApplyIntent(const VoiceIntent &intent) {
  if (intent.type == "set_volume") {
    SetVolume(atoi(intent.value.c_str()));
  } else if (intent.type == "play") {
    if (!playing_) {
      if (mode_ == MediaMode::kMp3)
        StartCurrentMp3();
      else
        StartCurrentStation();
    }
  } else if (intent.type == "pause") {
    Stop();
  } else if (intent.type == "next") {
    if (mode_ == MediaMode::kMp3)
      NextMp3();
    else
      Next();
  } else if (intent.type == "previous") {
    if (mode_ == MediaMode::kMp3)
      PreviousMp3();
    else
      Previous();
  } else if (intent.type == "next_mp3") {
    NextMp3();
  } else if (intent.type == "previous_mp3") {
    PreviousMp3();
  } else if (intent.type == "select_station") {
    PlayStation(intent.value);
  } else if (intent.type == "switch_mode") {
    if (intent.value == "radio") {
      mode_ = MediaMode::kRadio;
      StartCurrentStation();
    } else if (intent.value == "mp3") {
      mode_ = MediaMode::kMp3;
      Stop();
      StartCurrentMp3();
    }
  }
}

void RadioPlayer::PrepareForReply(PlayerAction action) {
  was_playing_ = playing_;
  saved_volume_ = volume_;
  if (action == PlayerAction::kDuck) {
    if (audio_)
      audio_->setVolume((volume_ / 2) * 21 / 100);
  } else if (action == PlayerAction::kStopResume) {
    if (playing_ && audio_) {
      audio_->stopSong();
      playing_ = false;
    }
  }
}

void RadioPlayer::RestoreAfterReply(bool resume) {
  if (saved_volume_ >= 0) {
    if (audio_)
      audio_->setVolume(saved_volume_ * 21 / 100);
    saved_volume_ = -1;
  }
  if (resume && was_playing_ && !playing_)
    StartCurrentStation();
  was_playing_ = false;
}

bool RadioPlayer::PlayReplyAudio(const std::vector<uint8_t> &) {
  return false; // stub — not tested
}

void RadioPlayer::SetStations(const std::vector<std::pair<std::string, std::string>> &list) {
  stations_ = list;
  if (current_station_ >= (int)stations_.size())
    current_station_ = 0;
}

void RadioPlayer::PlayStation(int index) {
  if (stations_.empty())
    return;
  current_station_ = index % (int)stations_.size();
  StartCurrentStation();
}

void RadioPlayer::PlayStation(const std::string &name) {
  for (int i = 0; i < (int)stations_.size(); i++) {
    if (stations_[i].first == name) {
      PlayStation(i);
      return;
    }
  }
}

void RadioPlayer::Next() {
  if (stations_.empty())
    return;
  current_station_ = (current_station_ + 1) % (int)stations_.size();
  StartCurrentStation();
}

void RadioPlayer::Previous() {
  if (stations_.empty())
    return;
  current_station_ = (current_station_ - 1 + (int)stations_.size()) % (int)stations_.size();
  StartCurrentStation();
}

void RadioPlayer::Stop() {
  if (audio_)
    audio_->stopSong();
  playing_ = false;
}

void RadioPlayer::SetVolume(int vol) {
  volume_ = constrain(vol, 0, 100);
  if (audio_)
    audio_->setVolume(volume_ * 21 / 100);
}

bool RadioPlayer::IsPlaying() const {
  return playing_;
}

void RadioPlayer::SetMp3Files(const std::vector<std::string> &files) {
  mp3_files_ = files;
  if (current_mp3_ >= (int)mp3_files_.size())
    current_mp3_ = 0;
}

void RadioPlayer::NextMp3() {
  if (mp3_files_.empty())
    return;
  current_mp3_ = (current_mp3_ + 1) % (int)mp3_files_.size();
  StartCurrentMp3();
}

void RadioPlayer::PreviousMp3() {
  if (mp3_files_.empty())
    return;
  current_mp3_ = (current_mp3_ - 1 + (int)mp3_files_.size()) % (int)mp3_files_.size();
  StartCurrentMp3();
}

void RadioPlayer::StartCurrentMp3() {
  if (!initialized_ || !audio_ || mp3_files_.empty())
    return;
  const std::string &path = mp3_files_[current_mp3_];
  audio_->stopSong();
  playing_ = audio_->connecttoFS(SD, path.c_str());
}

void RadioPlayer::StartCurrentStation() {
  if (!initialized_ || !audio_ || stations_.empty())
    return;
  const auto &[name, url] = stations_[current_station_];
  audio_->stopSong();
  playing_ = audio_->connecttohost(url.c_str());
}

void RadioPlayer::OnInfo(const char *) {}
void RadioPlayer::OnTitle(const char *title) {
  current_title_ = title ? title : "";
}

void updatePlayerWifi(RadioPlayer &p, const std::string &ssid, int rssi) {
  p.wifi_ssid_ = ssid;
  p.wifi_rssi_ = rssi;
}

// ===========================================================================
// Helpers
// ===========================================================================

static std::vector<std::pair<std::string, std::string>> three_stations() {
  return {{"FIP", "http://fip.fr/stream"},
          {"NovaPlanet", "http://nova.fr/stream"},
          {"France Inter", "http://inter.fr/stream"}};
}

// ===========================================================================
// Tests
// ===========================================================================

void setUp() {}
void tearDown() {}

// --- Snapshot defaults -------------------------------------------------------

void test_snapshot_defaults() {
  RadioPlayer p;
  auto s = p.Snapshot();
  TEST_ASSERT_EQUAL(MediaMode::kRadio, s.mode);
  TEST_ASSERT_FALSE(s.playing);
  TEST_ASSERT_EQUAL_INT(40, s.volume); // default volume
  TEST_ASSERT_TRUE(s.station.empty());
  TEST_ASSERT_EQUAL_INT(-1, s.battery_pct);
}

void test_snapshot_no_stations() {
  RadioPlayer p;
  auto s = p.Snapshot();
  TEST_ASSERT_TRUE(s.available_stations.empty());
}

// --- SetStations / Snapshot station list ------------------------------------

void test_setstations_populates_available() {
  RadioPlayer p;
  p.SetStations(three_stations());
  auto s = p.Snapshot();
  TEST_ASSERT_EQUAL_INT(3, (int)s.available_stations.size());
  TEST_ASSERT_EQUAL_STRING("FIP", s.available_stations[0].c_str());
  TEST_ASSERT_EQUAL_STRING("NovaPlanet", s.available_stations[1].c_str());
}

void test_snapshot_current_station_name() {
  RadioPlayer p;
  p.SetStations(three_stations());
  // current_station_ starts at 0 → "FIP"
  TEST_ASSERT_EQUAL_STRING("FIP", p.Snapshot().station.c_str());
}

// --- Station navigation ------------------------------------------------------

void test_playstation_int_sets_index() {
  RadioPlayer p;
  p.SetStations(three_stations());
  p.PlayStation(1);
  TEST_ASSERT_EQUAL_STRING("NovaPlanet", p.Snapshot().station.c_str());
}

void test_playstation_int_wraps() {
  RadioPlayer p;
  p.SetStations(three_stations());
  p.PlayStation(5); // 5 % 3 == 2
  TEST_ASSERT_EQUAL_STRING("France Inter", p.Snapshot().station.c_str());
}

void test_playstation_by_name() {
  RadioPlayer p;
  p.SetStations(three_stations());
  p.PlayStation(std::string("France Inter"));
  TEST_ASSERT_EQUAL_STRING("France Inter", p.Snapshot().station.c_str());
}

void test_playstation_unknown_name_no_change() {
  RadioPlayer p;
  p.SetStations(three_stations());
  p.PlayStation(std::string("Unknown"));
  TEST_ASSERT_EQUAL_STRING("FIP", p.Snapshot().station.c_str());
}

void test_next_advances() {
  RadioPlayer p;
  p.SetStations(three_stations());
  p.Next(); // 0 → 1
  TEST_ASSERT_EQUAL_STRING("NovaPlanet", p.Snapshot().station.c_str());
}

void test_next_wraps_at_end() {
  RadioPlayer p;
  p.SetStations(three_stations());
  p.PlayStation(2); // France Inter (last)
  p.Next();         // wraps → 0 (FIP)
  TEST_ASSERT_EQUAL_STRING("FIP", p.Snapshot().station.c_str());
}

void test_previous_wraps_at_start() {
  RadioPlayer p;
  p.SetStations(three_stations());
  // current_station_=0, Previous → (0-1+3)%3 == 2
  p.Previous();
  TEST_ASSERT_EQUAL_STRING("France Inter", p.Snapshot().station.c_str());
}

// --- Volume ------------------------------------------------------------------

void test_setvolume_normal() {
  RadioPlayer p;
  p.SetVolume(60);
  TEST_ASSERT_EQUAL_INT(60, p.Snapshot().volume);
}

void test_setvolume_clamps_high() {
  RadioPlayer p;
  p.SetVolume(200);
  TEST_ASSERT_EQUAL_INT(100, p.Snapshot().volume);
}

void test_setvolume_clamps_low() {
  RadioPlayer p;
  p.SetVolume(-10);
  TEST_ASSERT_EQUAL_INT(0, p.Snapshot().volume);
}

// --- ApplyIntent -------------------------------------------------------------

void test_intent_set_volume() {
  RadioPlayer p;
  VoiceIntent intent;
  intent.type = "set_volume";
  intent.value = "75";
  p.ApplyIntent(intent);
  TEST_ASSERT_EQUAL_INT(75, p.Snapshot().volume);
}

void test_intent_pause_clears_playing() {
  RadioPlayer p;
  p.playing_ = true; // simulate playing state
  VoiceIntent intent;
  intent.type = "pause";
  p.ApplyIntent(intent);
  TEST_ASSERT_FALSE(p.IsPlaying());
}

void test_intent_next_advances_station() {
  RadioPlayer p;
  p.SetStations(three_stations());
  VoiceIntent intent;
  intent.type = "next";
  p.ApplyIntent(intent);
  TEST_ASSERT_EQUAL_STRING("NovaPlanet", p.Snapshot().station.c_str());
}

void test_intent_select_station() {
  RadioPlayer p;
  p.SetStations(three_stations());
  VoiceIntent intent;
  intent.type = "select_station";
  intent.value = "France Inter";
  p.ApplyIntent(intent);
  TEST_ASSERT_EQUAL_STRING("France Inter", p.Snapshot().station.c_str());
}

void test_intent_switch_mode_mp3() {
  RadioPlayer p;
  VoiceIntent intent;
  intent.type = "switch_mode";
  intent.value = "mp3";
  p.ApplyIntent(intent);
  TEST_ASSERT_EQUAL(MediaMode::kMp3, p.Snapshot().mode);
}

void test_intent_switch_mode_radio() {
  RadioPlayer p;
  // Start in mp3, switch back to radio
  p.mode_ = MediaMode::kMp3;
  VoiceIntent intent;
  intent.type = "switch_mode";
  intent.value = "radio";
  p.ApplyIntent(intent);
  TEST_ASSERT_EQUAL(MediaMode::kRadio, p.Snapshot().mode);
}

// --- PrepareForReply / RestoreAfterReply -------------------------------------

void test_prepare_saves_state() {
  RadioPlayer p;
  p.SetVolume(80);
  p.playing_ = true;
  p.PrepareForReply(PlayerAction::kDuck);
  // saved_volume_ = 80, was_playing_ = true
  // After restore with resume=false, saved_volume_ reset
  p.RestoreAfterReply(false);
  TEST_ASSERT_EQUAL_INT(80, p.Snapshot().volume); // volume restored
  TEST_ASSERT_TRUE(p.IsPlaying());                // kDuck never stops playback
}

void test_prepare_stop_resume_action() {
  RadioPlayer p;
  // audio_=nullptr → kStopResume path skips audio->stopSong but playing_ stays set
  // (guard: if (playing_ && audio_) — audio is null, so no-op)
  p.playing_ = true;
  p.PrepareForReply(PlayerAction::kStopResume);
  TEST_ASSERT_TRUE(p.IsPlaying()); // audio_ is null → no change
  // resume=true, was_playing_=true, but !playing_=false → StartCurrentStation not called.
  // playing_ never stopped (no audio_) → remains true.
  p.RestoreAfterReply(true);
  TEST_ASSERT_TRUE(p.IsPlaying()); // never stopped; was_playing_ reset internally
}

void test_restore_resets_saved_volume() {
  RadioPlayer p;
  p.SetVolume(50);
  p.PrepareForReply(PlayerAction::kNone);
  p.RestoreAfterReply(false);
  // saved_volume_ reset to -1 internally; volume stays 50
  TEST_ASSERT_EQUAL_INT(50, p.Snapshot().volume);
}

// --- WiFi info in Snapshot ---------------------------------------------------

void test_update_wifi_reflected_in_snapshot() {
  RadioPlayer p;
  updatePlayerWifi(p, "HomeNetwork", -65);
  auto s = p.Snapshot();
  TEST_ASSERT_EQUAL_STRING("HomeNetwork", s.wifi_ssid.c_str());
  TEST_ASSERT_EQUAL_INT(-65, s.wifi_rssi);
}

// --- OnTitle -----------------------------------------------------------------

void test_ontitle_updates_track() {
  RadioPlayer p;
  p.OnTitle("Daft Punk - Robot Rock");
  TEST_ASSERT_EQUAL_STRING("Daft Punk - Robot Rock", p.Snapshot().track.c_str());
}

void test_ontitle_null_clears() {
  RadioPlayer p;
  p.OnTitle("something");
  p.OnTitle(nullptr);
  TEST_ASSERT_TRUE(p.Snapshot().track.empty());
}

// ===========================================================================
// SD MP3 tests
// ===========================================================================

static std::vector<std::string> three_mp3s() {
  return {"/music/track1.mp3", "/music/track2.mp3", "/music/track3.mp3"};
}

void test_setmp3files_count() {
  RadioPlayer p;
  p.SetMp3Files(three_mp3s());
  TEST_ASSERT_EQUAL_INT(3, p.Mp3Count());
}

void test_mp3_initial_index_zero() {
  RadioPlayer p;
  p.SetMp3Files(three_mp3s());
  TEST_ASSERT_EQUAL_INT(0, p.CurrentMp3Index());
}

void test_nextmp3_advances() {
  RadioPlayer p;
  p.SetMp3Files(three_mp3s());
  p.NextMp3();
  TEST_ASSERT_EQUAL_INT(1, p.CurrentMp3Index());
}

void test_nextmp3_wraps() {
  RadioPlayer p;
  p.SetMp3Files(three_mp3s());
  p.NextMp3();
  p.NextMp3();
  p.NextMp3(); // 0→1→2→0
  TEST_ASSERT_EQUAL_INT(0, p.CurrentMp3Index());
}

void test_previousmp3_wraps_at_start() {
  RadioPlayer p;
  p.SetMp3Files(three_mp3s());
  p.PreviousMp3(); // (0-1+3)%3 == 2
  TEST_ASSERT_EQUAL_INT(2, p.CurrentMp3Index());
}

void test_switch_mode_mp3_sets_mode() {
  RadioPlayer p;
  VoiceIntent intent;
  intent.type = "switch_mode";
  intent.value = "mp3";
  p.ApplyIntent(intent);
  TEST_ASSERT_EQUAL(MediaMode::kMp3, p.Snapshot().mode);
}

void test_intent_next_in_mp3_mode_advances_mp3() {
  RadioPlayer p;
  p.SetMp3Files(three_mp3s());
  p.mode_ = MediaMode::kMp3;
  VoiceIntent intent;
  intent.type = "next";
  p.ApplyIntent(intent);
  TEST_ASSERT_EQUAL_INT(1, p.CurrentMp3Index());
}

void test_intent_previous_in_mp3_mode_wraps() {
  RadioPlayer p;
  p.SetMp3Files(three_mp3s());
  p.mode_ = MediaMode::kMp3;
  VoiceIntent intent;
  intent.type = "previous";
  p.ApplyIntent(intent);
  TEST_ASSERT_EQUAL_INT(2, p.CurrentMp3Index());
}

void test_intent_next_in_radio_mode_advances_station() {
  RadioPlayer p;
  p.SetStations(three_stations());
  p.mode_ = MediaMode::kRadio;
  VoiceIntent intent;
  intent.type = "next";
  p.ApplyIntent(intent);
  TEST_ASSERT_EQUAL_STRING("NovaPlanet", p.Snapshot().station.c_str());
}

void test_mp3_no_files_safe() {
  RadioPlayer p;
  p.NextMp3();     // must not crash
  p.PreviousMp3(); // must not crash
  TEST_ASSERT_EQUAL_INT(0, p.Mp3Count());
}

// ===========================================================================
// Main
// ===========================================================================

int main() {
  UNITY_BEGIN();

  RUN_TEST(test_snapshot_defaults);
  RUN_TEST(test_snapshot_no_stations);
  RUN_TEST(test_setstations_populates_available);
  RUN_TEST(test_snapshot_current_station_name);
  RUN_TEST(test_playstation_int_sets_index);
  RUN_TEST(test_playstation_int_wraps);
  RUN_TEST(test_playstation_by_name);
  RUN_TEST(test_playstation_unknown_name_no_change);
  RUN_TEST(test_next_advances);
  RUN_TEST(test_next_wraps_at_end);
  RUN_TEST(test_previous_wraps_at_start);
  RUN_TEST(test_setvolume_normal);
  RUN_TEST(test_setvolume_clamps_high);
  RUN_TEST(test_setvolume_clamps_low);
  RUN_TEST(test_intent_set_volume);
  RUN_TEST(test_intent_pause_clears_playing);
  RUN_TEST(test_intent_next_advances_station);
  RUN_TEST(test_intent_select_station);
  RUN_TEST(test_intent_switch_mode_mp3);
  RUN_TEST(test_intent_switch_mode_radio);
  RUN_TEST(test_prepare_saves_state);
  RUN_TEST(test_prepare_stop_resume_action);
  RUN_TEST(test_restore_resets_saved_volume);
  RUN_TEST(test_update_wifi_reflected_in_snapshot);
  RUN_TEST(test_ontitle_updates_track);
  RUN_TEST(test_ontitle_null_clears);
  // SD MP3 tests
  RUN_TEST(test_setmp3files_count);
  RUN_TEST(test_mp3_initial_index_zero);
  RUN_TEST(test_nextmp3_advances);
  RUN_TEST(test_nextmp3_wraps);
  RUN_TEST(test_previousmp3_wraps_at_start);
  RUN_TEST(test_switch_mode_mp3_sets_mode);
  RUN_TEST(test_intent_next_in_mp3_mode_advances_mp3);
  RUN_TEST(test_intent_previous_in_mp3_mode_wraps);
  RUN_TEST(test_intent_next_in_radio_mode_advances_station);
  RUN_TEST(test_mp3_no_files_safe);

  return UNITY_END();
}
