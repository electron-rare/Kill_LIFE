# Workflow — Design produit / UX

## But
Définir l’expérience utilisateur, les états UI, les contraintes physiques (écran/boutons), et produire un handoff exploitable.

## Phases

### 1) Brief & contraintes
- Personas, contexte d’usage, objectifs UX
- Contraintes hardware (écran, boutons, feedback)
- Livrable : spec UX (règles + mapping inputs)
- Label : `ai:spec`

### 2) Exploration
- 3–5 directions (pas plus)
- Critères : lisibilité, erreurs, temps d’apprentissage, robustesse
- Livrable : “direction choisie” + rationale
- Label : `ai:plan` (docs)

### 3) Prototypage
- Wireframes → prototype (low → mid → hi)
- États : nominal, loading, erreur, offline
- Livrable : matrice états + mapping boutons/gestes
- Label : `ai:docs` (ou `ai:impl` si tu ajoutes un prototype UI)

### 4) Design system & handoff
- Composants + états
- Guidelines + naming assets
- Handoff vers firmware/hardware
- Label : `ai:docs`

## Gates
- Mapping inputs complet (boutons/écran)
- États d’erreur spécifiés
- Handoff : assets + conventions

## Evidence pack
- Captures/export (ou liens internes)
- Checklist de validation UX

## Tips
- Si l’UI doit toucher le firmware : sépare UI logique (testable `native`) et rendu HW (drivers).
