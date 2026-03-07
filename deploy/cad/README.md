# CAD Stack

Stack Docker CAD/EDA intégrée directement dans `Kill_LIFE`.

## Direction retenue

- `KiCad headless`: `kicad-cli` via une image KiCad 10 (`kicad/kicad:nightly` par défaut)
- `KiCad MCP`: `kicad-sch-mcp` en `stdio`
- `FreeCAD headless`: `FreeCADCmd`
- `PlatformIO`: `pio` dans un conteneur Python léger

## Usage rapide

```bash
tools/hw/cad_stack.sh up
tools/hw/cad_stack.sh doctor
tools/hw/cad_stack.sh kicad-cli version
tools/hw/cad_stack.sh freecad-cmd -c "import FreeCAD; print(FreeCAD.Version())"
tools/hw/cad_stack.sh pio system info
tools/hw/cad_stack.sh mcp
```

Le workspace monté dans les conteneurs est la racine de `Kill_LIFE` par défaut.
`tools/hw/cad_stack.sh build ...` redéploie aussi automatiquement les services persistants reconstruits, pour éviter de garder un ancien conteneur sur une image obsolète.

Variables utiles :

- `KICAD_DOCKER_IMAGE` : image KiCad 10 à utiliser. Par défaut, la stack suit la branche `nightly` tant qu’une image stable 10.x n’est pas explicitement épinglée.
- `CAD_WORKSPACE_DIR` : workspace monté dans `/workspace`

## Note MCP

Le choix ici est volontairement sobre :

- `stdio` pour l’usage local
- `kicad-sch-api` pour le schématique via `kicad-sch-mcp`
- `kicad-cli` comme source de vérité pour les exports et checks

Si un serveur MCP distant devient nécessaire plus tard, il faudra ajouter un vrai transport réseau adapté, pas détourner le mode local.
