# Architecture — Kill_LIFE

_« L'architecture d'un système embarqué est une fugue : chaque module entre à son tour, mais c'est l'ensemble qui fait la musique. »_ — Pierre Schaeffer

## 1. Diagramme bloc matériel

```
                         ┌──────────────────────────────────────────────────┐
                         │           Waveshare ESP32-S3-LCD-1.85           │
                         │                                                  │
    ┌──────────┐  I2S0   │  ┌────────────┐    ┌──────────────────────┐     │
    │ PCM5101  │◄────────┤  │RadioPlayer │    │   VoiceController    │     │
    │ DAC I2S  │  BCK=48 │  │(ESP32-     │    │                      │     │
    │          │  WS=38  │  │ audioI2S)  │◄──►│ BeginPushToTalk()    │     │
    │  🔊 HP   │  DO=47  │  └────────────┘    │ CompletePushToTalk() │     │
    └──────────┘         │                     └──────────┬───────────┘     │
                         │                                │                 │
    ┌──────────┐  I2S1   │  ┌────────────┐               │                 │
    │ICS-43434 │────────►┤  │  I2sMic    │───────────────►│                 │
    │   Mic    │  SCK=15 │  │(new I2S    │  WAV PCM 16kHz│                 │
    │          │  WS=2   │  │ channel    │               │                 │
    │          │  SD=39  │  │ driver)    │               │                 │
    └──────────┘         │  └────────────┘               │                 │
                         │                                │                 │
                         │  ┌────────────┐    ┌──────────▼───────────┐     │
                         │  │   LcdUi    │    │    HttpBackend       │     │
                         │  │ (ST77916   │    │  POST /device/v1/*   │     │
                         │  │  QSPI      │    └──────────┬───────────┘     │
                         │  │  1.85"     │               │                 │
                         │  │  rond)     │               │  HTTP/WiFi      │
                         │  └────────────┘               │                 │
                         │                                │                 │
                         │  ┌────────────┐    ┌──────────┤                 │
    ┌──────────┐  USB-C  │  │WifiManager │    │OtaManager│                 │
    │   5V     │────────►┤  │(STA + AP   │    │(firmware │                 │
    │  Alim    │         │  │ captive    │    │ check +  │                 │
    └──────────┘         │  │ portal)    │    │ flash)   │                 │
                         │  └────────────┘    └──────────┘                 │
                         │                                                  │
                         │  ┌────────────┐       BOOT btn (GPIO 0)         │
                         │  │WifiScanner │       court = push-to-talk      │
                         │  │(scan ponc- │       long 3s = mode AP         │
                         │  │ tuel)      │                                  │
                         │  └────────────┘                                  │
                         └──────────────────────────────────────────────────┘
                                          │
                                          │ WiFi (HTTP)
                                          ▼
                                ┌───────────────────┐
                                │  Backend Mascarade │
                                │                   │
                                │ /device/v1/voice  │
                                │ /device/v1/event  │
                                │ /device/v1/       │
                                │   firmware/check  │
                                └───────────────────┘
```

## 2. Architecture logicielle

### 2.1 Vue d'ensemble des modules

| Module | Fichier | Rôle | Interface abstraite |
|---|---|---|---|
| **WifiManager** | `wifi_manager.h` | Connexion WiFi STA, fallback AP, portail captif, NVS | — |
| **RadioPlayer** | `radio_player.h` | Lecture radio web (Icecast MP3) + TTS via I2S DAC | `MediaController` |
| **VoiceController** | `voice_controller.h` | Orchestration push-to-talk : record → backend → TTS | — |
| **I2sMic** | `i2s_mic.h` | Capture micro I2S (ICS-43434) → buffer WAV PCM 16 kHz | — |
| **LcdUi** | `lcd_ui.h` | Affichage LCD rond 1.85" (ST77916 QSPI) | `UiRenderer` |
| **HttpBackend** | `http_backend.h` | Client HTTP vers Mascarade (events, voice, audio) | `BackendClient` |
| **OtaManager** | `ota_manager.h` | Vérification + flash firmware OTA | — |
| **WifiScanner** | `wifi_scanner.h` | Scan ponctuel des réseaux WiFi, JSON | — |
| **firmware_utils** | `firmware_utils.h` | Fonctions pures C++ (testables natif Unity) | — |

