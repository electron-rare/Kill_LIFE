# Design Blocks (KiCad 9)

Créer une brique :
- isoler un sous-schéma stable (ex: régulateur 3V3)
- générer un block via `schops block-make ...`
- versionner sous `hardware/blocks/<lib>.kicad_blocks/`

Instancier une brique :
- `schops block instantiate ...` (à implémenter selon ton workflow)
