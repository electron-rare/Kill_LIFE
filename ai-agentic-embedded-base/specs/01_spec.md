# Easter Egg musique concrète

_« La spec vibre lentement, comme une onde analogique dans le silence du hardware. »_ — Éliane Radigue
# Spec

## Objectifs
- O1 Scanner les réseaux WiFi visibles depuis l’ESP32-S3 en ≤ 5s.
- O2 Sérialiser les résultats en JSON et les envoyer au backend Mascarade.
- O3 Exposer une qualité de signal 0–100 calculable en pur C++ (testable natif).

## Non-objectifs
- N1 Sélection automatique du réseau (c’est le rôle du portail captif).
- N2 Scan continu en arrière-plan (bloquant, déclenché à la demande).
- N3 Support WPA-Enterprise ou réseaux cachés.

## User stories
- US1: En tant qu’utilisateur, je veux voir la liste des réseaux WiFi disponibles sur le Serial monitor afin de diagnostiquer la connectivité.
- US2: En tant que backend Mascarade, je veux recevoir l’événement `wifi_scan_complete` avec le JSON des réseaux afin d’alerter l’utilisateur si le signal est faible.

## Exigences fonctionnelles
- F1 `WifiScanner::Scan(timeout_ms)` retourne `std::vector<Network>` triés par RSSI décroissant.
- F2 `WifiScanner::ToJson(networks, duration_ms)` produit un JSON valide UTF-8.
- F3 `WifiScanner::RssiQuality(rssi)` mappe [-100, -50] → [0, 100] (clampé, pur C++).
- F4 Le résultat JSON est imprimé sur Serial et envoyé via `SendPlayerEvent`.
- F5 En cas de timeout (0 réseaux trouvés), le JSON retourne `{"networks": [], "count": 0}`.

## Exigences non-fonctionnelles
- Perf: durée totale `Scan()` ≤ 5 000 ms sur hardware réel.
- Observabilité: log `[wifi_scan]` sur Serial avec count et durée.
- Conso: scan ponctuel uniquement (pas de scan périodique automatique).

## Critères d’acceptation (AC)
- AC1 `Scan()` retourne ≥ 1 réseau dans un environnement avec WiFi disponible, en ≤ 5s.
- AC2 Le JSON produit est parseable par `ArduinoJson` et par Python `json.loads()`.
- AC3 Les champs obligatoires sont présents : `ssid`, `rssi`, `open`, `channel`, `quality`.
- AC4 `RssiQuality(-50) == 100`, `RssiQuality(-100) == 0`, `RssiQuality(-75) == 50`.
- AC5 Les réseaux sont triés par RSSI décroissant (meilleur signal en premier).
- AC6 28 + N tests Unity natifs verts (N ≥ 8 nouveaux tests WiFi scanner).

## Interfaces (contrats)
```json
{
  "networks": [
    {"ssid": "MyNetwork", "rssi": -62, "open": false, "channel": 6, "quality": 76}
  ],
  "count": 1,
  "duration_ms": 2340
}
```
Événement backend : `SendPlayerEvent(device_id, "wifi_scan_complete", snapshot, json_string)`.
