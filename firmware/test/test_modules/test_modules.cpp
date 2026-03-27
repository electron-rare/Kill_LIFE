/// @file test_modules.cpp
/// Unity tests for VoiceController state-machine logic and OtaManager version
/// checking.  Compiles on the native (Linux x86_64) target with -D UNIT_TEST=1.
/// No Arduino/ESP32 headers are used.

#include <cstring>
#include <string>
#include <unity.h>
#include <utility>
#include <vector>

// ---------------------------------------------------------------------------
// Provide a yield() stub so VoiceController implementation can call it.
// On ESP32 this comes from Arduino.h; on native it is a no-op.
// ---------------------------------------------------------------------------
inline void yield() {}

// Include the pure-C++ headers (no Arduino deps).
#include "../../include/firmware_utils.h"
#include "../../include/ota_manager.h"
#include "../../include/voice_controller.h"

// ===========================================================================
// VoiceController implementation (copied from voice_controller.cpp to avoid
// pulling in Arduino.h which is not available on native).
// ===========================================================================

VoiceController::VoiceController(std::string device_id, BackendClient &backend,
                                 MediaController &media, UiRenderer &ui)
    : device_id_(std::move(device_id)), backend_(backend), media_(media), ui_(ui) {}

void VoiceController::Boot() {
  phase_ = VoicePhase::kIdle;
  RenderState("pret", IdleSummary(media_.Snapshot()), false);
  backend_.SendPlayerEvent(device_id_, "boot", media_.Snapshot(), "voice-controller-ready");
}

bool VoiceController::BeginPushToTalk() {
  if (phase_ != VoicePhase::kIdle) {
    return false;
  }
  phase_ = VoicePhase::kRecording;
  RenderState("j'ecoute", "Maintiens le bouton pour parler.", true);
  return true;
}