### 2.2 Interfaces abstraites

Le système utilise trois interfaces virtuelles pour le découplage :

```
                  ┌──────────────┐
                  │BackendClient │ (interface)
                  │──────────────│
                  │SendPlayerEvent()
                  │SubmitVoiceSession()
                  │DownloadReplyAudio()
                  └──────┬───────┘
                         │ implémente
                  ┌──────▼───────┐
                  │ HttpBackend  │
                  └──────────────┘

                  ┌───────────────┐
                  │MediaController│ (interface)
                  │───────────────│
                  │Snapshot()
                  │ApplyIntent()
                  │PrepareForReply()
                  │RestoreAfterReply()
                  │PlayReplyAudio()
                  └──────┬────────┘
                         │ implémente
                  ┌──────▼────────┐
                  │  RadioPlayer  │
                  └───────────────┘

                  ┌──────────────┐
                  │  UiRenderer  │ (interface)
                  │──────────────│
                  │Render()
                  └──────┬───────┘
                         │ implémente
                  ┌──────▼───────┐
                  │    LcdUi     │
                  └──────────────┘
```

### 2.3 Interactions principales

**Flux push-to-talk (appui court sur BOOT) :**

```
Utilisateur         main.cpp        VoiceController    I2sMic       HttpBackend     RadioPlayer   LcdUi
    │                   │                │                │              │               │           │
    │ appui court       │                │                │              │               │           │
    ├──────────────────►│                │                │              │               │           │
    │                   │ BeginPushToTalk│                │              │               │           │
    │                   ├───────────────►│                │              │               │           │
    │                   │                │ Render(kRecording)            │               │           │
    │                   │                ├──────────────────────────────────────────────────────────►│
    │                   │ Capture(wav)   │                │              │               │           │
    │                   ├────────────────────────────────►│              │               │           │
    │                   │◄───────────────────────────────►│              │               │           │
    │                   │ CompletePushToTalk(wav)         │              │               │           │
    │                   ├───────────────►│                │              │               │           │
    │                   │                │ PrepareForReply│              │               │           │
    │                   │                ├──────────────────────────────────────────────►│           │
    │                   │                │ SubmitVoiceSession(wav)       │               │           │
    │                   │                ├──────────────────────────────►│               │           │
    │                   │                │◄─────────────────────────────┤               │           │
    │                   │                │ ApplyIntent    │              │               │           │
    │                   │                ├──────────────────────────────────────────────►│           │
    │                   │                │ DownloadReplyAudio            │               │           │
    │                   │                ├──────────────────────────────►│               │           │
    │                   │                │ PlayReplyAudio │              │               │           │
    │                   │                ├──────────────────────────────────────────────►│           │
    │                   │                │ RestoreAfterReply             │               │           │
    │                   │                ├──────────────────────────────────────────────►│           │
    │                   │                │ Render(kIdle)  │              │               │           │
    │                   │                ├──────────────────────────────────────────────────────────►│
```

**Flux de démarrage (setup + startApp) :**

```
setup()
  ├── LCD.Begin()                      // écran de démarrage
  ├── WifiManager.Begin()              // charge NVS, tente connexion STA
  │     ├── [succès] → callback → startApp()
  │     └── [échec]  → AP mode + portail captif
  │
startApp()  [appelé une fois WiFi connecté]
  ├── I2sMic.Begin(16kHz)
  ├── RadioPlayer.Begin(I2S pins)
  ├── RadioPlayer.SetStations(FIP, Nova, ...)
  ├── HttpBackend = new(backendUrl)
  ├── VoiceController = new(backend, radio, lcd)
  ├── OtaManager.CheckAndUpdate()      // flash + reboot si mise à jour
  ├── WifiScanner.Scan(4000)           // envoi wifi_scan_complete
  ├── VoiceController.Boot()           // événement boot au backend
  └── RadioPlayer.PlayStation(0)       // lance la première station
```

