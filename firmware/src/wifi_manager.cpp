#include "wifi_manager.h"

#include <Arduino.h>

#include <DNSServer.h>
#include <Preferences.h>
#include <WebServer.h>
#include <WiFi.h>

// ---------------------------------------------------------------------------
// NVS namespace
// ---------------------------------------------------------------------------
static constexpr const char *kNvsNamespace = "killlife";
static Preferences prefs;

// ---------------------------------------------------------------------------
// Captive portal
// ---------------------------------------------------------------------------
static WebServer *web_server = nullptr;
static DNSServer *dns_server = nullptr;
static WifiManager *g_mgr = nullptr; // back-pointer for handlers

// HTML page served by the captive portal.
static const char kPortalHtml[] PROGMEM = R"rawhtml(
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Kill_LIFE WiFi</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:system-ui,sans-serif;background:#111;color:#eee;padding:20px;max-width:420px;margin:0 auto}
h1{font-size:1.4em;margin-bottom:16px;color:#0ff}
.net{background:#222;padding:12px;margin:6px 0;border-radius:8px;cursor:pointer;display:flex;justify-content:space-between}
.net:hover{background:#333}
.rssi{color:#888;font-size:.85em}
.open{color:#4f4}
form{margin-top:20px}
label{display:block;margin:12px 0 4px;font-size:.9em;color:#aaa}
input{width:100%;padding:10px;border:1px solid #444;border-radius:6px;background:#222;color:#eee;font-size:1em}
button{margin-top:16px;width:100%;padding:12px;border:none;border-radius:8px;background:#0aa;color:#fff;font-size:1.1em;cursor:pointer}
button:hover{background:#0cc}
.msg{padding:12px;margin:12px 0;border-radius:8px;text-align:center}
.ok{background:#062}
.err{background:#600}
#scan{margin-bottom:16px}
</style>
</head>
<body>
<h1>&#x1f4e1; Kill_LIFE WiFi</h1>
<div id="scan"><em>Scanning...</em></div>
<form method="POST" action="/save">
  <label>SSID</label>
  <input name="ssid" id="ssid" required>
  <label>Password</label>
  <input name="pass" type="password">
  <label>Backend URL</label>
  <input name="backend" value="__BACKEND__">
  <button type="submit">Connect</button>
</form>
<script>
fetch('/scan').then(r=>r.json()).then(nets=>{
  let container=document.getElementById('scan');
  container.textContent='';
  if(!nets.length){container.innerHTML='<em>No networks found</em>';return;}
  nets.forEach(n=>{
    let div=document.createElement('div');
    div.className='net';
    div.onclick=()=>{document.getElementById('ssid').value=n.ssid;};
    let nameSpan=document.createElement('span');
    nameSpan.textContent=n.ssid+' ';
    if(n.open){let o=document.createElement('span');o.className='open';o.textContent='open';nameSpan.appendChild(o);}
    else{nameSpan.insertAdjacentHTML('beforeend','&#x1f512;');}
    let rssiSpan=document.createElement('span');
    rssiSpan.className='rssi';
    rssiSpan.textContent=n.rssi+' dBm';
    div.appendChild(nameSpan);
    div.appendChild(rssiSpan);
    container.appendChild(div);
  });
});
</script>
</body>
</html>
)rawhtml";

static const char kSavedHtml[] PROGMEM = R"rawhtml(
<!DOCTYPE html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Kill_LIFE</title>
<style>body{font-family:system-ui;background:#111;color:#eee;padding:40px;text-align:center}</style>
</head><body>
<h2 style="color:#0f0">&#x2705; Saved!</h2>
<p>Connecting to <strong>__SSID__</strong>...</p>
<p style="color:#888;margin-top:20px">The device will reboot in a few seconds.</p>
</body></html>
)rawhtml";

// ---------------------------------------------------------------------------
void WifiManager::SetApCredentials(const std::string &ssid, const std::string &password) {
  ap_ssid_ = ssid;
  ap_password_ = password;
}

// ---------------------------------------------------------------------------
void WifiManager::Begin() {
  LoadCredentials();

  if (saved_ssid_.empty()) {
    Serial.println("[wifi] no saved credentials → AP mode");
    StartApMode();
    return;
  }

  SetState(State::kConnecting, saved_ssid_);
  if (TryConnect(saved_ssid_, saved_pass_)) {
    current_ssid_ = saved_ssid_;
    SetState(State::kConnected, WiFi.localIP().toString().c_str());
    Serial.printf("[wifi] connected to %s — %s\n", current_ssid_.c_str(),
                  WiFi.localIP().toString().c_str());
  } else {
    Serial.println("[wifi] connection failed → AP mode");
    StartApMode();
  }
}

// ---------------------------------------------------------------------------
void WifiManager::Loop() {
  if (server_running_) {
    dns_server->processNextRequest();
    web_server->handleClient();
  }

  // Check WiFi still connected in STA mode.
  if (state_ == State::kConnected && WiFi.status() != WL_CONNECTED) {
    SetState(State::kConnecting, "reconnecting...");
    if (TryConnect(saved_ssid_, saved_pass_, 8000)) {
      SetState(State::kConnected, WiFi.localIP().toString().c_str());
    } else {
      SetState(State::kFailed, "connection lost");
    }
  }
}

// ---------------------------------------------------------------------------
void WifiManager::StartApMode() {
  StopApWebServer();
  WiFi.disconnect(true);
  delay(100);

  WiFi.mode(WIFI_AP_STA); // AP + STA for scanning.
  WiFi.softAP(ap_ssid_.c_str(), ap_password_.c_str());
  delay(200);

  Serial.printf("[wifi] AP started: %s / %s — http://%s\n", ap_ssid_.c_str(), ap_password_.c_str(),
                WiFi.softAPIP().toString().c_str());

  SetupApWebServer();
  SetState(State::kApMode, ap_ssid_);
}

// ---------------------------------------------------------------------------
std::string WifiManager::ip() const {
  if (state_ != State::kConnected)
    return "";
  return WiFi.localIP().toString().c_str();
}

int WifiManager::rssi() const {
  if (state_ != State::kConnected)
    return 0;
  return WiFi.RSSI();
}

std::string WifiManager::apIp() const {
  return WiFi.softAPIP().toString().c_str();
}

// ---------------------------------------------------------------------------
std::vector<WifiManager::ScanResult> WifiManager::Scan() {
  std::vector<ScanResult> results;
  int n = WiFi.scanNetworks(false, false, false, 300);
  for (int i = 0; i < n; i++) {
    ScanResult r;
    r.ssid = WiFi.SSID(i).c_str();
    r.rssi = WiFi.RSSI(i);
    r.open = (WiFi.encryptionType(i) == WIFI_AUTH_OPEN);
    if (!r.ssid.empty()) {
      results.push_back(r);
    }
  }
  WiFi.scanDelete();
  // Sort by signal strength.
  std::sort(results.begin(), results.end(),
            [](const ScanResult &a, const ScanResult &b) { return a.rssi > b.rssi; });
  return results;
}

// ---------------------------------------------------------------------------
void WifiManager::LoadCredentials() {
  prefs.begin(kNvsNamespace, true);
  saved_ssid_ = prefs.getString("wifi_ssid", "").c_str();
  saved_pass_ = prefs.getString("wifi_pass", "").c_str();
  backend_url_ = prefs.getString("backend_url", "http://192.168.1.42:8000").c_str();
  prefs.end();
  Serial.printf("[wifi] loaded: ssid='%s' backend='%s'\n", saved_ssid_.c_str(),
                backend_url_.c_str());
}

void WifiManager::SaveCredentials(const std::string &ssid, const std::string &pass,
                                  const std::string &backend) {
  prefs.begin(kNvsNamespace, false);
  prefs.putString("wifi_ssid", ssid.c_str());
  prefs.putString("wifi_pass", pass.c_str());
  prefs.putString("backend_url", backend.c_str());
  prefs.end();
  saved_ssid_ = ssid;
  saved_pass_ = pass;
  backend_url_ = backend;
  Serial.printf("[wifi] saved: ssid='%s' backend='%s'\n", ssid.c_str(), backend.c_str());
}

// ---------------------------------------------------------------------------
bool WifiManager::TryConnect(const std::string &ssid, const std::string &pass,
                             uint32_t timeout_ms) {
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid.c_str(), pass.c_str());

  uint32_t start = millis();
  while (WiFi.status() != WL_CONNECTED) {
    delay(250);
    if (millis() - start > timeout_ms) {
      WiFi.disconnect(true);
      return false;
    }
  }
  return true;
}

// ---------------------------------------------------------------------------
void WifiManager::SetState(State s, const std::string &info) {
  state_ = s;
  if (on_state_change_)
    on_state_change_(s, info);
}

// ---------------------------------------------------------------------------
void WifiManager::SetupApWebServer() {
  g_mgr = this;

  dns_server = new DNSServer();
  web_server = new WebServer(80);

  // Captive portal: redirect all DNS to our IP.
  dns_server->start(53, "*", WiFi.softAPIP());

  // Main page.
  web_server->on("/", HTTP_GET, []() {
    String html = FPSTR(kPortalHtml);
    html.replace("__BACKEND__", g_mgr->backend_url_.c_str());
    web_server->send(200, "text/html", html);
  });

  // Scan endpoint (JSON).
  web_server->on("/scan", HTTP_GET, []() {
    auto nets = g_mgr->Scan();
    String json = "[";
    for (size_t i = 0; i < nets.size(); i++) {
      if (i > 0)
        json += ",";
      json += "{\"ssid\":\"";
      // Escape quotes in SSID.
      String escaped = nets[i].ssid.c_str();
      escaped.replace("\"", "\\\"");
      json += escaped;
      json += "\",\"rssi\":";
      json += String(nets[i].rssi);
      json += ",\"open\":";
      json += nets[i].open ? "true" : "false";
      json += "}";
    }
    json += "]";
    web_server->send(200, "application/json", json);
  });

  // Save credentials.
  web_server->on("/save", HTTP_POST, []() {
    String ssid = web_server->arg("ssid");
    String pass = web_server->arg("pass");
    String backend = web_server->arg("backend");

    if (ssid.isEmpty()) {
      web_server->send(400, "text/plain", "SSID required");
      return;
    }
    if (backend.isEmpty()) {
      backend = g_mgr->backend_url_.c_str();
    }

    g_mgr->SaveCredentials(ssid.c_str(), pass.c_str(), backend.c_str());

    String html = FPSTR(kSavedHtml);
    html.replace("__SSID__", ssid);
    web_server->send(200, "text/html", html);

    // Reboot after a short delay so the response is sent.
    delay(2000);
    ESP.restart();
  });

  // Captive portal detection endpoints.
  web_server->on("/generate_204", HTTP_GET, []() {
    web_server->sendHeader("Location", "http://" + WiFi.softAPIP().toString());
    web_server->send(302, "text/plain", "");
  });
  web_server->on("/hotspot-detect.html", HTTP_GET, []() {
    web_server->sendHeader("Location", "http://" + WiFi.softAPIP().toString());
    web_server->send(302, "text/plain", "");
  });
  web_server->on("/connecttest.txt", HTTP_GET, []() {
    web_server->sendHeader("Location", "http://" + WiFi.softAPIP().toString());
    web_server->send(302, "text/plain", "");
  });

  // Fallback: redirect everything to the portal.
  web_server->onNotFound([]() {
    web_server->sendHeader("Location", "http://" + WiFi.softAPIP().toString());
    web_server->send(302, "text/plain", "");
  });

  web_server->begin();
  server_running_ = true;
  Serial.println("[wifi] captive portal started");
}

// ---------------------------------------------------------------------------
void WifiManager::StopApWebServer() {
  if (web_server) {
    web_server->stop();
    delete web_server;
    web_server = nullptr;
  }
  if (dns_server) {
    dns_server->stop();
    delete dns_server;
    dns_server = nullptr;
  }
  server_running_ = false;
  g_mgr = nullptr;
}
