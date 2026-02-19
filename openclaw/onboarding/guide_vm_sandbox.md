# Guide d’intégration locale OpenClaw (VM sandboxée)

## Prérequis
- macOS ou Linux
- VirtualBox ou QEMU/KVM installé
- Accès internet
- Aucun secret ou code source du dépôt principal dans la VM

## Étapes

### 1. Créer une VM sandboxée
- Lancez VirtualBox ou QEMU/KVM
- Créez une nouvelle VM (Ubuntu recommandé)
- Allouez 2 Go RAM, 20 Go disque
- Démarrez la VM et installez Ubuntu

### 2. Préparer l’environnement
- Mettez à jour la VM :
  ```bash
  sudo apt update && sudo apt upgrade -y
  sudo apt install curl git nodejs npm build-essential -y
  ```
- Vérifiez que vous n’avez aucun secret/token dans la VM

### 3. Installer OpenClaw
- Téléchargez et lancez le script :
  ```bash
  curl -fsSL https://openclaw.ai/install.sh | bash
  ```
- Suivez les instructions, vérifiez ~/.local/bin/openclaw

### 4. Tester OpenClaw
- Lancez OpenClaw :
  ```bash
  openclaw doctor
  openclaw help
  ```
- Utilisez les guides et scripts du dossier openclaw/onboarding/

### 5. Sécurité
- Ne montez jamais le dossier du dépôt principal dans la VM
- N’utilisez OpenClaw que pour des tests, labels, commentaires sanitisés
- Détruisez la VM après usage ou réinitialisez-la

### 6. Documentation
- Consultez le README openclaw/, onboarding, et supports visuels

## Bonnes pratiques
- Toujours sandboxer OpenClaw
- Jamais d’accès aux secrets/code source
- Utiliser la VM pour tests, formation, ou simulation
- Respecter la politique sécurité Kill_LIFE

Pour toute question, ouvrez une issue ou contactez l’équipe.
