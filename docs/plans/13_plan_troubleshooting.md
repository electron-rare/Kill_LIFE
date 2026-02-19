# 13) Plan de troubleshooting

## Objectif
Résoudre rapidement les erreurs courantes (build, tests, CI, hardware) avec une démarche standard.

## Approche
1) Identifier le gate qui échoue
2) Lire le log complet
3) Reproduire localement
4) Corriger avec une PR minimale

## Cas fréquents

### PR sans label `ai:*`
- Symptôme : job “PR Label Enforcement” échoue
- Fix : ajouter un label `ai:*` (ou attendre fallback `ai:impl`)

### Scope guard échoue
- Symptôme : fichier hors allowlist
- Fix :
  - changer le label `ai:*` vers celui adapté
  - ou déplacer la modification dans une PR séparée

### Build PlatformIO échoue
- Vérifier versions toolchain
- Lancer :
```bash
cd firmware
pio run -e <env>
```

### Tests `native` échouent
- Lancer :
```bash
cd firmware
pio test -e native -v
```

### Suspicion prompt injection
- Ajouter `ai:hold`
- Ne pas merger
- Revue manuelle + rotation tokens si nécessaire

## Critère de sortie
✅ Root cause documentée + fix minimal + CI verte.

## Références
- `docs/RUNBOOK.md`
- `docs/security/anti_prompt_injection_policy.md`