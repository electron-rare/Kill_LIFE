#pragma once

#include "voice_controller.h"

#include <string>
#include <vector>

class Audio;  // Forward-declare from ESP32-audioI2S

/// Web radio + TTS playback using ESP32-audioI2S library.
/// Manages the I2S output (PCM5101 DAC) for both radio streaming
/// and TTS reply audio.
class RadioPlayer : public MediaController {
 public:
  RadioPlayer();
  ~RadioPlayer();

  /// Initialise I2S output via the Audio library.
  bool Begin(int bck, int ws, int dout);

  /// Must be called from loop() to feed the audio decoder.
  void Loop();

  // -- MediaController interface --
  MediaSnapshot Snapshot() const override;
  void ApplyIntent(const VoiceIntent& intent) override;
  void PrepareForReply(PlayerAction action) override;
  void RestoreAfterReply(bool resume) override;
  bool PlayReplyAudio(const std::vector<uint8_t>& wav) override;

  // -- Station management --
  void SetStations(const std::vector<std::pair<std::string, std::string>>& list);
  void PlayStation(int index);
  void PlayStation(const std::string& name);
  void Next();
  void Previous();
  void Stop();
  void SetVolume(int vol);  // 0–100
  bool IsPlaying() const;

  // -- SD MP3 management --
  /// Load a list of MP3 file paths from the SD card (e.g. "/music/track1.mp3").
  void SetMp3Files(const std::vector<std::string>& files);
  /// Advance to next MP3 and play it.
  void NextMp3();
  /// Go back to previous MP3 and play it.
  void PreviousMp3();
  /// Index of the currently selected MP3 (0-based).
  int CurrentMp3Index() const { return current_mp3_; }
  /// Number of loaded MP3 files.
  int Mp3Count() const { return static_cast<int>(mp3_files_.size()); }

  // -- Callbacks from Audio lib (set in main.cpp) --
  void OnInfo(const char* info);
  void OnTitle(const char* title);

 private:
  void StartCurrentStation();
  void StartCurrentMp3();

  Audio* audio_ = nullptr;
  bool initialized_ = false;

  // Station list: {name, url}
  std::vector<std::pair<std::string, std::string>> stations_;
  int current_station_ = 0;
  MediaMode mode_ = MediaMode::kRadio;
  bool playing_ = false;
  int volume_ = 40;  // 0–100
  std::string current_title_;

  // SD MP3 file list and navigation.
  std::vector<std::string> mp3_files_;
  int current_mp3_ = 0;

  // State saved before TTS reply.
  bool was_playing_ = false;
  int saved_volume_ = -1;
  std::string saved_url_;

  // WiFi info (updated externally).
  std::string wifi_ssid_;
  int wifi_rssi_ = 0;
  int battery_pct_ = -1;

  friend void updatePlayerWifi(RadioPlayer& p, const std::string& ssid, int rssi);
};

/// Update WiFi info in the player snapshot.
void updatePlayerWifi(RadioPlayer& p, const std::string& ssid, int rssi);
