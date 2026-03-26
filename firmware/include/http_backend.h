#pragma once

#include "voice_controller.h"

#include <string>

/// HTTP client that talks to the Mascarade /device/v1/* endpoints.
class HttpBackend : public BackendClient {
 public:
  /// @param base_url  e.g. "http://192.168.1.42:8000"
  explicit HttpBackend(const std::string& base_url);

  bool SendPlayerEvent(const std::string& device_id,
                       const std::string& event_name,
                       const MediaSnapshot& media,
                       const std::string& detail) override;

  VoiceSessionResponse SubmitVoiceSession(
      const std::string& device_id,
      const MediaSnapshot& media,
      const std::vector<uint8_t>& wav_data) override;

  bool DownloadReplyAudio(const std::string& audio_url,
                          std::vector<uint8_t>* wav_data) override;

 private:
  std::string base_url_;
};
