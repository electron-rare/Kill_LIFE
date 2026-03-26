#include "voice_controller.h"
#include "firmware_utils.h"

#include <Arduino.h>  // yield() — feeds WDT, lets other FreeRTOS tasks run

#include <utility>

VoiceController::VoiceController(std::string device_id,
                                 BackendClient& backend,
                                 MediaController& media,
                                 UiRenderer& ui)
    : device_id_(std::move(device_id)),
      backend_(backend),
      media_(media),
      ui_(ui) {}

void VoiceController::Boot() {
  phase_ = VoicePhase::kIdle;
  RenderState("pret", IdleSummary(media_.Snapshot()), false);
  backend_.SendPlayerEvent(device_id_, "boot", media_.Snapshot(),
                           "voice-controller-ready");
}

bool VoiceController::BeginPushToTalk() {
  if (phase_ != VoicePhase::kIdle) {
    return false;
  }

  phase_ = VoicePhase::kRecording;
  RenderState("j'ecoute", "Maintiens le bouton pour parler.", true);
  return true;
}

bool VoiceController::CompletePushToTalk(const std::vector<uint8_t>& wav_data) {
  if (phase_ != VoicePhase::kRecording) {
    return false;
  }

  if (wav_data.empty()) {
    return Fail("capture audio vide");
  }

  phase_ = VoicePhase::kThinking;
  RenderState("je reflechis", "Envoi de la requete a Mascarade.", true);

  last_response_ = backend_.SubmitVoiceSession(device_id_, media_.Snapshot(),
                                               wav_data);
  yield();  // WDT: feed watchdog after HTTP POST round-trip

  if (!last_response_.ok) {
    const std::string error_text =
        last_response_.error.empty() ? "session vocale en echec"
                                     : last_response_.error;
    return Fail(error_text);
  }

  const MediaSnapshot before = media_.Snapshot();
  media_.ApplyIntent(last_response_.intent);
  const MediaSnapshot after = media_.Snapshot();

  if (ShouldPublishPlaybackStarted(before, after, last_response_.intent)) {
    const std::string detail =
        !after.station.empty() ? after.station : after.track;
    backend_.SendPlayerEvent(device_id_, "playback_started", after, detail);
  }

  media_.PrepareForReply(last_response_.player_action);

  phase_ = VoicePhase::kSpeaking;
  RenderState("je reponds",
              last_response_.reply_text.empty()
                  ? "Reponse audio en preparation."
                  : last_response_.reply_text,
              true);

  if (!last_response_.reply_audio_url.empty()) {
    std::vector<uint8_t> reply_audio;
    if (backend_.DownloadReplyAudio(last_response_.reply_audio_url,
                                    &reply_audio)) {
      yield();  // WDT: feed watchdog after audio download
      if (!media_.PlayReplyAudio(reply_audio)) {
        backend_.SendPlayerEvent(device_id_, "playback_failed",
                                 media_.Snapshot(),
                                 "tts reply playback failed");
      }
    } else {
      backend_.SendPlayerEvent(device_id_, "playback_failed", media_.Snapshot(),
                               "tts reply download failed");
    }
  }

  media_.RestoreAfterReply(last_response_.intent.resume_media_after_tts);

  phase_ = VoicePhase::kIdle;
  RenderState("pret", IdleSummary(media_.Snapshot()), false);
  return true;
}

bool VoiceController::Fail(const std::string& error_text) {
  phase_ = VoicePhase::kError;
  last_response_.ok = false;
  last_response_.error = error_text;
  RenderState("erreur reseau", error_text, false);
  backend_.SendPlayerEvent(device_id_, "voice_error", media_.Snapshot(),
                           error_text);
  media_.RestoreAfterReply(true);
  phase_ = VoicePhase::kIdle;
  RenderState("pret", IdleSummary(media_.Snapshot()), false);
  return false;
}

void VoiceController::RenderState(const std::string& headline,
                                  const std::string& summary,
                                  bool show_ring) {
  ui_.Render(media_.Snapshot(), phase_, headline, summary, show_ring);
}

std::string VoiceController::IdleSummary(const MediaSnapshot& media) {
  return FwIdleSummary(media);
}

bool VoiceController::ShouldPublishPlaybackStarted(
    const MediaSnapshot& before, const MediaSnapshot& after,
    const VoiceIntent& intent) {
  return FwShouldPublishPlaybackStarted(before, after, intent);
}
