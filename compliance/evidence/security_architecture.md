# Architecture de sécurité — Kill_LIFE

**Produit :** Kill_LIFE — Radio internet pilotée par la voix
**Version :** 1.0
**Date :** 2026-03-25
**Auteur :** Équipe KXKM / L'électron rare
**Références :** RED 2014/53/EU art. 3.3(d)(e)(f), EN 18031-1/-2/-3

---

## 1. Vue d'ensemble

Kill_LIFE est un dispositif IoT basé sur ESP32-S3 qui se connecte en WiFi à un serveur backend (Mascarade) pour la diffusion de radio internet et le traitement de commandes vocales. Ce document décrit l'état actuel de la sécurité, l'état cible, et le modèle de menaces.

### 1.1 Interfaces de communication

| Interface | Protocole | Direction | État actuel |
|---|---|---|---|
| WiFi STA → Backend Mascarade | HTTP | Bidirectionnel | Non chiffré |
| WiFi AP → Portail captif | HTTP | Client → Appareil | Auth basique, non chiffré |
| OTA firmware | HTTP GET | Serveur → Appareil | Pas de signature |
| I2S audio (interne) | I2S | MCU ↔ DAC/Mic | Bus interne, pas de risque réseau |
| SPI écran (interne) | SPI | MCU → LCD | Bus interne, pas de risque réseau |

### 1.2 Actifs à protéger

- **Intégrité du firmware** — empêcher l'exécution de code non autorisé
- **Confidentialité des communications** — protéger les flux audio et commandes
- **Disponibilité du service** — assurer le fonctionnement de la radio
- **Identifiants WiFi** — stockés en NVS, protéger contre l'extraction
- **Données utilisateur** — minimales (pas de données personnelles au sens RGPD, sauf si les commandes vocales sont considérées comme telles)

---

## 2. État actuel (prototype)

### 2.1 Communication backend

- Protocole : **HTTP en clair** (port 80)
- Aucun chiffrement TLS
- Aucune authentification mutuelle
- Le serveur Mascarade est identifié par son nom d'hôte/IP — pas de validation de certificat

### 2.2 Mises à jour OTA

