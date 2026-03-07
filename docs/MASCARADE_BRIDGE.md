# Pont Kill_LIFE <-> Mascarade

Ce document rattache les décisions et implémentations produites pendant la session de travail locale au repo `Kill_LIFE`.

## But

Garder une séparation propre entre :

- `Kill_LIFE` : repo de méthode, specs, gates, evidence packs, workflows hardware/firmware.
- `Mascarade` : repo compagnon d’exécution locale pour orchestration LLM, distillation/fine-tuning, et outillage CAD conteneurisé.

En local, les deux dépôts sont côte à côte :

- `Kill_LIFE` : `../Kill_LIFE`
- `Mascarade` : `../mascarade`

## Ce qui a été mis en place côté Mascarade

### 1. Stack CAD/EDA locale

La stack CAD/EDA a maintenant été intégrée directement dans `Kill_LIFE` :

- `deploy/cad/docker-compose.yml`
- `tools/hw/cad_stack.sh`

Elle fournit :

- `kicad-headless` via `kicad-cli` sur une image KiCad 10 compatible
- `kicad-mcp` en transport `stdio`, lancé via `tools/hw/run_kicad_mcp.sh`
- `freecad-headless` via `FreeCADCmd`
- `platformio` via CLI `pio`

Le repo `Mascarade` reste utile comme repo compagnon pour :

- orchestration LLM
- distillation / fine-tuning
- modèles students spécialisés

### 2. Pipeline local teacher -> student

Le repo compagnon contient aussi un pipeline local de distillation et fine-tuning :

- `../mascarade/finetune/distill_dataset.py`
- `../mascarade/finetune/distill_and_train.py`
- `../mascarade/finetune/run_local.py`
- `../mascarade/finetune/batch_local.py`

Domaines déjà traités ou préparés :

- `kicad`
- `freecad`
- `platformio`
- `esp32/iot`
- `spice`

Ce pipeline sert à produire de petits modèles spécialisés exploitables localement pour les agents `HW`, `Firmware`, `Doc` et `QA`.

## Répartition recommandée des rôles

| Besoin | Repo recommandé | Raison |
|---|---|---|
| Specs, ADR, gates, evidence packs | `Kill_LIFE` | c’est la source de vérité méthodologique |
| Exécution LLM locale et orchestration provider/model | `Mascarade` | c’est le cockpit d’exécution |
| KiCad/FreeCAD/PlatformIO en conteneur | `Kill_LIFE` | stack CAD désormais intégrée localement |
| Datasets, distillation, adapters LoRA/QLoRA | `Mascarade` | pipeline de training déjà opérationnel |
| Rapports finaux, runbooks, conformité | `Kill_LIFE` | cohérence des artefacts et traçabilité |

## Comment relier les deux dépôts

### Pour le hardware / CAD

`Kill_LIFE` garde :

- les règles
- les schémas
- les evidence packs
- les handoffs

`Kill_LIFE` exécute maintenant directement :

- `kicad-cli`
- le serveur `kicad-mcp`
- `FreeCADCmd`
- `pio`

Le flux recommandé est :

1. préparer la spec et les critères d’acceptation dans `Kill_LIFE`
2. exécuter les outils CAD/EDA dans `Kill_LIFE`
3. rapatrier les rapports, exports et décisions dans `Kill_LIFE/docs/` et `Kill_LIFE/artifacts/`

### Pour les agents IA spécialisés

`Kill_LIFE` fournit la matière de domaine :

- `specs/`
- `docs/`
- `hardware/`
- `tools/`
- conventions et profils compliance

`Mascarade` transforme cette matière en :

- datasets `ShareGPT JSONL`
- distillation teacher -> student
- adapters LoRA/QLoRA locaux

Le flux recommandé est :

1. extraire ou générer des datasets depuis `Kill_LIFE`
2. entraîner les students côté `Mascarade`
3. réinjecter l’usage de ces students dans les workflows agents de `Kill_LIFE`

## Alignement avec l’état de l’art au 6 mars 2026

Points retenus pendant la recherche :

- `kicad-cli` est la voie officielle pour le headless KiCad
- pour MCP, `stdio` reste le bon choix en local
- `Streamable HTTP` ne doit être ajouté que si on expose un vrai serveur distant
- `FreeCADCmd` est le mode headless propre pour FreeCAD
- `PlatformIO` reste le plus simple à conteneuriser via CLI Python

Conséquence pour `Kill_LIFE` :

- ne pas mélanger la méthode et la couche d’exécution
- documenter `Mascarade` comme repo compagnon, pas comme dépendance cachée
- garder les evidence packs et la gouvernance dans `Kill_LIFE`

## Statut actuel

L’étape d’intégration côté `Kill_LIFE` est maintenant réalisée.

La couche CAD/EDA locale vit directement dans ce dépôt :

- `deploy/cad/docker-compose.yml`
- `deploy/cad/Dockerfile.kicad-mcp`
- `deploy/cad/Dockerfile.freecad-headless`
- `deploy/cad/Dockerfile.platformio`
- `tools/hw/cad_stack.sh`

## Intégration actuelle dans Kill_LIFE

Le dépôt `Kill_LIFE` expose maintenant un launcher local natif :

- `tools/hw/cad_stack.sh`
- `tools/hw/run_kicad_mcp.sh`

Ce launcher :

- monte `Kill_LIFE` comme workspace par défaut
- pilote directement `deploy/cad/docker-compose.yml`
- évite de cacher une dépendance implicite vers `Mascarade`
- laisse `Mascarade` jouer son rôle de repo compagnon pour LLM local et fine-tuning

Exemples :

```bash
tools/hw/cad_stack.sh doctor
tools/hw/cad_stack.sh kicad-cli version
tools/hw/cad_stack.sh pio system info
tools/hw/run_kicad_mcp.sh --doctor
tools/hw/cad_stack.sh mcp
```
