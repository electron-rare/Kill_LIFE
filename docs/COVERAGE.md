# Test Coverage — Rapport de couverture des tests

---

## Objectif

Mesurer le taux de couverture des tests automatisés sur le code Python du projet (tests unitaires, intégration).

---

## Prérequis

- Python installé
- Les dépendances du projet installées (voir requirements-mistral.txt)
- coverage.py installé :
  ```bash
  pip install coverage
  ```

---

## Générer le rapport de couverture

1. Place-toi à la racine du projet.
2. Lance les tests avec coverage :
   ```bash
   coverage run -m pytest
   ```
3. Génère le rapport HTML :
   ```bash
   coverage html -d docs/coverage_report
   ```
4. Ouvre le fichier docs/coverage_report/index.html dans ton navigateur.

---

## Interprétation

- Le rapport indique le pourcentage de code testé, les fichiers couverts, et les lignes non testées.
- Plus le taux de couverture est élevé, plus le projet est fiable.

---

## Bonnes pratiques

- Vise au moins 80% de couverture.
- Ajoute des tests pour les parties critiques ou non couvertes.
- Mets à jour le rapport à chaque modification majeure.

---

## Automatisation (optionnel)

Tu peux ajouter une tâche dans le Makefile :

```
coverage:
	coverage run -m pytest
	coverage html -d docs/coverage_report
```

---

Pour toute question, consulte le README ou demande à l’agent QA.
