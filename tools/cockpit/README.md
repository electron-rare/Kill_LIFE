# Cockpit

Entrée unique pour piloter le repo en local.
- `menu` : menu simple
- `gate_s0` : check “spec ready”
- `fw` : build/test firmware
- `hw` : gates hardware (ERC/netlist/BOM)
- `lots-status` : état des lots locaux utiles + prochaine vraie question + resynchronisation de `docs/plans/18_*`
- `lots-run` : enchaîne les lots auto-fix, la lane `autonomous_next_lots`, les validations, puis met à jour le suivi
- `run_next_lots_autonomously.sh` : enchaîne automatiquement tous les lots utiles détectés, un à un, puis stoppe proprement quand la chaîne est vide.
- `bash tools/ai/zeroclaw_integrations_lot.sh verify` : valide en un point les wrappers `ZeroClaw/n8n` et le smoke workflow suivi

Note:
- `lots-run` peut sortir avec le code `3` quand la chaîne est saine mais qu'un vrai choix opérateur reste nécessaire.

Tous les outputs → `artifacts/`.
