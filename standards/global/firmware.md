# Firmware standards

- PlatformIO + Unity
- `src/` minimal, extraire en `lib/` les modules partagés
- Interfaces drivers derrière des wrappers (pas d'accès direct partout)
- Watchdog/timeout sur IO bloquants
