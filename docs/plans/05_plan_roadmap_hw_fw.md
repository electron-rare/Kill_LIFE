# 5) Plan de roadmap hardware/firmware

## Objectif
Définir une roadmap synchronisée entre **hardware** et **firmware** : analyse → design → proto → tests → validation → release.

## Labels recommandés
- `type:systems` + `ai:plan`

## Étapes (HW)
1. **Analyse** : contraintes mécaniques/électriques, BOM cible, profils compliance
2. **Schéma** (KiCad) : ERC, choix composants, interfaces
3. **PCB** : placement, routage, DRC
4. **BOM & supply** : alternatives, risque de pénurie
5. **Proto V0** : bring‑up électrique, tests de base
6. **Proto V1** : corrections, robustesse, ESD/EMC préliminaire
7. **Pré‑série** : endurance, tolérances, doc fabrication

## Étapes (FW)
1. **Skeleton** : architecture tasks/modules, logs, erreurs, watchdog
2. **Drivers** : GPIO/I2C/SPI/UART, HAL propre
3. **Comms** : protocoles + framing + retry
4. **Tests unitaires** : `native`
5. **Intégration** : test sur cible, HIL si possible
6. **Profil conso** : deep sleep, wake sources, budget énergétique
7. **RC** : freeze, bugfix only, release

## Points de synchronisation (gates “co-design”)
- Interface freeze (pinout, protocoles)
- Bring‑up checklist (V0)
- Validation conso (FW + HW)
- Test matrix release

## Evidence pack
- Exports KiCad (PDF, renders)
- BOM export + versions
- Logs bring‑up
- Mesures (courant, timing)

## Critère de sortie
✅ Roadmap publiée + jalons versionnés + critères “go/no‑go” définis.

## Références
- `docs/HARDWARE_QUICKSTART.md`
- `docs/COMPLIANCE.md`
- `docs/evidence/evidence_pack.md`