### 2.4 Boucle principale (loop)

```
loop()  [~1ms par itération]
  ├── WifiManager.Loop()               // serveur AP si actif
  ├── RadioPlayer.Loop()               // décodeur audio (doit tourner souvent)
  ├── OTA check périodique             // toutes les 4h, si idle et pas de lecture
  └── Gestion bouton BOOT
        ├── appui court → push-to-talk (record + voice session)
        └── appui long 3s → force mode AP (stop radio)
```

### 2.5 Structures de données clés

- **`MediaSnapshot`** : état courant du lecteur (mode, station, track, volume, WiFi, batterie)
- **`VoiceIntent`** : intention parsée par le backend (type, target, value, spoken_confirmation)
- **`VoiceSessionResponse`** : réponse complète d'une session vocale (transcript, intent, audio TTS)
- **`OtaCheckResult`** : résultat de vérification OTA (status, version, URL, erreur)
- **`WifiNetwork`** : réseau scanné (ssid, rssi, open, channel)

## 3. Décisions d'architecture (ADR)

### ADR-001 : Framework Arduino (vs ESP-IDF natif)

**Contexte :** L'ESP32-S3 peut être programmé en ESP-IDF pur (FreeRTOS + API C) ou via le framework Arduino pour ESP32.

**Décision :** Utiliser Arduino comme framework PlatformIO (`framework = arduino`).

**Justification :**
- Écosystème de bibliothèques riche : ESP32-audioI2S, ESP32_Display_Panel, WiFi.h, HTTPClient.
- Courbe d'apprentissage réduite (setup/loop, Serial, API familière).
- Compatibilité directe avec les exemples Waveshare.
- Les API ESP-IDF restent accessibles depuis Arduino (driver I2S, NVS, OTA).

**Conséquences :**
- Boucle single-thread `loop()` (pas de multitâche FreeRTOS explicite par défaut).
- Abstraction WiFi via `WiFi.h` plutôt que `esp_wifi`.
- Dépendance à la couche Arduino-ESP32 (mises à jour potentiellement en retard sur ESP-IDF).

### ADR-002 : ESP32-audioI2S pour la radio (vs I2S brut)

**Contexte :** La lecture de flux MP3 Icecast nécessite un décodeur logiciel et une gestion de buffer réseau.

