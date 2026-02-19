# Note technique : Utilisation de kicad-sch-api

Si l’intégration ou l’automatisation des opérations sur les schémas KiCad n’est pas bien implémentée dans le projet, voici un rappel :

- Utiliser le package Python `kicad-sch-api` pour manipuler les fichiers `.kicad_sch`.
- Exemple de script pour charger, modifier et sauvegarder un schéma :

```python
from kicad_sch_api import Schematic

sch = Schematic('hardware/mon_schéma.kicad_sch')
for comp in sch.components:
    print(comp.ref, comp.value, comp.footprint)
sch.components[0].value = "10k"
sch.save('hardware/mon_schéma_modifié.kicad_sch')
```

- Pour des fonctionnalités avancées, consulter https://github.com/circuit-synth/mcp-kicad-sch-api
- Adapter les scripts d’automatisation hardware pour utiliser cette API.

À garder en référence si besoin d’améliorer ou corriger l’intégration KiCad dans le workflow.