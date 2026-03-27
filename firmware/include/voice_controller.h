#pragma once

#include <cstdint>
#include <string>
#include <vector>

enum class MediaMode {
  kIdle,
  kMp3,
  kRadio,
};

enum class VoicePhase {
  kIdle,
  kRecording,
  kThinking,
  kSpeaking,
  kError,
};

enum class PlayerAction {
  kNone,
  kDuck,
  kStopResume,
};

struct MediaSnapshot {
  MediaMode mode = MediaMode::kIdle;
  bool playing = false;
  std::string station;
  std::string track;
  int volume = 40;
  int battery_pct = -1;
  std::string wifi_ssid;
  int wifi_rssi = 0;
  std::vector<std::string> available_stations;
};

struct VoiceIntent {
  std::string type = "none";
  std::string target;
  std::string value;
  std::string spoken_confirmation;
  bool resume_media_after_tts = false;
};

struct VoiceSessionResponse {
  bool ok = false;
  std::string session_id;
  std::string transcript;
  VoiceIntent intent;
  std::string reply_text;
  std::string reply_audio_url;
  PlayerAction player_action = PlayerAction::kNone;
  std::string provider = "none";
  std::string error;
};

class BackendClient {
public:
  virtual ~BackendClient() = default;

  virtual bool SendPlayerEvent(const std::string &device_id, const std::string &event_name,
                               const MediaSnapshot &media, const std::string &detail) = 0;

  virtual VoiceSessionResponse SubmitVoiceSession(const std::string &device_id,
                                                  const MediaSnapshot &media,
                                                  const std::vector<uint8_t> &wav_data) = 0;

  virtual bool DownloadReplyAudio(const std::string &audio_url, std::vector<uint8_t> *wav_data) = 0;
};

class MediaController {
public:
  virtual ~MediaController() = default;

  virtual MediaSnapshot Snapshot() const = 0;
  virtual void ApplyIntent(const VoiceIntent &intent) = 0;
  virtual void PrepareForReply(PlayerAction action) = 0;
  virtual void RestoreAfterReply(bool resume_media_after_tts) = 0;
  virtual bool PlayReplyAudio(const std::vector<uint8_t> &wav_data) = 0;
};

class UiRenderer {
public:
  virtual ~UiRenderer() = default;

  virtual void Render(const MediaSnapshot &media, VoicePhase phase, const std::string &headline,
                      const std::string &summary, bool show_ring) = 0;
};

class VoiceController {
public:
  VoiceController(std::string device_id, BackendClient &backend, MediaController &media,
                  UiRenderer &ui);

  void Boot();
  bool BeginPushToTalk();
  bool CompletePushToTalk(const std::vector<uint8_t> &wav_data);

  VoicePhase phase() const { return phase_; }
  const VoiceSessionResponse &last_response() const { return last_response_; }

private:
  bool Fail(const std::string &error_text);
  void RenderState(const std::string &headline, const std::string &summary, bool show_ring);
  static std::string IdleSummary(const MediaSnapshot &media);
  static bool ShouldPublishPlaybackStarted(const MediaSnapshot &before, const MediaSnapshot &after,
                                           const VoiceIntent &intent);

  std::string device_id_;
  BackendClient &backend_;
  MediaController &media_;
  UiRenderer &ui_;
  VoicePhase phase_ = VoicePhase::kIdle;
  VoiceSessionResponse last_response_;
};
