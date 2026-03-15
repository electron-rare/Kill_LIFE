# Spec perimetre MCP KiCad

Last updated: 2026-03-07

## Objectifs

- O1. Definir le perimetre fonctionnel du serveur MCP KiCad supporte par `Kill_LIFE`.
- O2. Eviter la derive entre implementation serveur, launcher local, docs et attentes des agents.
- O3. Fixer une frontiere claire entre le contrat stable du MCP KiCad, les extensions futures legitimes et ce qui reste hors scope.

## Non-objectifs

- N1. Faire du serveur MCP KiCad un assistant generaliste ou un agent conversationnel.
- N2. Exposer un transport reseau ou multi-tenant en v1.
- N3. Couvrir Git, CI, docs repo, orchestration infra, ou des actions hors CAD.
- N4. Ajouter des effets de bord caches hors des chemins explicitement fournis par l'utilisateur ou le runtime.

## Ownership

- Implementation serveur de reference: `mascarade/finetune/kicad_mcp_server`
- Contrat local, launcher, smoke test et doc d'usage: `Kill_LIFE`
- Consommateurs externes eventuels: autres repos, sans ownership serveur

## User stories

- US1. En tant qu'ingenieur hardware, je veux creer, ouvrir, modifier et exporter un projet KiCad depuis un client MCP local.
- US2. En tant qu'agent outille, je veux inspecter schema, board, librairies et regles sans corrompre le projet.
- US3. En tant qu'operateur de fabrication, je veux lancer les validations et exports minimaux avant production.
- US4. En tant qu'agent de sourcing, je veux relier composants, footprints, datasheets et references JLCPCB/LCSC.

## Exigences fonctionnelles v1

- F1. Transport
  - Le serveur MUST exposer `stdio` local uniquement.
  - Le serveur MUST parler JSON-RPC compatible MCP avec framing ligne par ligne, conforme au SDK utilise.
  - Le serveur MUST fonctionner via `tools/hw/run_kicad_mcp.sh`.
  - Le serveur MUST exposer une seule surface stable; aucun profil runtime alternatif ne doit etre requis.

- F2. Cycle projet
  - Le serveur MUST permettre de creer, ouvrir, sauvegarder et inspecter un projet KiCad.
  - Le serveur MUST distinguer les operations de lecture des operations de mutation.

- F3. Schema
  - Le serveur MUST permettre le placement de symboles, la connexion de pins, la pose de labels/nets et la generation de netlist.
  - Le serveur SHOULD permettre l'enrichissement des champs de composant utiles a la suite du flux CAD.

- F4. PCB / layout
  - Le serveur MUST permettre l'inspection du board, des couches, des extents et de la geometrie.
  - Le serveur MUST couvrir outline, trous de fixation, textes, zones et operations de placement/deplacement/rotation de composants.

- F5. Routage
  - Le serveur MUST permettre la creation ou l'inspection de pistes, vias, pads, nets et couches utiles au routage.
  - Le serveur SHOULD exposer des aides de recherche/outillage de routage.

- F6. Librairies
  - Le serveur MUST lister et rechercher des symboles et footprints.
  - Le serveur MUST permettre l'enregistrement de librairies projet/globales quand l'operation est explicitement demandee.
  - Le serveur SHOULD permettre la creation de symboles et footprints custom en local.

- F7. Validation
  - Le serveur MUST permettre l'execution de checks de validation de type DRC ou equivalent.
  - Le serveur MUST renvoyer des erreurs structurees et exploitables quand une validation echoue.

- F8. Export
  - Le serveur MUST couvrir les exports minimaux de fabrication et de revue: Gerber, PDF, 3D ou sorties equivalentes deja supportees par l'implementation.
  - Le serveur SHOULD rendre le chemin de sortie explicite.

- F9. Sourcing
  - Le serveur SHOULD permettre la recherche de composants JLCPCB/LCSC, les alternatives proches et l'acces aux datasheets.
  - Les integrations de sourcing MAY utiliser un backend local ou une API externe si les credentials sont presents.

