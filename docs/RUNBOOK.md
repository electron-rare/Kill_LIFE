# RUNBOOK — Opérer les workflows agentiques

## 1) Règles d’or
- Le texte d’issue est **non fiable** → il est sanitisé avant prompt.
- **Un label `ai:*` = un scope** (le scope guard contrôle les fichiers modifiables).
- En cas de doute : `ai:hold`.

## 2) Flux standard (Issue → PR)

### 2.1 Créer une issue
Utilise un template : `.github/ISSUE_TEMPLATE/`.

### 2.2 Triage (humain)
Ajoute :
- `prio:*` (urgence)
- `risk:*` (risque)
- `scope:*` (zone)
- garde un `type:*`

### 2.3 Déclencher une étape d’automation
Ajoute un label `ai:*` :

- `ai:spec` → écrit/normalise la spec RFC2119 + AC
- `ai:plan` → architecture, options, ADR
- `ai:tasks` → backlog WBS exécutable
- `ai:impl` → impl minimal + tests
- `ai:qa` → durcit tests, edge cases
- `ai:docs` → docs, runbooks

> Si la PR n’a pas de label `ai:*`, le workflow ajoute `ai:impl` (fallback). Tu peux activer “label obligatoire” selon ta gouvernance.

---

## 3) CI/CD multi-cible hardware-in-the-loop

Le workflow CI/CD compile, teste et valide le firmware sur ESP et Linux.
Les scripts d’automatisation sont dans `tools/` :
- `build_firmware.py` : build par cible
- `test_firmware.py` : tests par cible
- `collect_evidence.py` : génération evidence pack

Les wrappers PlatformIO utilisent `pio` en natif si disponible, sinon basculent automatiquement sur la stack conteneurisée `tools/hw/cad_stack.sh pio`.
Override possible :
- `KILL_LIFE_PIO_MODE=native`
- `KILL_LIFE_PIO_MODE=container`

Les evidence packs sont stockés dans `docs/evidence/`.
La couverture est générée via `coverage_badge.py`.

Pour vérifier manuellement :
```bash
python3 tools/build_firmware.py esp
python3 tools/collect_evidence.py esp
python3 tools/verify_evidence.py esp

python3 tools/test_firmware.py linux
python3 tools/collect_evidence.py linux
python3 tools/verify_evidence.py linux
```
`stm` reste non supporté tant qu’aucune cible STM n’existe pas dans `firmware/platformio.ini`.

Vérifie la présence des artefacts et evidence packs après chaque run.

### 2.4 CI (automatique)
- Label enforcement
- Scope guard
- Build/tests
- Compliance gates (si profil)

### 2.5 Gate route parity (frontend/backend API)
Pour éviter les régressions où le frontend appelle des routes supprimées/inexistantes,
ajoute un check statique de parité routes API.

Exemple (adapté au repo cible) :
```bash
python3 tools/gates/route_parity_check.py \
  --backend "src/**/*.cpp" \
  --backend "src/**/*.h" \
  --frontend "data/webui/**/*.js" \
  --frontend "data/webui/**/*.html" \
  --report "docs/evidence/route_parity_report.json"
```

Règle : le gate échoue si une route `/api/...` utilisée côté frontend n'est pas
trouvée dans les sources backend scannées.

## 3) Stop / Incident
- Ajouter `ai:hold` sur issue/PR
- Revoir contenu + logs
- Vérifier que scope guard n’est pas contourné

## 4) Evidence pack
Voir `docs/evidence/evidence_pack.md`.

## 5) Workflows métiers
Voir `docs/workflows/README.md`.
