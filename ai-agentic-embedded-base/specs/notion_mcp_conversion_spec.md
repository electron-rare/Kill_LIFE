# Spec conversion MCP Notion

Last updated: 2026-03-07

## Objectif

Documenter l'implémentation MCP `notion` à partir de l'intégration `Notion` existante, sans remplacer la voie HTTP existante en V1.

## État actuel

- backend réel dans `mascarade/core/mascarade/integrations/notion.py`
- bridge HTTP existant dans `mascarade/api/src/routes/notion.ts`
- UI consommatrice existante dans `crazy_life/src/pages/NotionBrowser.tsx`
- dépendance secrète: `NOTION_API_KEY`

## Surface MCP implémentée

Serveur MCP `notion` local avec les outils:

- `search_pages`
- `read_page`
- `append_to_page`
- `create_page`

## Mapping depuis l'existant

- `GET /api/notion/search` -> `search_pages`
- `GET /api/notion/pages/:pageId` -> `read_page`
- `POST /api/notion/pages/:pageId/append` -> `append_to_page`
- `POST /api/notion/pages` -> `create_page`

## Contraintes

- garder `stdio` comme transport par défaut
- ne pas exposer un MCP réseau en V1
- erreurs explicites si `NOTION_API_KEY` absent
- conserver le bridge HTTP existant tant que la migration client n'est pas faite
- launcher opérateur: `tools/run_notion_mcp.sh`

## Hors scope V1

- suppression du bridge HTTP existant
- édition riche avancée ou gestion fine des blocs Notion
- sync bidirectionnelle UI <-> MCP

## Validation minimale

- handshake `initialize -> tools/list` vert
- `search_pages` et `read_page` smokés
- erreur structurée et non ambiguë si `NOTION_API_KEY` absent
- documentation opérateur et matrice de support mises à jour
