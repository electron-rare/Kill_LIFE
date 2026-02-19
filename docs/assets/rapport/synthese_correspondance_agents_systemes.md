# Correspondance agents & systèmes – Kill_LIFE

## Agents humains
- Définis dans agents/, ai-agentic-embedded-base/agents/, .github/agents/
- Rôles : Architect, Doc, Firmware, HW Schematic, PM, QA
- Artefacts : schémas, plans, tests, documentation, evidence packs

## Agents AI & systèmes
- **Copilot** : audit, documentation, validation automatisée (instructions dans .github/copilot-instructions.md, prompts dans tools/mistral/prompts/)
- **Codex** : génération de code, automatisation (tools/ai/compose_codex_prompt.py, prompts codex)
- **OpenAI** : génération de texte, evidence packs, validation specs (prompts QA, Doc, Architect)
- **Mistral** : prompts firmware, QA, documentation, orchestration, evidence packs (requirements-mistral.txt, tools/mistral/prompts/)

## Correspondance fichiers/dossiers
- agents/, ai-agentic-embedded-base/agents/, .github/agents/ : rôles humains
- tools/mistral/prompts/, tools/ai/, .github/prompts/ : prompts/scripts pour agents AI
- docs/assets/rapport/, SYNTHESE_AGENTIQUE.md : synthèse, rapport, diagramme, audit
- firmware/, hardware/, compliance/, specs/ : artefacts produits/consommés

## Interactions
- Agents humains : orchestration, validation, documentation
- Agents AI : automatisation, génération, evidence packs
- Systèmes intégrés via prompts/scripts pour traçabilité, conformité, automatisation

---

> Synthèse générée automatiquement (GPT-4.1)