**Décision :** Utiliser la bibliothèque [ESP32-audioI2S](https://github.com/schreibfaul1/ESP32-audioI2S) (classe `Audio`) pour la lecture radio et TTS.

**Justification :**
- Décodage MP3/AAC/WAV intégré, optimisé pour ESP32.
- Gestion transparente des flux HTTP Icecast (reconnexion, metadata).
- Callbacks (`audio_info`, `audio_showstreamtitle`) pour l'UI.
- Support natif de la lecture depuis buffer mémoire (TTS reply audio).

**Conséquences :**
- La bibliothèque prend le contrôle du périphérique I2S0 (sortie DAC).
- Nécessite `Loop()` appelé fréquemment depuis `loop()` pour alimenter le décodeur.
- Conflit potentiel si un autre module utilise le même périphérique I2S → voir ADR-003.

### ADR-003 : Nouvelle API I2S channel pour le micro (vs legacy)

**Contexte :** Le micro ICS-43434 et le DAC PCM5101 utilisent tous deux I2S mais sur des bus séparés (I2S0 sortie, I2S1 entrée). ESP32-audioI2S utilise le driver I2S legacy. Deux drivers I2S (legacy et nouveau) ne peuvent pas coexister facilement.

**Décision :** Utiliser la nouvelle API `i2s_std` (ESP-IDF 5.x channel driver, `driver/i2s_std.h`) pour le micro, sur I2S1, tandis que ESP32-audioI2S conserve le driver legacy sur I2S0.

**Justification :**
- Séparation complète des périphériques : I2S0 (legacy, `Audio`) et I2S1 (new driver, `I2sMic`).
- L'API channel permet un contrôle fin (enable/disable RX uniquement quand nécessaire).
- Évite le conflit de drivers sur le même bus.
- Compatible ESP-IDF 5.x (inclus dans Arduino-ESP32 v3.x).

**Conséquences :**
- Code micro non portable vers des versions plus anciennes d'Arduino-ESP32.
- Deux APIs I2S différentes cohabitent dans le même firmware.
- `I2sMic` gère le header WAV manuellement (pas de bibliothèque audio côté capture).

### ADR-004 : Portail captif pour le WiFi provisioning (vs BLE)

**Contexte :** L'utilisateur doit configurer le SSID, mot de passe WiFi et URL backend lors de la première utilisation.

**Décision :** Utiliser un point d'accès WiFi (AP mode) avec portail captif HTTP pour la configuration.

**Justification :**
- Aucune application mobile requise — fonctionne depuis n'importe quel navigateur.
- Interface web riche : formulaire, scan des réseaux, feedback visuel.
- Stockage en NVS (clés : `wifi_ssid`, `wifi_pass`, `backend_url`).
- Le bouton BOOT (appui long 3s) permet de forcer le retour en mode AP à tout moment.

**Conséquences :**
- Le WiFi est monopolisé pendant le mode AP (pas de connexion STA simultanée en mode AP pur).
- L'utilisateur doit se connecter manuellement au réseau AP (`KillLife-Setup` / `killlife`).
- Pas de provisioning BLE → simplifie le code (pas de stack BLE, économie de mémoire).

## 4. États d'énergie et cycle de vie

```
              ┌─────────────────────────────────────────────────────────────┐
              │                                                             │
              ▼                                                             │
        ┌──────────┐    credentials OK     ┌───────────────┐               │
        │   BOOT   │─────────────────────►│  WiFi          │               │
        │ (setup)  │                       │  Connecting    │               │
        │          │   pas de credentials  │  (≤12s)        │               │
        └────┬─────┘─────────────┐         └───────┬────────┘               │
             │                   │                 │                         │
             │                   ▼                 │ succès                  │
             │            ┌────────────┐           ▼                         │
             │            │  AP Mode   │    ┌──────────────┐                │
             │            │ (portail   │    │   ACTIVE      │               │
             │            │  captif)   │    │ (radio+voice) │               │
             │            └─────┬──────┘    │               │               │
             │                  │           │ radio.Loop()  │               │
             │                  │ config OK │ voice sessions│               │
             │                  └──────────►│ WiFi scan     │               │
             │                              │ OTA check     │               │
             │                              └───────┬───────┘               │
             │                                      │                       │
             │                                      │ 4h sans activité      │
             │                                      │ voice idle            │
             │                                      │ radio arrêtée         │
             │                                      ▼                       │
             │                              ┌──────────────┐                │
             │                              │    IDLE       │               │
             │                              │ (OTA check   │                │
             │                              │  périodique)  │               │
             │                              └───────┬───────┘               │
             │                                      │                       │
             │                                      │ appui bouton          │
             │                                      │ ou événement          │
             │                                      └───────────────────────┘
             │
             │              long press BOOT (3s) depuis n'importe quel état
             └───────────────────────► AP Mode
```

**Détail des transitions :**

| Depuis | Vers | Déclencheur |
|---|---|---|
| Boot | WiFi Connecting | Credentials NVS trouvées |
| Boot | AP Mode | Pas de credentials ou échec connexion |
| WiFi Connecting | Active | Connexion WiFi réussie → `startApp()` |
| WiFi Connecting | AP Mode | Timeout 12s |
| AP Mode | WiFi Connecting | Soumission formulaire portail captif |
| Active | Active | Appui court BOOT (push-to-talk) |
| Active | Idle | Pas d'activité, radio arrêtée, voice idle |
| Idle | Active | Appui bouton ou événement réseau |
| Tout état | AP Mode | Appui long BOOT (3s) |

**Note sur le sommeil :** Aucun mode deep sleep n'est implémenté dans la version actuelle. Le MCU reste en mode actif en permanence (alimentation USB-C continue).

## 5. Communication avec le backend Mascarade

### 5.1 Endpoints HTTP

| Endpoint | Méthode | Usage |
|---|---|---|
| `/device/v1/event` | POST | Envoi d'événements (boot, wifi_scan_complete, playback_started, ...) |
| `/device/v1/voice` | POST | Soumission session vocale (audio WAV + contexte média) |
| `/device/v1/firmware/check` | POST | Vérification de mise à jour OTA |
| URL dynamique | GET | Téléchargement audio TTS (reply) |
| URL dynamique | GET | Téléchargement binaire firmware OTA |

### 5.2 Payloads JSON

**Événement joueur (`SendPlayerEvent`) :**

```json
{
  "device_id": "esp32-001",
  "event": "wifi_scan_complete",
  "media": {
    "mode": "radio",
    "playing": true,
    "station": "FIP",
    "track": "Titre en cours",
    "volume": 40,
    "wifi_ssid": "MonReseau",
    "wifi_rssi": -62,
    "battery_pct": -1,
    "available_stations": ["FIP", "FIP Rock", "Nova", "..."]
  },
  "detail": "{\"networks\":[...],\"count\":5,\"duration_ms\":2340}"
}
```

**Session vocale (`SubmitVoiceSession`) :**

```
POST /device/v1/voice
Content-Type: multipart ou JSON avec audio encodé

Requête : device_id, MediaSnapshot, wav_data (PCM 16kHz mono)
Réponse :
{
  "ok": true,
  "session_id": "uuid",
  "transcript": "mets FIP Jazz",
  "intent": {
    "type": "select_station",
    "target": "FIP Jazz",
    "value": "",
    "spoken_confirmation": "Je mets FIP Jazz",
    "resume_media_after_tts": true
  },
  "reply_text": "Je mets FIP Jazz",
  "reply_audio_url": "/device/v1/audio/uuid.wav",
  "player_action": "duck",
  "provider": "openai"
}
```

**Vérification OTA (`firmware/check`) :**

```json
// Requête
{"version": "1.0.0", "device_id": "esp32-001"}

// Réponse (mise à jour disponible)
{"latest": "1.0.1", "url": "http://backend/firmware/1.0.1.bin", "notes": "fix audio"}

// Réponse (à jour)
{"latest": "1.0.0"}
```

### 5.3 Protocole OTA

1. Le device envoie `POST /device/v1/firmware/check` avec sa version courante.
2. Le backend compare et retourne la version latest + URL du binaire si nécessaire.
3. `OtaManager` compare les versions via `FwCompareVersions()` (semver).
4. Si mise à jour disponible : téléchargement HTTP du binaire → flash via `esp_ota_ops`.
5. Si flash OK → `ESP.restart()` immédiat.
6. Vérification initiale au boot + périodique toutes les 4 heures (uniquement si idle et radio arrêtée).

### 5.4 Types d'intentions vocales

| `intent.type` | Description | Exemple |
|---|---|---|
| `play` | Lancer la lecture | "joue de la musique" |
| `stop` | Arrêter la lecture | "stop" |
| `select_station` | Changer de station | "mets FIP Jazz" |
| `next` | Station suivante | "suivant" |
| `previous` | Station précédente | "précédent" |
| `volume` | Changer le volume | "monte le son" |
| `switch_mode` | Changer de mode (radio/mp3) | "passe en radio" |
| `none` | Pas d'intention reconnue | — |

## 6. Détails matériels

### 6.1 Carte : Waveshare ESP32-S3-LCD-1.85

- **MCU :** ESP32-S3 (dual-core Xtensa LX7, 240 MHz)
- **Écran :** LCD rond 1.85" ST77916 (QSPI)
- **Micro :** ICS-43434 (I2S MEMS)
- **DAC :** PCM5101 (I2S, sortie audio analogique)
- **Alimentation :** USB-C 5V
- **Bouton :** BOOT (GPIO 0, pull-up interne)
- **WiFi :** 802.11 b/g/n 2.4 GHz (intégré ESP32-S3)

### 6.2 Assignation des broches I2S

| Signal | GPIO | Périphérique |
|---|---|---|
| I2S0 BCK (sortie) | 48 | PCM5101 DAC |
| I2S0 WS (sortie) | 38 | PCM5101 DAC |
| I2S0 DOUT (sortie) | 47 | PCM5101 DAC |
| I2S1 SCK (entrée) | 15 | ICS-43434 Mic |
| I2S1 WS (entrée) | 2 | ICS-43434 Mic |
| I2S1 SD (entrée) | 39 | ICS-43434 Mic |

### 6.3 Stations radio par défaut

| Station | URL Icecast |
|---|---|
| FIP | `icecast.radiofrance.fr/fip-midfi.mp3` |
| FIP Rock | `icecast.radiofrance.fr/fiprock-midfi.mp3` |
| FIP Jazz | `icecast.radiofrance.fr/fipjazz-midfi.mp3` |
| FIP Electro | `icecast.radiofrance.fr/fipelectro-midfi.mp3` |
| FIP Monde | `icecast.radiofrance.fr/fipworld-midfi.mp3` |
| Nova | `novazz.ice.infomaniak.ch/novazz-128.mp3` |
| France Inter | `icecast.radiofrance.fr/franceinter-midfi.mp3` |
| France Culture | `icecast.radiofrance.fr/franceculture-midfi.mp3` |

## 7. Fonctions pures et testabilité

Le fichier `firmware_utils.h` isole les fonctions pures C++ (sans dépendance Arduino) pour permettre les tests natifs via Unity :

| Fonction | Rôle |
|---|---|
| `FwIdleSummary()` | Résumé texte de l'état média pour l'UI |
| `FwShouldPublishPlaybackStarted()` | Décide si un événement playback_started doit être émis |
| `FwCompareVersions()` | Comparaison semver (MAJOR.MINOR.PATCH) |
| `FwIsValidWavHeader()` | Validation magic RIFF/WAVE |
| `FwIsValidBackendUrl()` | Validation http:// ou https:// |
| `FwRssiQuality()` | Conversion RSSI dBm → qualité 0–100 |
| `FwWifiToJson()` | Sérialisation réseaux WiFi → JSON |
| `FwNetworkBetterSignal()` | Comparateur tri RSSI décroissant |

## 8. Risques et mitigations

| # | Risque | Impact | Probabilité | Mitigation |
|---|---|---|---|---|
| R1 | Conflit drivers I2S (micro vs radio) | Bloquant | Moyenne | ADR-003 : I2S0 legacy (Audio) + I2S1 new channel driver (Mic) sur bus séparés |
| R2 | Déconnexion WiFi pendant session vocale | Perte de la commande | Haute | Timeout HTTP, retry, feedback LCD (état erreur) |
| R3 | OTA flash corrompu | Device briqué | Faible | Partition OTA A/B (rollback automatique ESP-IDF), vérification checksum |
| R4 | Scan WiFi bloquant > 5s | Gel de l'UI et du décodeur audio | Moyenne | Timeout explicite 4s, scan uniquement au boot (pas périodique) |
| R5 | Mémoire insuffisante (PSRAM) | Crash pendant capture audio + décodage | Moyenne | Capture limitée à 8s (16 kHz mono = ~256 Ko), radio stoppée pendant TTS |
| R6 | Backend Mascarade indisponible | Pas de voix, pas d'OTA | Moyenne | Radio continue de fonctionner en autonome, OTA retry toutes les 4h |
| R7 | Portail captif non détecté par l'OS | Utilisateur ne trouve pas la config | Moyenne | Affichage IP + credentials sur l'écran LCD, documentation utilisateur |
| R8 | Boucle `loop()` trop lente | Artefacts audio (underrun) | Haute | `RadioPlayer.Loop()` appelé à chaque itération, `delay(1)` minimal, pas de blocage dans la boucle principale |
| R9 | SSID avec caractères spéciaux | JSON malformé | Faible | Échappement `\"` et `\\` dans `FwWifiToJson()`, validation UTF-8 |
| R10 | Appui long accidentel | Passage inattendu en mode AP | Faible | Seuil de 3 secondes, feedback LCD immédiat |

## 9. Pipeline CI/CD

```
.github/workflows/ci.yml
  ├─ python-stable      — 26 tests Python (validate_specs, compliance, outils)
  │                       tools/test_python.sh --suite stable
  ├─ firmware-native    — pio test -e native (Unity, 39 tests, < 15 min)
  ├─ firmware-build     — pio run -e esp32s3_waveshare → artifact firmware.bin
  │                       (nécessite firmware-native passant)
  └─ firmware-sim       — [PENDING] Wokwi CLI simulation ESP32-S3 complète

Outils locaux:
  tools/mcp_runtime_status.py  — smoke tests 11 serveurs MCP (ready/degraded/failed)
  tools/validate_specs.py      — 15 specs, 38 MUST, 12 SHOULD
  compliance/validate.py       — 5 standards (prototype profile)
  tools/auto_check_ci_cd.py    — vérification artefacts CI
```

### 9.1 Environnements PlatformIO

| Env | Board | Usage |
|---|---|---|
| `native` | PC Linux | Tests Unity (logique pure, firmware_utils) |
| `esp32s3_waveshare` | ESP32-S3 | Build firmware complet, flash hardware |
| `esp32s3_qemu` | QEMU ESP32-S3 | [PENDING] Simulation locale |

---

## 10. Stratégie de simulation

| Niveau | Outil | Couverture | État |
|---|---|---|---|
| 1 — Host tests | PlatformIO `[env:native]` | Logique pure, state machines, parsing | ✅ 39/39 |
| 2 — Full sim CI | Wokwi CLI + GitHub Action | Firmware complet ESP32-S3, WiFi, LCD, I2S partiel | 🔲 PENDING |
| 3 — Local QEMU | Espressif QEMU (GPL v2) | Boot, réseau Ethernet émulé, LCD, OTA, crypto | 🔲 PENDING |

**Renode** : support CPU Xtensa LX7 OK, aucun périphérique SoC ESP32-S3 — non retenu.

### 10.1 Scénarios Wokwi prévus

1. `boot_connect` — démarrage → WiFi mock → `[main] ready`
2. `ota_uptodate` — OTA check → version identique → `[OTA] up to date`
3. `wifi_scan` — scan boot → JSON `"count":` présent sur Serial
4. `push_to_talk` — bouton GPIO0 (court) → `[main] recording...` → session backend

### 10.2 Fichiers simulation

```
tools/sim/
├── run_qemu.sh          — wrapper QEMU ESP32-S3 (boot ELF, serial output)
├── qemu_scenarios.py    — scénarios QEMU avec assertions
└── README.md

firmware/
├── wokwi.toml           — config Wokwi CLI (ELF path, timeout)
└── diagram.json         — board ESP32-S3, bouton, serial monitor
```

---

## 11. Stack IA / MCP / RAG

```
Claude Code (kxkm-ai)
    │
    ├─ MCP servers (10 actifs)
    │   ├─ ngspice          — simulation SPICE batch (ngspice-42)
    │   ├─ platformio       — build/test firmware ESP32-S3 (PIO 6.1.19)
    │   ├─ apify            — ingest docs Espressif/KiCad/PlatformIO
    │   ├─ kicad            — ERC, BOM, schops.py
    │   ├─ freecad          — modèles 3D (tâche F-101)
    │   ├─ openscad         — modèles paramétriques (tâche O-101)
    │   ├─ nexar-api        — BOM pricing/availability (tâche K-014)
    │   ├─ knowledge-base   — requêtes RAG
    │   ├─ github-dispatch  — déclenchement CI/CD
    │   └─ validate-specs   — validation spécifications
    │
    └─ RAG Pipeline (mascarade-api :8100)
        ├─ nomic-embed-text  — embeddings 768d (via Ollama)
        ├─ Qdrant            — 6 collections vectorielles:
        │   ├─ kb-firmware   — code Kill_LIFE (192 chunks)
        │   ├─ kb-espressif  — docs Espressif (146 chunks)
        │   ├─ kb-kicad      — schémas + docs KiCad
        │   ├─ kb-spice      — netlists SPICE (11 fichiers)
        │   ├─ kb-platformio — docs PlatformIO
        │   └─ kb-general    — divers
        ├─ qwen3:4b reranker — reranking cross-encoder
        └─ devstral (RTX 4090) — LLM génération (~5s warm)

Agents RAG:
  FirmwareAgent    — contexte kb-firmware + kb-espressif, 5 méthodes
  OpenSeekerAgent  — fan-out multi-collection, cross-domain, dataset generation

Endpoint API agents:
  POST /v1/agents/{name}/run          — run avec enrichissement RAG automatique
  POST /v1/agents/openseeker/search   — recherche multi-hop
```

---

## 12. Hardware — KiCad 10

### 12.1 Schéma principal

```
hardware/esp32_minimal/
├── gen_kicad10.py          — générateur Python (KiCad 10 S-expression)
├── esp32_minimal.kicad_sch — schéma ESP32-S3 minimal (ERC: 0 erreurs, 0 warnings)
├── erc_report.txt
└── Composants: J1 USB-C, FB1 Ferrite, U1 AMS1117-3.3, U2 ESP32-S3, C1-C6

BOM (10 composants):
  C1-C5: 100nF 0603, C3-C4: 10µF 0805, C6: 4.7µF 0805
  FB1: 600Ω@100MHz 0603, J1: USB-C PowerOnly HRO TYPE-C-31
  U1: AMS1117-3.3 SOT-223, U2: ESP32-S3-WROOM-1-N16R8
```

### 12.2 Design blocks réutilisables

| Block | Générateur | Composants | Interface |
|---|---|---|---|
| `power_usbc_ldo` | `gen_power_usbc_ldo.py` | USB-C + AMS1117-3.3 | +5V, +3V3, GND |
| `uart_header` | `gen_uart_header.py` | Conn 4 pins | GND, +3V3, UART_TX, UART_RX |
| `i2s_dac` | `gen_i2s_dac.py` | Conn 6 pins | GND, +3V3, I2S_BCK/WS/DOUT/DIN |
| `spi_header` | `gen_spi_header.py` | Conn 6 pins | GND, +3V3, SPI_SCK/MOSI/MISO/CS |

Bibliothèque partagée: `hardware/lib/kicad_gen.py` — `pin_screen()`, `lib_sym_entry()`, helpers.

### 12.3 Règles ERC KiCad 10

- ADR-007 : Net label `+3V3` sur pin `power_out` LDO (jamais `power:+3V3` → ERC `pin_to_pin`)
- ADR-008 : Symboles `extends` aplatis au moment de la génération (AMS1117-3.3 ← AP1117-ADJ)
- Toutes les coordonnées : multiples de 1.27mm (grille KiCad)
- Marqueurs `no_connect` aux coordonnées exactes `pin_screen()`
