# Exemples d’utilisation OpenClaw

## Exemple 1 : Ajout de label sur une issue

1. Créez une issue sur GitHub.
2. Utilisez OpenClaw pour ajouter le label `ai:spec`.
3. Vérifiez que le label apparaît et que l’issue est prise en charge par l’agent.

## Exemple 2 : Publication d’un commentaire sanitisé

1. Rédigez un commentaire contenant des mentions, du code ou des URLs.
2. Utilisez OpenClaw pour publier ce commentaire.
3. Vérifiez que le commentaire publié ne contient plus de mentions, code ou URLs (sanitisation effective).

## Exemple 3 : Workflow complet PR

1. Créez une PR avec le label `ai:impl`.
2. OpenClaw ajoute un commentaire sanitisé sur l’avancement.
3. Les gates CI valident la conformité.
4. Evidence pack généré et attaché à la PR.

## Ressources complémentaires

- [FAQ OpenClaw](guide_contributeur.md#faq-openclaw)
- [README onboarding](README.md)
- [README openclaw/](../README.md)
- [Script de sanitisation](../../tools/ai/sanitize_issue.py)

## Bonnes pratiques

- Toujours vérifier la sanitisation avant publication.
- Utiliser les labels `ai:*` pour tracer les actions.
- Documenter chaque étape du workflow.
- Consulter la FAQ en cas de doute.
