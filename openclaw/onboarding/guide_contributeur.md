# Guide contributeur OpenClaw — Kill_LIFE

## Tutoriel pas-à-pas

1. **Lire le README openclaw/** et le guide onboarding.
2. **Vérifier la sandbox** : OpenClaw doit tourner en environnement jetable, sans accès aux secrets/code source.
3. **Ajouter un label `ai:*`** sur une issue ou PR pour activer l’automatisation.
4. **Publier un commentaire** : Utiliser OpenClaw pour poster un statut ou une note, qui sera automatiquement sanitisée.
5. **Vérifier la sanitisation** : Le commentaire ne doit contenir ni mention, ni code, ni URL, ni secret.
6. **Passer les gates CI** : Toute action doit être validée par les workflows GitHub (scope guard, evidence pack).
7. **Documenter la contribution** : Mettre à jour le README, la checklist onboarding, et fournir un evidence pack.

## Exemple de workflow OpenClaw

- Création d’une issue avec label `ai:qa`.
- OpenClaw ajoute un label `ai:impl` sur la PR associée.
- OpenClaw publie un commentaire sanitisé sur l’avancement.
- Les gates CI valident la conformité et la sécurité.
- Evidence pack généré et attaché à la PR.

## FAQ OpenClaw

**Q : OpenClaw peut-il modifier le code source ?**
R : Non, OpenClaw ne commite ni ne modifie le code. Seuls les labels et commentaires sanitisés sont autorisés.

**Q : Comment garantir la sécurité ?**
R : Utilisez toujours un environnement sandboxé, vérifiez la sanitisation, et ne donnez jamais accès aux secrets.

**Q : Que faire en cas d’incident ?**
R : Ajoutez le label `ai:hold` sur l’issue/PR, vérifiez les logs CI, et contactez l’équipe.

**Q : Où trouver la documentation complète ?**
R : Voir le README openclaw/, le guide onboarding, et la section sécurité.

## Bonnes pratiques OpenClaw

- Toujours sandboxer l’environnement.
- Ne jamais donner accès aux secrets ou au code source.
- Utiliser les labels `ai:*` pour tracer les actions.
- Publier uniquement des commentaires sanitisés.
- Documenter chaque contribution.
- Respecter la checklist onboarding.
- Passer les gates CI et fournir un evidence pack.
- Consulter la FAQ et demander conseil en cas de doute.
