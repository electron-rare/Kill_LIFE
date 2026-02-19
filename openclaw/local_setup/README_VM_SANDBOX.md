# Synthèse : Intégration locale OpenClaw en VM sandboxée

## Objectif
Automatiser l’installation, la sécurisation et la validation d’OpenClaw dans une VM Ubuntu Minimal, sans risque pour le dépôt principal.

## Étapes automatisées

1. **Préparation VM**
   - Installation VirtualBox/QEMU/LXD
   - Téléchargement image Ubuntu Server 24.04 LTS Minimal
   - Création VM (2 Go RAM, 10-20 Go disque, sans interface graphique)

2. **Installation système**
   - Installation manuelle d’Ubuntu Minimal (console VM)
   - Mise à jour système
   - Installation paquets requis : `install_packages.sh`

3. **Sécurité & conformité**
   - Scan secrets/tokens/code source : `scan_secrets.sh`
   - Vérification montages : `check_mounts.sh`
   - Politique observer-only : `check_observer_only.sh`

4. **Installation OpenClaw**
   - Installation via curl : `curl -fsSL https://openclaw.ai/install.sh | bash`
   - Vérification binaire : `check_openclaw.sh`
   - Tests doctor/help : `openclaw_check.sh`

5. **Onboarding & simulation**
   - Simulation onboarding : `onboarding_simulation.sh` (lance tous les guides/tests)

6. **Destruction VM & traçabilité**
   - Destruction/réinitialisation : `destroy_vm.sh`
   - Documentation : compléter `onboarding/vm_test_report.md`

## Scripts à utiliser
- Tous les scripts sont dans `openclaw/local_setup/`
- Instructions centralisées dans `install_vm_openclaw.sh`

## Validation
- Suivre le script principal, transférer les scripts dans la VM, exécuter chaque étape.
- Compléter le rapport de test.

---

## Prochaine étape todo
- Installer curl, git, nodejs, npm, build-essential dans la VM (via install_packages.sh)
- Puis enchaîner sur le scan des secrets/tokens/code source

Pour continuer, souhaitez-vous lancer l’installation des paquets dans la VM (via scp/ssh) ou simuler l’exécution ?