# Standards (Agent OS style)

Objectif : ne plus “ré-expliquer” tes conventions à chaque prompt.
- `global/` : standards communs
- `profiles/` : overrides selon le type de projet

Usage recommandé :
- Les agents lisent **toujours** `standards/global/*` + le profil actif.
- Le profil actif est déclaré dans `specs/constraints.yaml` (ex: esp-first).
