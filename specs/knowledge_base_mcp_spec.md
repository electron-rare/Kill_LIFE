# Spec MCP Knowledge Base

Last updated: 2026-03-08

## Objectif

Documenter l'implementation MCP `knowledge-base` a partir du bridge knowledge base actuel, avec uniquement `memos` et `docmost` dans la pile supportee.

## Etat actuel

- backend reel dans `mascarade/core/mascarade/integrations/knowledge_base.py`
- bridge HTTP canonique dans `mascarade/api/src/routes/knowledgeBase.ts`
- UI consommatrice dans `mascarade/web/src/pages/KnowledgeBrowser.tsx` et `crazy_life/src/pages/KnowledgeBrowser.tsx`
- providers supportes:
  - `memos`
  - `docmost`

## Surface MCP implemente

Serveur MCP `knowledge-base` local avec les outils:

- `search_pages`
- `read_page`
- `append_to_page`
- `create_page`

## Mapping depuis l'existant

- `GET /api/knowledge-base/search` -> `search_pages`
- `GET /api/knowledge-base/pages/:pageId` -> `read_page`
- `POST /api/knowledge-base/pages/:pageId/append` -> `append_to_page`
- `POST /api/knowledge-base/pages` -> `create_page`

## Contraintes

- garder `stdio` comme transport par defaut
- ne pas exposer un MCP reseau en v1
- garder le bridge HTTP canonique tant que les clients UI le consomment
- launcher operateur: `tools/run_knowledge_base_mcp.sh`
- erreurs explicites si le provider actif n'est pas configure

## Providers supportes

- `memos`
  - prerequis: `MEMOS_BASE_URL`, `MEMOS_ACCESS_TOKEN`
- `docmost`
  - prerequis: `DOCMOST_BASE_URL`, `DOCMOST_EMAIL`, `DOCMOST_PASSWORD`

## Hors scope v1

- ajout d'un troisieme provider non qualifie
- suppression du bridge HTTP canonique
- edition riche avancee ou blocs proprietaires
- sync bidirectionnelle UI <-> MCP hors actions explicites

## Validation minimale

- handshake `initialize -> tools/list` vert
- `search_pages` et `read_page` smokees sur le provider actif
- erreur structuree et non ambigue si le provider actif n'est pas configure
- documentation operateur et matrice de support mises a jour
