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
