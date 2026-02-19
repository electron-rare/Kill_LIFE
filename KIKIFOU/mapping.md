# Table de mapping Kill_LIFE

| Dossier         | Rôle/Usage                  | Dépendances principales           |
|-----------------|----------------------------|-----------------------------------|
| agents/         | Orchestration par rôle      | specs/, docs/, gates/, evidence/  |
| ai-agentic-embedded-base/ | Socle méthodo, CI/CD | agents/, bmad/, tools/           |
| bmad/           | Gates, rituels, templates   | agents/, specs/, docs/            |
| compliance/     | Profils, plans, standards   | evidence/, plan.yaml, standards/  |
| docs/           | Guides, FAQ, quickstart     | specs/, compliance/, hardware/    |
| firmware/       | Code, tests, PlatformIO     | specs/, tools/, evidence/         |
| hardware/       | Blocks, rules, KiCad        | tools/hw/, blocks/, rules/        |
| standards/      | Conventions, profils        | specs/constraints.yaml            |
| tools/          | Scripts CI, compliance, hw  | agents/, hardware/, compliance/   |

Ce tableau synthétise les usages et dépendances de chaque dossier pour faciliter l’extension et la maintenance.