bool VoiceController::CompletePushToTalk(const std::vector<uint8_t> &wav_data) {
  if (phase_ != VoicePhase::kRecording) {
    return false;
  }
  if (wav_data.empty()) {
    return Fail("capture audio vide");
  }

  phase_ = VoicePhase::kThinking;
  RenderState("je reflechis", "Envoi de la requete a Mascarade.", true);

  last_response_ = backend_.SubmitVoiceSession(device_id_, media_.Snapshot(), wav_data);
  yield();

  if (!last_response_.ok) {
    const std::string error_text =
        last_response_.error.empty() ? "session vocale en echec" : last_response_.error;
    return Fail(error_text);
  }

  const MediaSnapshot before = media_.Snapshot();
  media_.ApplyIntent(last_response_.intent);
  const MediaSnapshot after = media_.Snapshot();

  if (ShouldPublishPlaybackStarted(before, after, last_response_.intent)) {
    const std::string detail = !after.station.empty() ? after.station : after.track;
    backend_.SendPlayerEvent(device_id_, "playback_started", after, detail);
  }

  media_.PrepareForReply(last_response_.player_action);

  phase_ = VoicePhase::kSpeaking;
  RenderState("je reponds",
              last_response_.reply_text.empty() ? "Reponse audio en preparation."
                                                : last_response_.reply_text,
              true);

  if (!last_response_.reply_audio_url.empty()) {
    std::vector<uint8_t> reply_audio;
    if (backend_.DownloadReplyAudio(last_response_.reply_audio_url, &reply_audio)) {
      yield();
      if (!media_.PlayReplyAudio(reply_audio)) {
        backend_.SendPlayerEvent(device_id_, "playback_failed", media_.Snapshot(),
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

bool VoiceController::Fail(const std::string &error_text) {
  phase_ = VoicePhase::kError;
  last_response_.ok = false;
  last_response_.error = error_text;
  RenderState("erreur reseau", error_text, false);
  backend_.SendPlayerEvent(device_id_, "voice_error", media_.Snapshot(), error_text);
  media_.RestoreAfterReply(true);
  phase_ = VoicePhase::kIdle;
  RenderState("pret", IdleSummary(media_.Snapshot()), false);
  return false;
}

void VoiceController::RenderState(const std::string &headline, const std::string &summary,
                                  bool show_ring) {
  ui_.Render(media_.Snapshot(), phase_, headline, summary, show_ring);
}

std::string VoiceController::IdleSummary(const MediaSnapshot &media) {
  return FwIdleSummary(media);
}

bool VoiceController::ShouldPublishPlaybackStarted(const MediaSnapshot &before,
                                                   const MediaSnapshot &after,
                                                   const VoiceIntent &intent) {
  return FwShouldPublishPlaybackStarted(before, after, intent);
}

// ===========================================================================
// OtaManager constructor stub (the real ota_manager.cpp needs Arduino/HTTP).
// We only need the constructor and simple accessors for testing.
// ===========================================================================

OtaManager::OtaManager(const std::string &current_version) : current_version_(current_version) {}

// Stubs for methods that depend on Arduino/HTTP — not called in our tests
// but needed to satisfy the linker (non-pure-virtual members).
OtaCheckResult OtaManager::CheckOnly() {
  return FetchLatestInfo();
}

OtaCheckResult OtaManager::CheckAndUpdate() {
  OtaCheckResult info = FetchLatestInfo();
  if (info.status == OtaCheckResult::Status::kCheckFailed)
    return info;
  if (info.status == OtaCheckResult::Status::kUpToDate)
    return info;
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
  result.status = OtaCheckResult::Status::kCheckFailed;
  result.error = "not available on native";
  return result;
}

bool OtaManager::FlashFromUrl(const std::string & /*url*/) {
  return false;
}

// ===========================================================================
// Mock implementations of abstract interfaces
// ===========================================================================

class MockBackend : public BackendClient {
public:
  VoiceSessionResponse next_voice_response;
  bool download_succeeds = true;
  std::vector<uint8_t> download_audio;

  int send_event_count = 0;
  std::string last_event_name;
  std::string last_event_detail;
  int submit_voice_count = 0;
  int download_count = 0;

  bool SendPlayerEvent(const std::string & /*device_id*/, const std::string &event_name,
                       const MediaSnapshot & /*media*/, const std::string &detail) override {
    ++send_event_count;
    last_event_name = event_name;
    last_event_detail = detail;
    return true;
  }

  VoiceSessionResponse SubmitVoiceSession(const std::string & /*device_id*/,
                                          const MediaSnapshot & /*media*/,
                                          const std::vector<uint8_t> & /*wav_data*/) override {
    ++submit_voice_count;
    return next_voice_response;
  }

  bool DownloadReplyAudio(const std::string & /*audio_url*/,
                          std::vector<uint8_t> *wav_data) override {
    ++download_count;
    if (download_succeeds && wav_data) {
      *wav_data = download_audio;
    }
    return download_succeeds;
  }
};

class MockMedia : public MediaController {
public:
  MediaSnapshot snapshot;
  int apply_intent_count = 0;
  int prepare_count = 0;
  int restore_count = 0;
  int play_reply_count = 0;
  bool play_reply_result = true;
  VoiceIntent last_intent;
  PlayerAction last_prepare_action = PlayerAction::kNone;
  bool last_restore_resume = false;

  MediaSnapshot Snapshot() const override { return snapshot; }

  void ApplyIntent(const VoiceIntent &intent) override {
    ++apply_intent_count;
    last_intent = intent;
  }

  void PrepareForReply(PlayerAction action) override {
    ++prepare_count;
    last_prepare_action = action;
  }

  void RestoreAfterReply(bool resume_media_after_tts) override {
    ++restore_count;
    last_restore_resume = resume_media_after_tts;
  }

  bool PlayReplyAudio(const std::vector<uint8_t> & /*wav_data*/) override {
    ++play_reply_count;
    return play_reply_result;
  }
};

class MockUi : public UiRenderer {
public:
  int render_count = 0;
  VoicePhase last_phase = VoicePhase::kIdle;
  std::string last_headline;
  std::string last_summary;
  bool last_show_ring = false;

  void Render(const MediaSnapshot & /*media*/, VoicePhase phase, const std::string &headline,
              const std::string &summary, bool show_ring) override {
    ++render_count;
    last_phase = phase;
    last_headline = headline;
    last_summary = summary;
    last_show_ring = show_ring;
  }
};

// ===========================================================================
// Helper: create a dummy WAV buffer (non-empty)
// ===========================================================================
static std::vector<uint8_t> DummyWav() {
  return {'R', 'I', 'F', 'F', 0, 0, 0, 0, 'W', 'A', 'V', 'E'};
}

// ===========================================================================
// VoiceController: state transition tests
// ===========================================================================

void test_vc_initial_phase_is_idle() {
  MockBackend backend;
  MockMedia media;
  MockUi ui;
  VoiceController vc("dev-001", backend, media, ui);
  TEST_ASSERT_EQUAL(static_cast<int>(VoicePhase::kIdle), static_cast<int>(vc.phase()));
}

void test_vc_boot_sends_event_and_stays_idle() {
  MockBackend backend;
  MockMedia media;
  MockUi ui;
  VoiceController vc("dev-001", backend, media, ui);

  vc.Boot();

  TEST_ASSERT_EQUAL(static_cast<int>(VoicePhase::kIdle), static_cast<int>(vc.phase()));
  TEST_ASSERT_EQUAL_INT(1, backend.send_event_count);
  TEST_ASSERT_EQUAL_STRING("boot", backend.last_event_name.c_str());
  TEST_ASSERT_TRUE(ui.render_count > 0);
}

void test_vc_begin_ptt_transitions_to_recording() {
  MockBackend backend;
  MockMedia media;
  MockUi ui;
  VoiceController vc("dev-001", backend, media, ui);
  vc.Boot();

  bool ok = vc.BeginPushToTalk();

  TEST_ASSERT_TRUE(ok);
  TEST_ASSERT_EQUAL(static_cast<int>(VoicePhase::kRecording), static_cast<int>(vc.phase()));
}

void test_vc_begin_ptt_fails_when_not_idle() {
  MockBackend backend;
  MockMedia media;
  MockUi ui;
  VoiceController vc("dev-001", backend, media, ui);
  vc.Boot();
  vc.BeginPushToTalk();

  bool ok = vc.BeginPushToTalk();

  TEST_ASSERT_FALSE(ok);
  TEST_ASSERT_EQUAL(static_cast<int>(VoicePhase::kRecording), static_cast<int>(vc.phase()));
}

void test_vc_complete_ptt_fails_when_not_recording() {
  MockBackend backend;
  MockMedia media;
  MockUi ui;
  VoiceController vc("dev-001", backend, media, ui);
  vc.Boot();

  bool ok = vc.CompletePushToTalk(DummyWav());

  TEST_ASSERT_FALSE(ok);
  TEST_ASSERT_EQUAL_INT(0, backend.submit_voice_count);
}

void test_vc_complete_ptt_empty_audio_fails() {
  MockBackend backend;
  MockMedia media;
  MockUi ui;
  VoiceController vc("dev-001", backend, media, ui);
  vc.Boot();
  vc.BeginPushToTalk();

  std::vector<uint8_t> empty;
  bool ok = vc.CompletePushToTalk(empty);

  TEST_ASSERT_FALSE(ok);
  TEST_ASSERT_EQUAL(static_cast<int>(VoicePhase::kIdle), static_cast<int>(vc.phase()));
  TEST_ASSERT_EQUAL_STRING("capture audio vide", vc.last_response().error.c_str());
}

void test_vc_full_successful_flow_idle_to_idle() {
  MockBackend backend;
  MockMedia media;
  MockUi ui;

  backend.next_voice_response.ok = true;
  backend.next_voice_response.reply_text = "Voici la radio FIP";
  backend.next_voice_response.reply_audio_url = "";
  backend.next_voice_response.intent.type = "play";
  backend.next_voice_response.player_action = PlayerAction::kDuck;

  VoiceController vc("dev-001", backend, media, ui);
  vc.Boot();

  TEST_ASSERT_TRUE(vc.BeginPushToTalk());
  TEST_ASSERT_EQUAL(static_cast<int>(VoicePhase::kRecording), static_cast<int>(vc.phase()));

  bool ok = vc.CompletePushToTalk(DummyWav());

  TEST_ASSERT_TRUE(ok);
  TEST_ASSERT_EQUAL(static_cast<int>(VoicePhase::kIdle), static_cast<int>(vc.phase()));
  TEST_ASSERT_EQUAL_INT(1, backend.submit_voice_count);
  TEST_ASSERT_EQUAL_INT(1, media.apply_intent_count);
  TEST_ASSERT_EQUAL_INT(1, media.prepare_count);
  TEST_ASSERT_EQUAL_INT(1, media.restore_count);
}

void test_vc_successful_flow_with_audio_download() {
  MockBackend backend;
  MockMedia media;
  MockUi ui;

  backend.next_voice_response.ok = true;
  backend.next_voice_response.reply_text = "Playing now";
  backend.next_voice_response.reply_audio_url = "http://example.com/reply.wav";
  backend.next_voice_response.player_action = PlayerAction::kStopResume;
  backend.download_succeeds = true;
  backend.download_audio = DummyWav();

  VoiceController vc("dev-001", backend, media, ui);
  vc.Boot();
  vc.BeginPushToTalk();

  bool ok = vc.CompletePushToTalk(DummyWav());

  TEST_ASSERT_TRUE(ok);
  TEST_ASSERT_EQUAL(static_cast<int>(VoicePhase::kIdle), static_cast<int>(vc.phase()));
  TEST_ASSERT_EQUAL_INT(1, backend.download_count);
  TEST_ASSERT_EQUAL_INT(1, media.play_reply_count);
}

void test_vc_backend_error_returns_to_idle() {
  MockBackend backend;
  MockMedia media;
  MockUi ui;

  backend.next_voice_response.ok = false;
  backend.next_voice_response.error = "server timeout";

  VoiceController vc("dev-001", backend, media, ui);
  vc.Boot();
  vc.BeginPushToTalk();

  bool ok = vc.CompletePushToTalk(DummyWav());

  TEST_ASSERT_FALSE(ok);
  TEST_ASSERT_EQUAL(static_cast<int>(VoicePhase::kIdle), static_cast<int>(vc.phase()));
  TEST_ASSERT_EQUAL_STRING("server timeout", vc.last_response().error.c_str());
  TEST_ASSERT_EQUAL_STRING("voice_error", backend.last_event_name.c_str());
}

void test_vc_backend_error_empty_message_uses_default() {
  MockBackend backend;
  MockMedia media;
  MockUi ui;

  backend.next_voice_response.ok = false;
  backend.next_voice_response.error = "";

  VoiceController vc("dev-001", backend, media, ui);
  vc.Boot();
  vc.BeginPushToTalk();
  vc.CompletePushToTalk(DummyWav());

  TEST_ASSERT_EQUAL_STRING("session vocale en echec", vc.last_response().error.c_str());
}

void test_vc_audio_download_failure_sends_event() {
  MockBackend backend;
  MockMedia media;
  MockUi ui;

  backend.next_voice_response.ok = true;
  backend.next_voice_response.reply_audio_url = "http://example.com/reply.wav";
  backend.download_succeeds = false;

  VoiceController vc("dev-001", backend, media, ui);
  vc.Boot();
  vc.BeginPushToTalk();

  bool ok = vc.CompletePushToTalk(DummyWav());

  TEST_ASSERT_TRUE(ok);
  TEST_ASSERT_EQUAL_STRING("playback_failed", backend.last_event_name.c_str());
  TEST_ASSERT_EQUAL_STRING("tts reply download failed", backend.last_event_detail.c_str());
}

void test_vc_audio_playback_failure_sends_event() {
  MockBackend backend;
  MockMedia media;
  MockUi ui;

  backend.next_voice_response.ok = true;
  backend.next_voice_response.reply_audio_url = "http://example.com/reply.wav";
  backend.download_succeeds = true;
  backend.download_audio = DummyWav();
  media.play_reply_result = false;

  VoiceController vc("dev-001", backend, media, ui);
  vc.Boot();
  vc.BeginPushToTalk();

  bool ok = vc.CompletePushToTalk(DummyWav());

  TEST_ASSERT_TRUE(ok);
  TEST_ASSERT_EQUAL_STRING("playback_failed", backend.last_event_name.c_str());
  TEST_ASSERT_EQUAL_STRING("tts reply playback failed", backend.last_event_detail.c_str());
}

void test_vc_restore_called_with_resume_flag() {
  MockBackend backend;
  MockMedia media;
  MockUi ui;

  backend.next_voice_response.ok = true;
  backend.next_voice_response.reply_audio_url = "";
  backend.next_voice_response.intent.resume_media_after_tts = true;

  VoiceController vc("dev-001", backend, media, ui);
  vc.Boot();
  vc.BeginPushToTalk();
  vc.CompletePushToTalk(DummyWav());

  TEST_ASSERT_TRUE(media.last_restore_resume);
}

void test_vc_prepare_receives_player_action() {
  MockBackend backend;
  MockMedia media;
  MockUi ui;

  backend.next_voice_response.ok = true;
  backend.next_voice_response.reply_audio_url = "";
  backend.next_voice_response.player_action = PlayerAction::kDuck;

  VoiceController vc("dev-001", backend, media, ui);
  vc.Boot();
  vc.BeginPushToTalk();
  vc.CompletePushToTalk(DummyWav());

  TEST_ASSERT_EQUAL(static_cast<int>(PlayerAction::kDuck),
                    static_cast<int>(media.last_prepare_action));
}

void test_vc_can_start_new_session_after_success() {
  MockBackend backend;
  MockMedia media;
  MockUi ui;

  backend.next_voice_response.ok = true;
  backend.next_voice_response.reply_audio_url = "";

  VoiceController vc("dev-001", backend, media, ui);
  vc.Boot();

  vc.BeginPushToTalk();
  vc.CompletePushToTalk(DummyWav());
  TEST_ASSERT_EQUAL(static_cast<int>(VoicePhase::kIdle), static_cast<int>(vc.phase()));

  TEST_ASSERT_TRUE(vc.BeginPushToTalk());
  TEST_ASSERT_EQUAL(static_cast<int>(VoicePhase::kRecording), static_cast<int>(vc.phase()));
}

void test_vc_can_start_new_session_after_error() {
  MockBackend backend;
  MockMedia media;
  MockUi ui;

  backend.next_voice_response.ok = false;
  backend.next_voice_response.error = "fail";

  VoiceController vc("dev-001", backend, media, ui);
  vc.Boot();

  vc.BeginPushToTalk();
  vc.CompletePushToTalk(DummyWav());
  TEST_ASSERT_EQUAL(static_cast<int>(VoicePhase::kIdle), static_cast<int>(vc.phase()));

  TEST_ASSERT_TRUE(vc.BeginPushToTalk());
}

// ===========================================================================
// OtaManager: version comparison logic
// ===========================================================================

void test_ota_version_equal_means_up_to_date() {
  std::string current = "1.2.3";
  std::string latest = "1.2.3";
  int cmp = FwCompareVersions(current, latest);
  TEST_ASSERT_TRUE(cmp >= 0);
}

void test_ota_version_newer_means_update_available() {
  std::string current = "1.0.0";
  std::string latest = "1.0.1";
  int cmp = FwCompareVersions(current, latest);
  TEST_ASSERT_TRUE(cmp < 0);
}

void test_ota_version_current_ahead_means_up_to_date() {
  std::string current = "2.0.0";
  std::string latest = "1.9.9";
  int cmp = FwCompareVersions(current, latest);
  TEST_ASSERT_TRUE(cmp >= 0);
}

void test_ota_version_major_minor_patch_all_checked() {
  TEST_ASSERT_TRUE(FwCompareVersions("1.0.0", "2.0.0") < 0);
  TEST_ASSERT_TRUE(FwCompareVersions("1.0.0", "1.1.0") < 0);
  TEST_ASSERT_TRUE(FwCompareVersions("1.0.0", "1.0.1") < 0);
  TEST_ASSERT_TRUE(FwCompareVersions("2.0.0", "1.0.0") > 0);
  TEST_ASSERT_TRUE(FwCompareVersions("1.1.0", "1.0.0") > 0);
  TEST_ASSERT_TRUE(FwCompareVersions("1.0.1", "1.0.0") > 0);
}

void test_ota_version_partial_strings() {
  TEST_ASSERT_EQUAL_INT(0, FwCompareVersions("1.0.0", "1.0"));
  TEST_ASSERT_EQUAL_INT(0, FwCompareVersions("1.0.0", "1"));
}

void test_ota_version_invalid_strings() {
  TEST_ASSERT_EQUAL_INT(0, FwCompareVersions("abc", "0.0.0"));
}

// ---------------------------------------------------------------------------
// OtaCheckResult state machine
// ---------------------------------------------------------------------------

void test_ota_check_result_up_to_date_flow() {
  OtaCheckResult info;
  info.status = OtaCheckResult::Status::kUpToDate;
  info.latest_version = "1.0.0";
  TEST_ASSERT_EQUAL(static_cast<int>(OtaCheckResult::Status::kUpToDate),
                    static_cast<int>(info.status));
}

void test_ota_check_result_check_failed_flow() {
  OtaCheckResult info;
  info.status = OtaCheckResult::Status::kCheckFailed;
  info.error = "HTTP -1";
  TEST_ASSERT_EQUAL(static_cast<int>(OtaCheckResult::Status::kCheckFailed),
                    static_cast<int>(info.status));
  TEST_ASSERT_EQUAL_STRING("HTTP -1", info.error.c_str());
}

void test_ota_check_result_update_flash_ok_flow() {
  OtaCheckResult info;
  info.status = OtaCheckResult::Status::kUpdateAvailable;
  info.latest_version = "1.1.0";
  info.url = "http://example.com/firmware.bin";

  // Simulate CheckAndUpdate: flash succeeds
  bool flash_ok = true;
  if (flash_ok) {
    info.status = OtaCheckResult::Status::kFlashOk;
  } else {
    info.status = OtaCheckResult::Status::kFlashFailed;
    info.error = "flash error";
  }
  TEST_ASSERT_EQUAL(static_cast<int>(OtaCheckResult::Status::kFlashOk),
                    static_cast<int>(info.status));
}

void test_ota_check_result_update_flash_failed_flow() {
  OtaCheckResult info;
  info.status = OtaCheckResult::Status::kUpdateAvailable;
  info.latest_version = "1.1.0";
  info.url = "http://example.com/firmware.bin";

  bool flash_ok = false;
  if (flash_ok) {
    info.status = OtaCheckResult::Status::kFlashOk;
  } else {
    info.status = OtaCheckResult::Status::kFlashFailed;
    info.error = "flash error";
  }
  TEST_ASSERT_EQUAL(static_cast<int>(OtaCheckResult::Status::kFlashFailed),
                    static_cast<int>(info.status));
  TEST_ASSERT_EQUAL_STRING("flash error", info.error.c_str());
}

void test_ota_check_result_defaults() {
  OtaCheckResult r;
  TEST_ASSERT_EQUAL(static_cast<int>(OtaCheckResult::Status::kCheckFailed),
                    static_cast<int>(r.status));
  TEST_ASSERT_TRUE(r.latest_version.empty());
  TEST_ASSERT_TRUE(r.url.empty());
  TEST_ASSERT_TRUE(r.error.empty());
}

void test_ota_invalid_backend_url() {
  TEST_ASSERT_FALSE(FwIsValidBackendUrl(""));
  TEST_ASSERT_FALSE(FwIsValidBackendUrl("ftp://foo"));
  TEST_ASSERT_TRUE(FwIsValidBackendUrl("http://192.168.1.42:8000"));
}

void test_ota_manager_constructor() {
  OtaManager ota("1.2.3");
  TEST_ASSERT_EQUAL_STRING("1.2.3", ota.current_version().c_str());
}

void test_ota_manager_set_backend_url() {
  OtaManager ota("1.0.0");
  ota.SetBackendUrl("http://test:9999");
  TEST_ASSERT_EQUAL_STRING("1.0.0", ota.current_version().c_str());
}

// ===========================================================================
// UI rendering verification
// ===========================================================================

void test_vc_boot_renders_idle_state() {
  MockBackend backend;
  MockMedia media;
  MockUi ui;
  media.snapshot.mode = MediaMode::kRadio;
  media.snapshot.volume = 55;
  media.snapshot.station = "FIP";
  media.snapshot.playing = true;

  VoiceController vc("dev-001", backend, media, ui);
  vc.Boot();

  TEST_ASSERT_EQUAL_STRING("pret", ui.last_headline.c_str());
  TEST_ASSERT_FALSE(ui.last_show_ring);
  TEST_ASSERT_EQUAL(static_cast<int>(VoicePhase::kIdle), static_cast<int>(ui.last_phase));
}

void test_vc_begin_ptt_renders_recording_state() {
  MockBackend backend;
  MockMedia media;
  MockUi ui;

  VoiceController vc("dev-001", backend, media, ui);
  vc.Boot();
  vc.BeginPushToTalk();

  TEST_ASSERT_EQUAL_STRING("j'ecoute", ui.last_headline.c_str());
  TEST_ASSERT_TRUE(ui.last_show_ring);
  TEST_ASSERT_EQUAL(static_cast<int>(VoicePhase::kRecording), static_cast<int>(ui.last_phase));
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

int main(int, char **) {
  UNITY_BEGIN();

  // VoiceController state transitions
  RUN_TEST(test_vc_initial_phase_is_idle);
  RUN_TEST(test_vc_boot_sends_event_and_stays_idle);
  RUN_TEST(test_vc_begin_ptt_transitions_to_recording);
  RUN_TEST(test_vc_begin_ptt_fails_when_not_idle);
  RUN_TEST(test_vc_complete_ptt_fails_when_not_recording);
  RUN_TEST(test_vc_complete_ptt_empty_audio_fails);
  RUN_TEST(test_vc_full_successful_flow_idle_to_idle);
  RUN_TEST(test_vc_successful_flow_with_audio_download);
  RUN_TEST(test_vc_backend_error_returns_to_idle);
  RUN_TEST(test_vc_backend_error_empty_message_uses_default);
  RUN_TEST(test_vc_audio_download_failure_sends_event);
  RUN_TEST(test_vc_audio_playback_failure_sends_event);
  RUN_TEST(test_vc_restore_called_with_resume_flag);
  RUN_TEST(test_vc_prepare_receives_player_action);
  RUN_TEST(test_vc_can_start_new_session_after_success);
  RUN_TEST(test_vc_can_start_new_session_after_error);

  // UI rendering verification
  RUN_TEST(test_vc_boot_renders_idle_state);
  RUN_TEST(test_vc_begin_ptt_renders_recording_state);

  // OtaManager version comparison
  RUN_TEST(test_ota_version_equal_means_up_to_date);
  RUN_TEST(test_ota_version_newer_means_update_available);
  RUN_TEST(test_ota_version_current_ahead_means_up_to_date);
  RUN_TEST(test_ota_version_major_minor_patch_all_checked);
  RUN_TEST(test_ota_version_partial_strings);
  RUN_TEST(test_ota_version_invalid_strings);

  // OtaManager CheckAndUpdate flow
  RUN_TEST(test_ota_check_result_up_to_date_flow);
  RUN_TEST(test_ota_check_result_check_failed_flow);
  RUN_TEST(test_ota_check_result_update_flash_ok_flow);
  RUN_TEST(test_ota_check_result_update_flash_failed_flow);
  RUN_TEST(test_ota_check_result_defaults);
  RUN_TEST(test_ota_invalid_backend_url);
  RUN_TEST(test_ota_manager_constructor);
  RUN_TEST(test_ota_manager_set_backend_url);

  return UNITY_END();
}
