/// @file test_wifi_state.cpp
/// Unity tests for WifiManager pure-C++ state: accessors, default values,
/// SetApCredentials, and OnStateChange callback.
/// Compiles on native (Linux x86_64) with -D UNIT_TEST=1.
/// No WiFi/Arduino/Preferences hardware used — only the inline header methods
/// and the two pure state methods inlined below.

#include <unity.h>
#include <string>
#include <vector>
#include <functional>

// ---------------------------------------------------------------------------
// Include the pure-C++ header (no Arduino deps)
// Open private members so we can drive SetState in white-box tests.
// ---------------------------------------------------------------------------
#define private public
#include "../../include/wifi_manager.h"
#undef private

// ---------------------------------------------------------------------------
// WifiManager implementation — inline only the pure-C++ methods that don't
// pull in Arduino/WiFi/Preferences/WebServer headers.
// (SetOnStateChange, state(), IsConnected(), IsApMode(), ssid(), apSsid(),
//  apPassword(), backendUrl() are already inline in the header.)
// ---------------------------------------------------------------------------

void WifiManager::SetApCredentials(const std::string& ssid,
                                   const std::string& password) {
  ap_ssid_ = ssid;
  ap_password_ = password;
}

void WifiManager::SetState(State s, const std::string& info) {
  state_ = s;
  if (on_state_change_) on_state_change_(s, info);
}

// Hardware-dependent methods — not called in these tests; provide empty stubs
// so the linker is satisfied.
void WifiManager::Begin() {}
void WifiManager::Loop() {}
void WifiManager::StartApMode() {}
std::string WifiManager::ip() const { return ""; }
int WifiManager::rssi() const { return 0; }
std::string WifiManager::apIp() const { return ""; }
std::vector<WifiManager::ScanResult> WifiManager::Scan() { return {}; }
void WifiManager::LoadCredentials() {}
void WifiManager::SaveCredentials(const std::string&, const std::string&,
                                  const std::string&) {}
bool WifiManager::TryConnect(const std::string&, const std::string&,
                              uint32_t) { return false; }
void WifiManager::SetupApWebServer() {}
void WifiManager::StopApWebServer() {}

// ===========================================================================
// Tests
// ===========================================================================

void setUp() {}
void tearDown() {}

// --- Default state -----------------------------------------------------------

void test_default_state_is_idle() {
  WifiManager mgr;
  TEST_ASSERT_EQUAL(WifiManager::State::kIdle, mgr.state());
}

void test_not_connected_by_default() {
  WifiManager mgr;
  TEST_ASSERT_FALSE(mgr.IsConnected());
}

void test_not_ap_mode_by_default() {
  WifiManager mgr;
  TEST_ASSERT_FALSE(mgr.IsApMode());
}

void test_ssid_empty_by_default() {
  WifiManager mgr;
  TEST_ASSERT_TRUE(mgr.ssid().empty());
}

void test_backend_url_default() {
  WifiManager mgr;
  TEST_ASSERT_EQUAL_STRING("http://192.168.1.42:8000", mgr.backendUrl().c_str());
}

// --- SetApCredentials -------------------------------------------------------

void test_set_ap_credentials_ssid() {
  WifiManager mgr;
  mgr.SetApCredentials("MyAP", "secret123");
  TEST_ASSERT_EQUAL_STRING("MyAP", mgr.apSsid().c_str());
}

void test_set_ap_credentials_password() {
  WifiManager mgr;
  mgr.SetApCredentials("MyAP", "secret123");
  TEST_ASSERT_EQUAL_STRING("secret123", mgr.apPassword().c_str());
}

void test_ap_credentials_default_ssid() {
  WifiManager mgr;
  TEST_ASSERT_EQUAL_STRING("KillLife-Setup", mgr.apSsid().c_str());
}

void test_ap_credentials_default_password() {
  WifiManager mgr;
  TEST_ASSERT_EQUAL_STRING("killlife", mgr.apPassword().c_str());
}

// --- OnStateChange callback --------------------------------------------------

void test_callback_fires_on_state_change() {
  WifiManager mgr;
  int call_count = 0;
  WifiManager::State last_state = WifiManager::State::kIdle;
  std::string last_info;

  mgr.SetOnStateChange([&](WifiManager::State s, const std::string& info) {
    ++call_count;
    last_state = s;
    last_info = info;
  });

  mgr.SetState(WifiManager::State::kConnecting, "HomeSSID");
  TEST_ASSERT_EQUAL_INT(1, call_count);
  TEST_ASSERT_EQUAL(WifiManager::State::kConnecting, last_state);
  TEST_ASSERT_EQUAL_STRING("HomeSSID", last_info.c_str());
}

void test_state_reflects_after_setstate() {
  WifiManager mgr;
  mgr.SetState(WifiManager::State::kConnected, "192.168.1.10");
  TEST_ASSERT_EQUAL(WifiManager::State::kConnected, mgr.state());
  TEST_ASSERT_TRUE(mgr.IsConnected());
  TEST_ASSERT_FALSE(mgr.IsApMode());
}

void test_ap_mode_state() {
  WifiManager mgr;
  mgr.SetState(WifiManager::State::kApMode, "KillLife-Setup");
  TEST_ASSERT_TRUE(mgr.IsApMode());
  TEST_ASSERT_FALSE(mgr.IsConnected());
}

void test_failed_state() {
  WifiManager mgr;
  mgr.SetState(WifiManager::State::kFailed, "connection lost");
  TEST_ASSERT_EQUAL(WifiManager::State::kFailed, mgr.state());
  TEST_ASSERT_FALSE(mgr.IsConnected());
  TEST_ASSERT_FALSE(mgr.IsApMode());
}

void test_callback_not_called_without_registration() {
  WifiManager mgr;
  // No crash if no callback registered
  mgr.SetState(WifiManager::State::kConnecting, "test");
  TEST_ASSERT_EQUAL(WifiManager::State::kConnecting, mgr.state());
}

void test_multiple_state_transitions() {
  WifiManager mgr;
  int count = 0;
  mgr.SetOnStateChange([&](WifiManager::State, const std::string&) { ++count; });

  mgr.SetState(WifiManager::State::kConnecting, "");
  mgr.SetState(WifiManager::State::kFailed, "");
  mgr.SetState(WifiManager::State::kApMode, "");

  TEST_ASSERT_EQUAL_INT(3, count);
  TEST_ASSERT_TRUE(mgr.IsApMode());
}

// ===========================================================================
// Main
// ===========================================================================

int main() {
  UNITY_BEGIN();

  RUN_TEST(test_default_state_is_idle);
  RUN_TEST(test_not_connected_by_default);
  RUN_TEST(test_not_ap_mode_by_default);
  RUN_TEST(test_ssid_empty_by_default);
  RUN_TEST(test_backend_url_default);
  RUN_TEST(test_set_ap_credentials_ssid);
  RUN_TEST(test_set_ap_credentials_password);
  RUN_TEST(test_ap_credentials_default_ssid);
  RUN_TEST(test_ap_credentials_default_password);
  RUN_TEST(test_callback_fires_on_state_change);
  RUN_TEST(test_state_reflects_after_setstate);
  RUN_TEST(test_ap_mode_state);
  RUN_TEST(test_failed_state);
  RUN_TEST(test_callback_not_called_without_registration);
  RUN_TEST(test_multiple_state_transitions);

  return UNITY_END();
}
