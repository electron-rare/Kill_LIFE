# Workflows professionnels (opérationnels)

Ces workflows sont conçus pour ressembler aux pratiques **cabinet de conseil**, **bureau d’études**, **design produit**, **studio créatif**, **R&D**, **industrialisation / compliance** — tout en restant compatibles avec le pipeline agentique du repo :

- labels `type:*` pour classer l’intention métier,
- labels `ai:*` pour déclencher l’automatisation (Issue → PR),
- **scope guard** et **label enforcement** pour sécuriser les actions,
- **evidence pack** pour tracer les décisions et résultats.

## Menu

- 🧑‍💼 [Cabinet de conseil](consulting.md)
- 🏗 [Bureau d’études / Ingénierie système](systems_engineering.md)
- 🎨 [Design produit / UX](design.md)
- 🎭 [Créatif / narration / contenu](creative.md)
- 🧪 [R&D / spikes time-boxés](rnd_spikes.md)
- 🛡 [Compliance / QA / Release](compliance_release.md)

## Règle simple (anti-chaos)

1) **Crée une issue** avec un template (`.github/ISSUE_TEMPLATE/`).
2) **Triage** : ajoute `prio:*`, `risk:*`, `scope:*`, et garde seulement un `type:*`.
3) **Déclenche l’automatisation** en ajoutant le bon label `ai:*` :
   - `ai:spec` → formaliser exigences (RFC2119 + critères d’acceptation)
   - `ai:plan` → architecture + options + ADR
   - `ai:tasks` → backlog exécutable
   - `ai:impl` → impl + tests minimaux
   - `ai:qa` → durcissement tests/edge
   - `ai:docs` → docs + runbooks

⚠️ Si tu suspects une injection / comportement bizarre : ajoute `ai:hold`.

## Evidence pack

Voir : `docs/evidence/evidence_pack.md`.

## Séquences opératoires canoniques

- Local / cockpit / restore : `docs/KILL_LIFE_WORKFLOW_LOCAL_SEQUENCE_2026-03-11.md`
- GitHub / dispatch / CI / artifacts : `docs/KILL_LIFE_WORKFLOW_GITHUB_SEQUENCE_2026-03-11.md`

Raccourci d'usage :
- si le besoin est de valider un workflow, un runtime local ou un export avant CI, partir de la séquence `local`
- si le besoin est de suivre un dispatch allowlisté, un check GitHub ou un evidence pack CI, partir de la séquence `github`

<iframe src="https://github.com/sponsors/electron-rare/card" title="Sponsor electron-rare" height="225" width="600" style="border: 0;"></iframe>
