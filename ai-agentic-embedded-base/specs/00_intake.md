# Easter Egg musique expérimentale

_« L’intake du projet s’écoute comme une partition acousmatique : chaque idée module le silence. »_ — François Bayle
# Intake

## Problème
- Le projet Kill_LIFE a déjà une architecture agentique et un socle MCP, mais les artefacts canoniques sont en partie désynchronisés.
- Le référentiel doit passer en mode refonte complète sans perdre la traction opérationnelle ni casser les chaînes CI.
- Les lots d’optimisation existent, mais les priorités et responsabilités ne sont pas suffisamment structurées pour un cycle autonome.

## Utilisateurs / contexte
- Équipe produit embarquée (PM, firmware, hardware, QA, doc) qui pilote des lots hebdomadaires.
- Opérateurs locaux (`clems@192.168.0.120`, `root@192.168.0.119`, `kxkm@kxkm-ai`, `cils@100.126.225.111`) qui exécutent la refonte.
- Mainteneurs souhaitant une piste claire entre specs, plans, automatisation et preuve.

## Hypothèses
- La spec-driven chain (`00_intake -> 01_spec -> 02_arch -> 03_plan -> 04_tasks`) reste la source de vérité.
- Les labels `ai:*` et le scope guard restent les garde-fous principaux.
- Les intégrations IA (ZeroClaw, MCP, LangGraph, AutoGen) restent optionnelles quand non sécurisées par les gates.
- Les données de télémetrie/logs doivent être exploitables, lisibles, puis nettoyables.

## Risques
- Perte de cohérence entre README/plans/specs.
- Dérive de portée AI (automatisation trop invasive hors garde-fous).
- Faux positifs dans les détections de lot auto.
- Chute de conformité si les evidences et gates sont sautées.

## Définition du “done”
- `docs/REFACTOR_MANIFEST_2026-03-20.md` et `docs/WEB_RESEARCH_OPEN_SOURCE_2026-03-20.md` mis à jour.
- Plans/tâches ré-assignés (`docs/plans/12`, `docs/plans/18`, `specs/04_tasks.md`) avec priorités.
- Nouveau script TUI opérationnel : `tools/cockpit/refonte_tui.sh`.
- Diagrammes et cartes mises à jour dans `docs/KILL_LIFE_FEATURE_MAP_2026-03-11.md`, `docs/AGENTIC_LANDSCAPE.md`, workflows.
- Logs de lot lus, analysés et purgeables avec commande dédiée.
