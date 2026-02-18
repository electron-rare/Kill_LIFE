# ai-agentic-embedded-base

Repo “de base” qui combine le meilleur de :
- **Spec‑driven development** (Spec Kit) : une spécification comme source de vérité.  
- **Standards injection** (Agent OS) : standards versionnés + profils.  
- **BMAD / BMAD‑METHOD** : agents par rôles + rituels + gates + handoffs.  
- **Agent Zero** : exécution transparente via outils locaux + logs + artifacts.

> Ce dépôt est **orienté embarqué** (firmware + hardware KiCad) mais extensible multi‑target.

## TL;DR
- Écris/itère la spec dans `specs/`
- (optionnel) Génère un squelette de spec depuis `.specify/` : `python tools/ai/specify_init.py --name <feature>`
- Applique les standards dans `standards/`
- Exécute le cockpit : `python tools/cockpit/cockpit.py menu`
- Pour l’automatisation GitHub : label `ai:codex` → Issue → PR

## Structure
- `specs/` : intake → spec → arch → plan → tasks + contraintes
- `standards/` : règles globales + profils (ESP / STM / multi)
- `bmad/` : rôles, rituels, gates, templates de handoff
- `agents/` : prompts agents (PM/Architect/FW/QA/Doc/HW)
- `tools/` : cockpit + outils AI + outils hardware (schops)
- `firmware/` : PlatformIO + Unity (tests)
- `hardware/` : KiCad + blocks + rules
- `.github/` : workflows (CI firmware/hardware/docs + Issue→PR Codex)

## KiCad local + IA
Voir `docs/KICAD_AI_LOCAL.md`.

## Démarrage rapide
```bash
# firmware
cd firmware
python -m pip install -U platformio
pio run -e esp32s3_arduino
pio test -e native

# cockpit
python tools/cockpit/cockpit.py menu
```

## Conventions de sortie
Tous les scripts écrivent sous `artifacts/<domain>/<timestamp>/` (logs + exports + reports).


## V4 — KiCad agentique (bulk + previews + MCP)
- `bash tools/hw/hw_gate.sh hardware/kicad` : exports SVG + ERC/DRC JSON + BOM/netlist
- `python tools/watch/watch_hw.py` : watch mode (re-run gate on save)
- `docs/MCP_SETUP.md` : configuration MCP (kicad-sch-mcp) citeturn0search9

## Compliance (2 options)
- **Prototype interne** : profil `prototype` (pas de CE/RED)
- **Produit UE Wi‑Fi/BLE** : profil `iot_wifi_eu` (RED + cyber + RoHS/REACH/WEEE + ETSI)

Changer de profil :
```bash
python tools/compliance/use_profile.py prototype
python tools/compliance/use_profile.py iot_wifi_eu
python tools/compliance/validate.py
```

Docs : `docs/COMPLIANCE.md`

