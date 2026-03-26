#include "radio_player.h"

#include <Arduino.h>
#include <Audio.h>   // ESP32-audioI2S
#include <LittleFS.h>

// ---------------------------------------------------------------------------
RadioPlayer::RadioPlayer() {}
RadioPlayer::~RadioPlayer() { delete audio_; }

// ---------------------------------------------------------------------------
bool RadioPlayer::Begin(int bck, int ws, int dout) {
  audio_ = new Audio();
  audio_->setPinout(bck, ws, dout);
  audio_->setVolume(volume_ * 21 / 100);  // Library uses 0–21 scale.
  initialized_ = true;
  Serial.printf("[radio] ready — BCK=%d WS=%d DOUT=%d\n", bck, ws, dout);
  return true;
}

// ---------------------------------------------------------------------------
void RadioPlayer::Loop() {
  if (initialized_ && audio_) {
    audio_->loop();
  }
}

// ---------------------------------------------------------------------------
MediaSnapshot RadioPlayer::Snapshot() const {
  MediaSnapshot snap;
  snap.mode = mode_;
  snap.playing = playing_;
  snap.volume = volume_;
  snap.wifi_ssid = wifi_ssid_;
  snap.wifi_rssi = wifi_rssi_;
  snap.battery_pct = battery_pct_;

  if (!stations_.empty() && current_station_ >= 0 &&
      current_station_ < (int)stations_.size()) {
    snap.station = stations_[current_station_].first;
  }
  snap.track = current_title_;

  for (const auto& s : stations_) {
    snap.available_stations.push_back(s.first);
  }
  return snap;
}

// ---------------------------------------------------------------------------
void RadioPlayer::ApplyIntent(const VoiceIntent& intent) {
  if (intent.type == "set_volume") {
    int v = atoi(intent.value.c_str());
    SetVolume(v);
  } else if (intent.type == "play") {
    if (!playing_) StartCurrentStation();
  } else if (intent.type == "pause") {
    Stop();
  } else if (intent.type == "next") {
    Next();
  } else if (intent.type == "previous") {
    Previous();
  } else if (intent.type == "select_station") {
    PlayStation(intent.value);
  } else if (intent.type == "switch_mode") {
    if (intent.value == "radio") {
      mode_ = MediaMode::kRadio;
      StartCurrentStation();
    } else if (intent.value == "mp3") {
      mode_ = MediaMode::kMp3;
      Stop();
      // TODO: SD card MP3 playback
    }
  }
}

// ---------------------------------------------------------------------------
void RadioPlayer::PrepareForReply(PlayerAction action) {
  was_playing_ = playing_;
  saved_volume_ = volume_;

  if (action == PlayerAction::kDuck) {
    // Lower volume by half during TTS.
    if (audio_) audio_->setVolume((volume_ / 2) * 21 / 100);
  } else if (action == PlayerAction::kStopResume) {
    if (playing_ && audio_) {
      audio_->stopSong();
      playing_ = false;
    }
  }
}

// ---------------------------------------------------------------------------
void RadioPlayer::RestoreAfterReply(bool resume) {
  // Restore volume.
  if (saved_volume_ >= 0) {
    if (audio_) audio_->setVolume(saved_volume_ * 21 / 100);
    saved_volume_ = -1;
  }
  // Resume playback if needed.
  if (resume && was_playing_ && !playing_) {
    StartCurrentStation();
  }
  was_playing_ = false;
}

