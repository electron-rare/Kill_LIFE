# Easter Egg musique concrète

_« La spec vibre lentement, comme une onde analogique dans le silence du hardware. »_ — Éliane Radigue
# Spec

## Objectifs
- O1 — Produire un cadre unifié de refonte pour rendre le projet entièrement traçable entre `specs/`, `plans/`, `tools/` et `evidence`.
- O2 — Structurer l’utilisation de l’IA en overlay optionnel avec garde-fous (labels, scope guard, anti-prompt injection).
- O3 — Mettre en place une boucle TUI docs/automation avec logs lisibles, analyse + purge.
- O4 — Actualiser les cartes fonctionnelles et diagrammes manquants ou incohérents.

## Non-objectifs
- N1 — Remplacer le dépôt ou l’architecture matérielle existante.
- N2 — Ajouter de nouvelles dépendances IA non maîtrisées sans validation de conformité.
- N3 — Changer la stratégie commerciale ou les accès secrets hors scope.

## User stories
- US1: En tant qu’agent PM je veux voir les lots prioritaires et leurs dépendances afin de piloter sans ambiguïté.
- US2: En tant qu’agent Firmware je veux des points d’entrée de lot clairs afin d’appliquer les corrections ciblées sans casser la CI.
- US3: En tant qu’agent QA je veux disposer d’un lot de vérification stable afin de valider preuves et dérive avant intégration.
- US4: En tant qu’agent Doc je veux des cartes Mermaid à jour afin de garder une vision système cohérente.
- US5: En tant qu’opérateur je veux un TUI avec logs pour exécuter, lire et supprimer les traces d’analyse.

## Exigences fonctionnelles
- F1 — Les artefacts de refonte doivent être centralisés dans `docs/REFACTOR_MANIFEST_2026-03-20.md`.
- F2 — Les plans d’agents/sous-agents doivent contenir rôles, compétences, tâches et priorité.
- F3 — Les lots auto et manuels doivent être orchestrés via scripts et scripts de cockpit.
- F4 — Les logs de lot doivent être persistés, listables, analysables et supprimables proprement.
- F5 — Les specs canoniques (`00_intake`, `01_spec`, `02_arch`, `03_plan`, `04_tasks`) doivent rester alignées.

## Exigences non-fonctionnelles
- Perf: temps de boucle lot réduit, commandes de maintenance en quelques secondes quand non bloquantes.
- Sécurité: labels `ai:*` gardés, secrets et accès réseau contrôlés par config existante.
- Observabilité: journalisation de chaque action TUI dans `artifacts/refonte_tui/`.
- Conso: les lots critiques ne doivent pas saturer les environnements locaux ni déclencher d’actions réseau inutiles.

## Critères d’acceptation (AC)
- AC1 — Les fichiers `specs/00 intake -> 04_tasks` et `docs/plans/12`, `docs/plans/18` sont cohérents.
- AC2 — Un opérateur peut exécuter un lot en mode interactif et obtenir un rapport.
- AC3 — Les logs sont localisables, consultables, puis supprimables selon politique.
- AC4 — `docs/KILL_LIFE_FEATURE_MAP_2026-03-11.md` et les workflows sont synchronisés.
- AC5 — Aucune mise à jour non demandée hors scope ne modifie le cadre de conformité.

## Interfaces (contrats)
- Spec contract: `specs/constraints.yaml` + `specs/` canonical sources.
- Tool contract: scripts dans `tools/cockpit`, `tools/doc`, `tools/autonomous_next_lots.py`.
- UI contract: TUI `tools/cockpit/refonte_tui.sh`.
- Docs contract: `docs/plans/*`, `docs/index.md`, `README.md`, `docs/AI_WORKFLOWS.md`.
