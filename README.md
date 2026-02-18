# Kill\_LIFE — AI‑Native Embedded Project Template

Bienvenue dans **Kill\_LIFE**, un modèle de dépôt pensé pour développer des systèmes embarqués à l’ère des agents. L’objectif est simple : offrir une structure prête à l’emploi qui combine spécifications formalisées, automatisation via agents, gestion multi‑cibles (ESP32/STM32/Linux), et pratiques de sécurité adaptées au développement assisté par IA.

## ✨ Inspirations et principes

Ce projet s’inspire de plusieurs initiatives et bonnes pratiques :

- **GitHub Agentic Workflows** : les workflows agentiques de GitHub, qui introduisent une chaîne de sanitisation de l’input (neutralisation des mentions, filtrage des URLs, limitation de taille) et l’utilisation de *safe outputs* pour limiter les privilèges des agents. Ces principes guident notre pipeline d’automatisation【420659683624566†L747-L857】【11582546369719†L160-L168】.
- **Alertes sur l’injection de prompt** : des rapports comme celui d’Aikido Security détaillent comment des contenus d’issues non fiables peuvent détourner un agent et recommandent d’éviter d’injecter du texte non filtré dans les prompts, de restreindre les outils disponibles et de traiter toute sortie de l’agent comme non fiable【885973626346785†L218-L231】.
- **Réduction du rayon d’explosion** : le guide *prompt‑injection‑defenses* rappelle qu’il faut concevoir en assumant que les injections ne seront jamais totalement éliminées. Cela implique de limiter les privilèges, de vérifier et de sanitariser systématiquement les entrées et sorties et de séparer les rôles【408877418785616†L277-L304】.
- **Enforcement des labels PR** : pour forcer les PR à respecter un flux précis, nous nous appuyons sur l’idée de l’action GitHub *enforce‑pr‑labels*, qui permet d’exiger qu’une PR contienne certains labels ou d’en bloquer d’autres【613342446189111†L283-L299】.
- **Licences open source** : le code source est sous licence MIT, les fichiers matériels sous licence **CERN OHL v2** (promouvant la liberté d’utiliser, d’étudier, de modifier et de partager des conceptions matérielles【572981070514051†L86-L91】) et la documentation sous **CC‑BY 4.0**, qui autorise le partage et l’adaptation avec attribution【335439356583797†L59-L75】.

## 🔧 Fonctionnalités clés

- **Développement guidé par la spécification** : écrivez votre spécification (user stories, contraintes, architecture) dans `specs/`. C’est la source de vérité. Des scripts de validation et un schéma garantissent la cohérence.
- **Multi‑agents** : des prompts prédéfinis pour les rôles PM, Architecte, Firmware, QA, Doc et Hardware (BMAD/AgentOS) orchestrent les étapes de la conception et de la mise en œuvre.
- **Automation L3 avec sécurité intégrée** : les workflows GitHub Agentic Workflows (Option A) transforment une issue en Pull Request en appliquant une sanitisation stricte et en créant la PR via un *safe output*. Un fallback sur `ai:impl` est possible si aucune étiquette n’est présente, mais vous pouvez activer l’option label obligatoire pour renforcer la gouvernance.
- **Sanitisation renforcée des issues** : un script Python élimine balises HTML, blocs de code, URLs externes, mentions et commandes potentiellement dangereuses avant que le texte ne soit injecté dans un prompt (voir `tools/ai/sanitize_issue.py`).
- **Contrôle des étiquettes** : un workflow impose qu’une PR contienne au moins un label `ai:*` (`ai:spec`, `ai:plan`, `ai:tasks`, `ai:impl`, `ai:qa`, `ai:docs`). Sans label, la PR est annotée par défaut avec `ai:impl` ou rejetée selon votre politique.
- **Scope guard par label** : chaque label détermine les dossiers modifiables (par exemple, `ai:spec` autorise `specs/` et `docs/` ; `ai:impl` autorise `firmware/`). Si un fichier en dehors de la liste est modifié, le gate échoue.
- **Multi‑cibles et firmware portable** : le dossier `firmware/` contient des environnements PlatformIO pour ESP32 (ESP‑IDF) et STM32, ainsi que des tests `native` pour valider la logique côté hôte. Ajoutez vos cibles personnalisées dans `firmware/targets/`.
- **Pipeline matériel** : `hardware/` propose des projets KiCad et des scripts pour générer le schéma, valider les règles (DRC/ERC) et exporter la nomenclature. Les profils de conformité (ex : `iot_wifi_eu`) s’appuient sur les standards dans `standards/`.
- **OpenClaw en mode observateur** : OpenClaw peut appliquer des labels ou laisser des commentaires sanitisés sur les issues/PR sans jamais écrire dans le code. Son exécution doit se faire en bac à sable, sans secrets【57263998884462†L355-L419】.