// ---------------------------------------------------------------------------
bool RadioPlayer::PlayReplyAudio(const std::vector<uint8_t>& wav) {
  if (!initialized_ || !audio_) return false;

  // Stop current stream.
  bool was = playing_;
  if (playing_) {
    audio_->stopSong();
    playing_ = false;
  }

  Serial.printf("[radio] playing TTS WAV (%u bytes)\n", (unsigned)wav.size());

  // ESP32-audioI2S doesn't have a direct "play from buffer" for WAV.
  // Write to SPIFFS temp file, then play it.
  // Alternative: use our raw I2S driver for TTS. For now, write to /tmp.
  //
  // Simpler approach: use PROGMEM-style buffer playback if available,
  // or fall back to the I2S driver directly.
  //
  // The Audio library doesn't support buffer playback natively,
  // so we write a temp file to SPIFFS/LittleFS.

  // Use LittleFS for temp file.
  static bool fs_init = false;
  if (!fs_init) {
    if (!LittleFS.begin(true)) {
      Serial.println("[radio] LittleFS mount failed");
      return false;
    }
    fs_init = true;
  }

  {
    File f = LittleFS.open("/tts_reply.wav", "w");
    if (!f) {
      Serial.println("[radio] cannot write temp WAV");
      return false;
    }
    f.write(wav.data(), wav.size());
    f.close();
  }

  audio_->setVolume(volume_ * 21 / 100);
  bool ok = audio_->connecttoFS(LittleFS, "/tts_reply.wav");
  if (!ok) {
    Serial.println("[radio] failed to play TTS WAV");
    return false;
  }

  // Block until TTS playback finishes.
  while (audio_->isRunning()) {
    audio_->loop();
    delay(1);
  }

  return true;
}

// ---------------------------------------------------------------------------
void RadioPlayer::SetStations(
    const std::vector<std::pair<std::string, std::string>>& list) {
  stations_ = list;
  if (current_station_ >= (int)stations_.size()) current_station_ = 0;
  Serial.printf("[radio] %d stations loaded\n", (int)stations_.size());
}

void RadioPlayer::PlayStation(int index) {
  if (stations_.empty()) return;
  current_station_ = index % (int)stations_.size();
  StartCurrentStation();
}

void RadioPlayer::PlayStation(const std::string& name) {
  for (int i = 0; i < (int)stations_.size(); i++) {
    if (stations_[i].first == name) {
      PlayStation(i);
      return;
    }
  }
  Serial.printf("[radio] station not found: %s\n", name.c_str());
}

void RadioPlayer::Next() {
  if (stations_.empty()) return;
  current_station_ = (current_station_ + 1) % (int)stations_.size();
  StartCurrentStation();
}

void RadioPlayer::Previous() {
  if (stations_.empty()) return;
  current_station_ = (current_station_ - 1 + (int)stations_.size()) %
                     (int)stations_.size();
  StartCurrentStation();
}

void RadioPlayer::Stop() {
  if (audio_) audio_->stopSong();
  playing_ = false;
}

void RadioPlayer::SetVolume(int vol) {
  volume_ = constrain(vol, 0, 100);
  if (audio_) audio_->setVolume(volume_ * 21 / 100);
  Serial.printf("[radio] volume → %d\n", volume_);
}

bool RadioPlayer::IsPlaying() const { return playing_; }

// ---------------------------------------------------------------------------
void RadioPlayer::StartCurrentStation() {
  if (!initialized_ || !audio_ || stations_.empty()) return;

  const auto& [name, url] = stations_[current_station_];
  Serial.printf("[radio] → %s (%s)\n", name.c_str(), url.c_str());

  audio_->stopSong();
  bool ok = audio_->connecttohost(url.c_str());
  playing_ = ok;
  if (!ok) {
    Serial.printf("[radio] connect failed: %s\n", url.c_str());
  }
}

// ---------------------------------------------------------------------------
void RadioPlayer::OnInfo(const char* info) {
  Serial.printf("[radio] info: %s\n", info);
}

void RadioPlayer::OnTitle(const char* title) {
  current_title_ = title ? title : "";
  Serial.printf("[radio] title: %s\n", current_title_.c_str());
}

// ---------------------------------------------------------------------------
void updatePlayerWifi(RadioPlayer& p, const std::string& ssid, int rssi) {
  p.wifi_ssid_ = ssid;
  p.wifi_rssi_ = rssi;
}
