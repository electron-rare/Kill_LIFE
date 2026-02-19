# INSTALL — Setup local + GitHub

## 0) Pré-requis

### Outils
- Git
- Python 3.10+ (3.11 recommandé)
- (Firmware) PlatformIO
- (Hardware) KiCad (optionnel)
- (Optionnel) GitHub CLI `gh`

### Accès GitHub
- Droits pour créer labels et secrets (ou admin)
- GitHub Actions activé

---

## 1) Installation locale

### 1.1 Cloner / initialiser

```bash
git clone <repo>
cd <repo>
```

### 1.2 Environnement Python

```bash
python -m venv .venv
source .venv/bin/activate
pip install -U pip
pip install platformio
```

> Si le repo fournit `tools/requirements.txt`, installe-le en priorité.

### 1.3 Build & tests firmware (exemples)

```bash
cd firmware
pio run -e esp32s3_idf
pio test -e native
```

---

## 2) Setup GitHub (obligatoire pour l’automation)

### 2.1 Labels
Crée ces labels (exactement ces noms) :

**Automation**
- `ai:spec` `ai:plan` `ai:tasks` `ai:impl` `ai:qa` `ai:docs` `ai:hold`

**Workflows métiers (recommandé)**
- `type:consulting` `type:systems` `type:design` `type:creative` `type:spike` `type:compliance`

Optionnel : `prio:p0..p3`, `risk:low|med|high`, `scope:hardware|firmware|docs|ux|content`.

### 2.2 Secrets
Selon ta stack agentique, configure :
- `OPENAI_API_KEY`
- `COPILOT_GITHUB_TOKEN`

### 2.3 Branch protection (recommandé)
- Exiger que la CI soit verte avant merge
- Interdire le bypass (ou au minimum sur `.github/workflows/*`)
- 1 review obligatoire

---

## 3) Démarrer avec les templates

- Templates d’issues : `.github/ISSUE_TEMPLATE/`
- Workflows métiers : `docs/workflows/README.md`
- Evidence packs : `docs/evidence/evidence_pack.md`

---

## 4) Vérification “ça marche”

1. Ouvre une issue via un template (ex : “Cabinet — Intake / Cadrage”).
2. Vérifie qu’elle a le label `type:*` + `needs:triage`.
3. Ajoute `ai:spec`.
4. Vérifie qu’une PR est créée et que la CI passe (label enforcement + scope guard).