## 🚀 Prise en main rapide

1. **Créer votre spécification** : copiez/complétez un modèle dans `specs/` ou utilisez `python tools/ai/specify_init.py --name votre-feature` pour générer un squelette.
2. **Définir votre profil** (prototype ou iot\_wifi\_eu) via `python tools/compliance/use_profile.py`.
3. **Développement firmware** : installez PlatformIO (`pip install platformio`), puis :
   ```bash
   cd firmware
   pio run -e esp32s3_idf   # build
   pio test -e native        # tests unitaires hôte
   ```
4. **Lancer un agent** : ouvrez une issue et ajoutez l’étiquette appropriée (`ai:spec`, `ai:plan`, etc.). Le workflow agentique crée une PR avec un diff minimal, les tests et un résumé humain.
5. **Contrôler les PR** : la CI exécute des gates (build/tests/validation spec). Un scope guard vérifie que les modifications respectent le label.
6. **Lire la documentation** : les dossiers `docs/` et `standards/` contiennent des guides (setup KiCad, sécurité, compliance) et des standards versionnés injectés par AgentOS.

## 🗂 Arborescence principale

- `specs/` : spécifications, architectures, plans et tâches.
- `standards/` : standards globaux (firmware, hardware, tests), profils de conformité.
- `bmad/` : rôles, rituels et gabarits de handoff pour orchestrer les agents.
- `agents/` : prompts pour chaque rôle.
- `tools/` : scripts AI (sanitisation, prompts), cockpit de génération, gates et validateurs.
- `firmware/` : projet PlatformIO (targets + tests).
- `hardware/` : projets KiCad et scripts de génération.
- `.github/` : workflows CI (build/test, scope guard, enforcement labels) et agents markdown (Option A).
- `openclaw/` : configuration et règles pour OpenClaw en mode observateur.
- `licenses/` : copies/summaries des licences MIT, CERN OHL v2 et CC BY 4.0.

## 📄 Licences

Le code source est diffusé sous **MIT**. Les fichiers matériels (KiCad, mécaniques, BOM) sont sous **CERN OHL v2 Permissive**, encourageant la collaboration et la liberté d’étudier et partager les designs【572981070514051†L86-L91】. La documentation et les spécifications sont sous **Creative Commons BY 4.0**, permettant la réutilisation et l’adaptation avec attribution【335439356583797†L59-L75】.

## 🤝 Contribuer

Les contributions sont les bienvenues ! Vous pouvez proposer de nouveaux profils cibles, améliorer les scripts de gating ou enrichir les standards. N’oubliez pas de suivre la politique anti‑injection décrite dans `docs/security/anti_prompt_injection_policy.md` et d’ajouter des tests avec vos changements.

---

Ce dépôt vise à offrir un point de départ moderne pour des projets embarqués assistés par IA, en conciliant innovation et sécurité. Explorez, adaptez et bâtissez votre prochain projet en toute confiance !