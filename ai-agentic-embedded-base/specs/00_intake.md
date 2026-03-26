# Easter Egg musique expérimentale

_« L’intake du projet s’écoute comme une partition acousmatique : chaque idée module le silence. »_ — François Bayle
# Intake

## Problème
L'appareil Kill_LIFE (ESP32-S3 Waveshare LCD 1.85”) doit pouvoir scanner les réseaux WiFi disponibles, exposer les résultats en JSON via Serial et les transmettre au backend Mascarade, afin de permettre le diagnostic réseau, la sélection guidée par voix, et la configuration AP intelligente.

## Utilisateurs / contexte
- **Utilisateur final** : configure le device via le portail captif ; veut voir les réseaux disponibles triés par signal.
- **Backend Mascarade** : reçoit les résultats de scan via `SendPlayerEvent(“wifi_scan_complete”)` pour décider d'une action (suggestion de réseau, alerte de signal faible).
- **Développeur** : valide l'intégration WiFi via Serial monitor et les tests Unity natifs.

## Hypothèses
- Le WiFi est en mode STA ou APSTA pendant le scan.
- `WiFi.scanNetworks()` retourne les résultats en ≤ 4s sur hardware réel.
- Le JSON de sortie est consommable directement par `ArduinoJson` et par le backend Python.

## Risques
- Scan bloquant > 4s sur réseau très encombré → timeout explicite.
- SSID avec caractères UTF-8 ou apostrophes → encodage JSON géré par ArduinoJson.
- Faux négatifs (réseau présent non détecté) → toléré, scan non-exhaustif par nature.

## Définition du “done”
- `WifiScanner::Scan()` retourne les réseaux en ≤ 5s.
- Sortie JSON valide : `{“networks”: [...], “count”: N, “duration_ms”: T}`.
- Tests Unity natifs sur `RssiQuality`, `ToJson`, tri par RSSI — tous verts.
- Build `esp32s3_waveshare` SUCCESS après intégration.
- Événement `wifi_scan_complete` visible dans le log Mascarade.
