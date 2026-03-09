# Cockpit

Entrée unique pour piloter le repo en local.
- `menu` : menu simple
- `gate_s0` : check “spec ready”
- `fw` : build/test firmware
- `hw` : gates hardware (ERC/netlist/BOM)
- `lots-status` : état des lots locaux utiles + prochaine vraie question
- `lots-run` : enchaîne les lots auto-fix, validations, puis met à jour le suivi

Note:
- `lots-run` peut sortir avec le code `3` quand la chaîne est saine mais qu'un vrai choix opérateur reste nécessaire.

Tous les outputs → `artifacts/`.
