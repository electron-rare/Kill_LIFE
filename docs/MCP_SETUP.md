# MCP setup (KiCad)

Source canonique pour la configuration MCP locale de `Kill_LIFE`.

Spec de perimetre:

- `specs/kicad_mcp_scope_spec.md`

## Chemin supporté

- Serveur MCP supporté: `mascarade/finetune/kicad_mcp_server`
- Launcher supporté côté `Kill_LIFE`: `tools/hw/run_kicad_mcp.sh`
- Transport supporté: `stdio` local uniquement
- Profil supporté par défaut: `v1`
- Profil étendu optionnel: `v2`

`kicad-sch-mcp` n’est plus le chemin recommandé dans ce repo. Il reste un ancien axe documentaire, mais il n’est ni installé ni supporté ici comme runtime principal.

## Prérequis

- le repo compagnon `mascarade` existe en voisin (`../mascarade`) ou via `MASCARADE_DIR`
- `node` est disponible sur la machine
- le serveur est buildé dans `mascarade/finetune/kicad_mcp_server/dist/index.js`
- KiCad et son Python sont visibles par le runtime du serveur

Diagnostic rapide :

```bash
tools/hw/run_kicad_mcp.sh --doctor
python3 tools/hw/mcp_smoke.py
```

Sélection de profil :

```bash
tools/hw/run_kicad_mcp.sh --profile v1
tools/hw/run_kicad_mcp.sh --profile v2
python3 tools/hw/mcp_smoke.py --profile v2
```

## Configuration locale

Le fichier versionné [mcp.json](../mcp.json) pointe déjà vers le launcher supporté :

```json
{
  "mcpServers": {
    "kicad": {
      "type": "local",
      "command": "bash",
      "args": ["tools/hw/run_kicad_mcp.sh", "--profile", "v1"],
      "tools": ["*"]
    }
  }
}
```

Le launcher prépare un runtime local writable sous `.cad-home/kicad-mcp/` et exporte `KICAD_MCP_DATA_DIR` pour éviter les écritures dans un préfixe immuable.
Il applique aussi par défaut un niveau de logs discret (`warn`) pour éviter de polluer les clients MCP sur le chemin nominal.

## Serveur auxiliaire

`Kill_LIFE` expose aussi un serveur MCP auxiliaire `validate-specs` pour la validation repo/specs :

```bash
python3 tools/validate_specs.py --json
python3 tools/validate_specs.py --mcp
```

Ce serveur ne remplace pas le runtime KiCad. Il sert à vérifier les specs, la conformité et l’usage RFC2119 côté dépôt.

## Usage

Depuis `Kill_LIFE` :

```bash
tools/hw/run_kicad_mcp.sh
```

## Politique de support

- `stdio` reste le seul transport supporté par défaut
- aucun serveur MCP réseau n’est exposé par défaut
- les serveurs mock/demo restent hors chemin de production tant qu’ils ne parlent pas à un backend réel
- `tools/hw/cad_stack.sh mcp` reste un chemin legacy à réaligner avant d’être re-documenté ici
