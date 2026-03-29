# Gate S2 — Web / PR review

Web (si concerné):
- [ ] `npm run build` ok (aucune erreur TypeScript)
- [ ] `npx playwright test e2e/smoke.spec.ts` ok
- [ ] Pas de régression visuelle sur les pages modifiées

API (si concerné):
- [ ] `python -m unittest discover test/` — tests stable verts
- [ ] Endpoints modifiés documentés dans `specs/contracts/`
- [ ] Pas de chemin hardcodé (IPs, paths absolus)

PR review:
- [ ] Scope guard validé (write_set respecté par agent)
- [ ] Pas de secret dans le diff (`CLAUDE.md`, `.env`, tokens)
- [ ] Handoff template rempli si cross-repo
- [ ] Evidence pack généré (si lot concerné)