- Téléchargement d'image firmware via **HTTP GET**
- **Aucune vérification de signature** de l'image
- Aucune vérification d'intégrité (pas de hash vérifié côté appareil)
- Pas de rollback automatique en cas d'échec
- Déclenchement manuel uniquement (pas d'auto-update)

### 2.3 Portail captif (mode AP)

- Serveur web embarqué en mode Access Point
- Authentification basique HTTP (mot de passe en clair dans les headers)
- Pas de HTTPS
- Vulnérabilité XSS identifiée et **corrigée** (sanitisation des entrées)

### 2.4 Stockage local

- Identifiants WiFi stockés en **NVS (Non-Volatile Storage)** — partition non chiffrée
- Pas de Secure Boot activé
- Pas de Flash Encryption activé

---

## 3. État cible (avant mise sur le marché CE)

### 3.1 TLS 1.3 pour les communications backend

**Objectif :** Chiffrer toutes les communications avec le serveur Mascarade.

**Implémentation prévue :**
- Activer mbedTLS intégré à ESP-IDF
- Configurer le client HTTP pour utiliser HTTPS (port 443)
- Embarquer le certificat racine du serveur (certificate pinning) ou utiliser le bundle de CA fourni par ESP-IDF (`esp_tls_set_global_ca_store()`)
- Vérification du certificat serveur obligatoire (`esp_tls_cfg_t.skip_common_name = false`)
- TLS 1.3 en priorité, fallback TLS 1.2 si nécessaire (RFC 8446)

**Estimation :**
- Impact mémoire : ~40 Ko de heap supplémentaire pour le contexte TLS
- Le module N16R8 dispose de 8 Mo de PSRAM — marge suffisante
- Certificats racines : ~2 Ko en flash

### 3.2 Signature des mises à jour OTA

**Objectif :** Garantir l'intégrité et l'authenticité des images firmware OTA.

**Implémentation prévue :**
- Utiliser le mécanisme `esp_secure_boot_v2` ou a minima la vérification de signature d'image OTA (`CONFIG_SECURE_SIGNED_ON_UPDATE`)
- Algorithme : ECDSA-256 (courbe secp256r1) — recommandé par Espressif pour les ressources contraintes
- Clé privée de signature stockée hors de l'appareil (poste de build ou HSM)
- Clé publique embarquée dans la partition `signature_verification_key`
- Rejet automatique de toute image non signée ou dont la signature est invalide
- Distribution des mises à jour via HTTPS (combiné avec 3.1)

**Étapes de déploiement :**
1. Générer la paire de clés ECDSA-256
2. Configurer `menuconfig` : `CONFIG_SECURE_SIGNED_ON_UPDATE=y`
3. Intégrer la signature dans le pipeline de build PlatformIO
4. Tester le rejet d'images non signées

### 3.3 Chiffrement de la partition NVS

**Objectif :** Protéger les identifiants WiFi et autres secrets stockés localement.

**Implémentation prévue :**
- Activer `CONFIG_NVS_ENCRYPTION=y` dans ESP-IDF
- Utiliser une clé de chiffrement NVS stockée dans la partition `nvs_keys`
- Combiné avec Flash Encryption pour une protection complète

### 3.4 Secure Boot (optionnel pour petite série)

**Objectif :** Empêcher l'exécution de firmware non autorisé au démarrage.

**Note :** Secure Boot V2 est irréversible (eFuse OTP). Pour une petite série d'installation artistique, cette mesure peut être disproportionnée. À évaluer en fonction de l'analyse de risque finale.

### 3.5 Portail captif sécurisé

**Objectif :** Protéger la configuration de l'appareil.

**Implémentation prévue :**
- HTTPS avec certificat auto-signé (acceptable pour un portail captif local)
- Remplacement de l'auth basique par un token de session temporaire
- Timeout de session (5 min d'inactivité)
- Rate limiting sur les tentatives d'authentification

---

## 4. Modèle de menaces

### 4.1 Interception réseau (sniffing)

| Paramètre | Valeur |
|---|---|
| Menace | Écoute passive du trafic WiFi entre l'appareil et le backend |
| Attaquant | Personne sur le même réseau WiFi ou à portée radio |
| Impact | Interception des flux audio, commandes, métadonnées de stations |
| Probabilité | Moyenne (réseau dédié mais WiFi accessible à portée) |
| **Mitigation actuelle** | Réseau WiFi dédié avec WPA2-PSK |
| **Mitigation cible** | TLS 1.3 (section 3.1) — chiffrement bout-en-bout |

### 4.2 Falsification de firmware (tampering)

| Paramètre | Valeur |
|---|---|
| Menace | Injection d'un firmware malveillant via OTA ou accès physique |
| Attaquant | Accès réseau local ou accès physique au port USB |
| Impact | Contrôle total de l'appareil, exfiltration de données, utilisation comme bot |
| Probabilité | Faible (nécessite accès au réseau de mise à jour ou accès physique) |
| **Mitigation actuelle** | OTA déclenchée manuellement, réseau dédié |
| **Mitigation cible** | Signature OTA ECDSA-256 (section 3.2) |

### 4.3 Point d'accès malveillant (rogue AP)

| Paramètre | Valeur |
|---|---|
| Menace | Création d'un faux point d'accès WiFi avec le même SSID pour détourner la connexion |
| Attaquant | Proximité physique de l'installation |
| Impact | Interception man-in-the-middle, redirection du trafic |
| Probabilité | Faible (installation artistique dans un lieu contrôlé) |
| **Mitigation actuelle** | SSID + mot de passe WPA2 connus uniquement de l'installateur |
| **Mitigation cible** | TLS avec certificate pinning empêche le MITM même sur un réseau compromis |

### 4.4 XSS sur l'interface web embarquée

| Paramètre | Valeur |
|---|---|
| Menace | Injection de script malveillant via les champs de saisie du portail captif |
| Attaquant | Utilisateur malveillant accédant au portail captif |
| Impact | Vol de session, exécution de code dans le navigateur de l'utilisateur |
| Probabilité | Faible (vulnérabilité corrigée) |
| **Mitigation actuelle** | Correctif appliqué — sanitisation des entrées, échappement HTML |
| **Mitigation cible** | Revue de code systématique, CSP headers |

### 4.5 Extraction de secrets par accès physique

| Paramètre | Valeur |
|---|---|
| Menace | Lecture de la flash SPI pour extraire les identifiants WiFi ou le firmware |
| Attaquant | Accès physique à la carte |
| Impact | Récupération des identifiants WiFi, reverse engineering du firmware |
| Probabilité | Faible (installation artistique dans un lieu semi-contrôlé) |
| **Mitigation actuelle** | Aucune protection matérielle |
| **Mitigation cible** | Flash Encryption + NVS Encryption (sections 3.3, 3.4) |

---

## 5. Alignement EN 18031

La série EN 18031 (EN 18031-1, -2, -3) publiée au JOUE par la décision 2025/138 est la norme harmonisée pour les exigences cybersécurité de la RED (articles 3.3 d/e/f).

### 5.1 EN 18031-1 — Sécurité réseau (art. 3.3 d)

| Exigence | État actuel | État cible |
|---|---|---|
| Chiffrement des communications | Non conforme (HTTP) | Conforme (TLS 1.3) |
| Intégrité des mises à jour | Non conforme (pas de signature) | Conforme (ECDSA-256) |
| Mécanisme d'authentification | Partiel (WPA2-PSK) | Conforme (TLS mutual auth optionnel) |
| Gestion des vulnérabilités | Processus informel | Processus documenté (changelog + OTA) |

### 5.2 EN 18031-2 — Protection des données personnelles (art. 3.3 e)

| Exigence | État actuel | État cible |
|---|---|---|
| Minimisation des données | Conforme (pas de collecte de données personnelles) | Maintenir |
| Chiffrement des données au repos | Non conforme (NVS en clair) | Conforme (NVS Encryption) |
| Consentement utilisateur | N/A (pas de données personnelles collectées) | N/A |

**Note :** Les commandes vocales ne sont pas stockées ni transmises comme données personnelles dans l'architecture actuelle — elles sont traitées en mémoire volatile et envoyées au backend pour interprétation. Néanmoins, le chiffrement TLS protégera ces flux en transit.

### 5.3 EN 18031-3 — Protection contre la fraude (art. 3.3 f)

| Exigence | État actuel | État cible |
|---|---|---|
| Prévention de l'utilisation abusive | Faible (pas de rate limiting réseau) | Rate limiting + monitoring |
| Intégrité du logiciel | Non conforme (pas de secure boot) | Évaluer secure boot vs. signature OTA seule |

**Note :** Pour un appareil de radio internet en installation artistique, le risque de fraude économique est très limité. La conformité à l'article 3.3(f) sera assurée de manière proportionnée.

---

## 6. Feuille de route sécurité

| Phase | Actions | Échéance estimée |
|---|---|---|
| **Phase 1** | Implémenter TLS 1.3 pour le backend Mascarade | Avant mise sur le marché |
| **Phase 1** | Implémenter la signature OTA ECDSA-256 | Avant mise sur le marché |
| **Phase 2** | Activer NVS Encryption | Avant mise sur le marché |
| **Phase 2** | Sécuriser le portail captif (HTTPS, token session) | Avant mise sur le marché |
| **Phase 3** | Évaluer Secure Boot V2 (optionnel) | Post-lancement si justifié |
| **Phase 3** | Audit de sécurité externe (optionnel pour petite série) | Si requis par le profil de risque |

---

## 7. Hypothèses et limites

- L'appareil fonctionne sur un **réseau WiFi dédié** à l'installation, non partagé avec le public.
- L'accès physique est **semi-contrôlé** (boîtier dans un lieu d'exposition).
- Le volume de production est **très faible** (petite série artistique) — les mesures de sécurité sont proportionnées à ce contexte.
- Le serveur backend Mascarade est géré par l'équipe KXKM et considéré comme un environnement de confiance.
