# Design Blocks (KiCad 10)

Créer une brique :
- isoler un sous-schéma stable (ex: régulateur 3V3)
- générer un block via `schops block-make ...`
- versionner sous `hardware/blocks/<lib>.kicad_blocks/`

Instancier une brique :
- `schops block instantiate ...` (à implémenter selon ton workflow)

<iframe src="https://github.com/sponsors/electron-rare/card" title="Sponsor electron-rare" height="225" width="600" style="border: 0;"></iframe>