- F10. Resources / prompts / UI
  - Le serveur MUST exposer `tools`, `resources` et `prompts` comme surface stable unique.
  - Toute resource exposee MUST correspondre a un backend reel et testable.
  - Les prompts MUST referencer uniquement des capabilities supportees.
  - Les actions UI supportees MUST retourner un resultat deterministe ou une erreur structuree quand le contexte graphique est indisponible.

- F11. Runtime
  - Le serveur MUST preferer un backend KiCad reel.
  - Le backend SHOULD preferer IPC quand disponible.
  - Le backend MUST pouvoir retomber sur SWIG si IPC n'est pas disponible.
  - Le runtime MUST fonctionner soit sur host avec `pcbnew`, soit via le conteneur KiCad supporte.

## Exigences non-fonctionnelles

- Securite
  - Le serveur MUST rester local par defaut.
  - Le serveur MUST eviter les ecritures hors `projectPath`, `libraryPath`, runtime home et `KICAD_MCP_DATA_DIR`.
  - Le serveur MUST NOT exiger de secrets pour les usages locaux de base.

- Fiabilite
  - `initialize`, `tools/list`, `resources/list` et `prompts/list` MUST passer sur une machine supportee.
  - Le launcher MUST gerer le fallback host -> container quand l'hote n'expose pas `pcbnew`.
  - Les erreurs MUST etre actionnables et non silencieuses.

- Determinisme
  - Les outils de lecture MUST NOT muter l'etat du projet.
  - Les outils de mutation SHOULD exiger des parametres explicites et des chemins non ambigus.

- Observabilite
  - Le serveur MUST garder les erreurs et warnings exploitables.
  - Le niveau de log par defaut SHOULD etre discret.
  - En succes nominal, le runtime SHOULD eviter de polluer `stderr` avec du bruit de demarrage non essentiel.

- Compatibilite
  - Le contrat de transport MUST rester stable pour les consommateurs locaux de `Kill_LIFE`.
  - Le runtime conteneur supporte SHOULD rester aligne avec la version KiCad cible du projet, y compris la trajectoire v10.

## Extensions futures legitimes

- E1. Session IPC plus riche, synchronisee avec une UI KiCad vivante.
- E2. Coverage schematic plus avancee: edition structurelle plus large, contraintes electriques plus fines, automation de patterns repetitifs.
- E3. Workflows de revue plus riches: snapshots, diff de board/schema, previews avant mutation.
- E4. Sourcing plus fort: BOM, substitutions, scoring cout/disponibilite.
- E5. Dry-run systematique pour les mutations a fort impact.

## Hors scope

- H1. Chat libre, planification generale, ou raisonnement non CAD.
- H2. Serveur MCP HTTP/SSE expose sur le reseau par defaut.
- H3. Git operations, PR management, CI/CD, ou orchestration repo.
- H4. Gestion de secrets globale de la machine.
- H5. Autonomie d'achat ou de commande fournisseur.
- H6. Couverture d'autres outils CAD hors KiCad dans ce serveur de reference.

## Contrats / interfaces

- I1. Point d'entree supporte: `tools/hw/run_kicad_mcp.sh`
- I2. Config consommatrice supportee: `mcp.json` cote `Kill_LIFE`
- I3. Implementation serveur de reference: `mascarade/finetune/kicad_mcp_server`
- I4. Smoke minimal supporte:
  - `initialize`
  - `notifications/initialized`
  - `tools/list`
  - `resources/list`
  - `prompts/list`
  - `resources/read` sur au moins une resource stable
  - `prompts/get` sur au moins un prompt stable

## Critieres d'acceptation

- AC1. Le repo documente un seul serveur KiCad MCP supporte en v1.
- AC2. Le serveur expose une surface stable fonctionnelle pour: projet, schema, PCB, librairies, validation, export, resources, prompts et sourcing.
- AC3. `python3 tools/hw/mcp_smoke.py` passe sur un environnement supporte.
- AC4. En absence de `pcbnew` host, le launcher supporte bascule vers le runtime conteneur.
- AC5. La doc d'usage locale renvoie explicitement vers cette spec de perimetre.
- AC6. Les sujets hors scope sont documentes au lieu d'etre supposes implicitement.
