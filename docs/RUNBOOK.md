# RUNBOOK — Opérer les workflows agentiques

## 0) Cartes de lecture rapides

- Carte fonctionnelle canonique : `docs/KILL_LIFE_FEATURE_MAP_2026-03-11.md`
- Séquence locale : `docs/KILL_LIFE_WORKFLOW_LOCAL_SEQUENCE_2026-03-11.md`
- Séquence GitHub : `docs/KILL_LIFE_WORKFLOW_GITHUB_SEQUENCE_2026-03-11.md`
- Monitoring VPS : `docs/INFRA_VPS_RUNBOOK_2026.md`
- Runbook multi-machine : `docs/MULTI_MACHINE_RUNBOOK.md`
- Audit UI/UX YiACAD : `docs/YIACAD_APPLE_UI_UX_AUDIT_2026-03-20.md`
- Points d’insertion natifs YiACAD : `docs/YIACAD_NATIVE_UI_INSERTION_POINTS_2026-03-20.md`

Choix opératoire rapide :
- validation et exécution locale avant CI distante : séquence `workflow local`
- dispatch allowlisté, checks GitHub et evidence pack CI : séquence `workflow github`
- dépendances cross-host, ordre de reprise Photon/Tower et registre machine : `runbook multi-machine`

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
Les scripts d’automatisation sont dans `tools/` :
- `build_firmware.py` : build par cible
- `test_firmware.py` : tests par cible
- `collect_evidence.py` : génération evidence pack

Les wrappers PlatformIO utilisent `pio` en natif si disponible, sinon basculent automatiquement sur la stack conteneurisée `tools/hw/cad_stack.sh pio`.
Override possible :
- `KILL_LIFE_PIO_MODE=native`
- `KILL_LIFE_PIO_MODE=container`

Pour une voie repo-locale sans `pio` systeme mais avec venv dedie :
```bash
bash tools/bootstrap_python_env.sh --with-platformio
KILL_LIFE_PIO_MODE=native ./.venv/bin/python tools/build_firmware.py esp
```

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

Lecture utile :
- preuves locales, restores et runs cockpit : `docs/KILL_LIFE_WORKFLOW_LOCAL_SEQUENCE_2026-03-11.md`
- preuves CI, artifacts GitHub et release signing : `docs/KILL_LIFE_WORKFLOW_GITHUB_SEQUENCE_2026-03-11.md`

## 5) Workflows métiers
Voir `docs/workflows/README.md`.

## 6) YiACAD UI/UX lane

Surfaces opératoires recommandées:

```bash
bash tools/cockpit/yiacad_uiux_tui.sh --action status
bash tools/cockpit/yiacad_uiux_tui.sh --action agent-matrix
bash tools/cockpit/yiacad_uiux_tui.sh --action insertion-points
bash tools/cockpit/yiacad_uiux_tui.sh --action logs-summary
```

Points d’appui:

- `docs/CAD_AI_NATIVE_GUI_RUNBOOK_2026-03-20.md`
- `docs/CAD_AI_NATIVE_HOOKS_2026-03-20.md`
- `docs/YIACAD_APPLE_UI_UX_FEATURE_MAP_2026-03-20.md`
- `docs/plans/20_plan_refonte_ui_ux_yiacad_apple_native.md`

## 2026-03-21 - Canonical operator entry
- Entree publique recommandee: `bash tools/cockpit/yiacad_operator_index.sh --action status`.
- Surface de preuves: `bash tools/cockpit/yiacad_proofs_tui.sh --action status`.
- Surface de logs: `bash tools/cockpit/yiacad_logs_tui.sh --action status`.
- Les routes directes historiques restent compatibles, mais ne sont plus l'entree publique recommandee.

## 2026-03-29 - Infra VPS lane
- Inventaire et healthcheck: `bash tools/cockpit/infra_vps_healthcheck.sh --json`.
- Surface runtime gateway: `bash tools/cockpit/runtime_ai_gateway.sh --action status --json`.
- Guide operateur complet: `docs/INFRA_VPS_RUNBOOK_2026.md`.
