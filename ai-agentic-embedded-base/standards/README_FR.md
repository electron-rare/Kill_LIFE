# Standards (Agent OS style)

Objectif : ne plus “ré-expliquer” tes conventions à chaque prompt.
- `global/` : standards communs
- `profiles/` : overrides selon le type de projet

Usage recommandé :
- Les agents lisent **toujours** `standards/global/*` + le profil actif.
- Le profil actif est déclaré dans `specs/constraints.yaml` (ex: esp-first).

<iframe src="https://github.com/sponsors/electron-rare/card" title="Sponsor electron-rare" height="225" width="600" style="border: 0;"></iframe>
