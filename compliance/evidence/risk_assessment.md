# Évaluation des risques — Kill_LIFE

**Produit :** Kill_LIFE — Radio internet pilotée par la voix
**Version :** 1.0
**Date :** 2026-03-25
**Auteur :** Équipe KXKM / L'électron rare
**Profil réglementaire :** EU/EEE — Directive RED 2014/53/EU

---

## 1. Méthodologie

Matrice de risque : **Impact** (Faible / Moyen / Élevé) × **Probabilité** (Faible / Moyenne / Élevée)

| Probabilité ↓ / Impact → | Faible | Moyen | Élevé |
|---|---|---|---|
| **Élevée** | Modéré | Élevé | Critique |
| **Moyenne** | Faible | Modéré | Élevé |
| **Faible** | Négligeable | Faible | Modéré |

Niveaux de risque résultants :
- **Critique** — Action immédiate requise avant toute mise sur le marché
- **Élevé** — Action requise, plan de mitigation à documenter
- **Modéré** — Surveillance et mitigation proportionnée
- **Faible / Négligeable** — Acceptable, documentation de la justification

---

## 2. Risques radio (émissions 2,4 GHz)

### 2.1 Dépassement de puissance d'émission

| Paramètre | Valeur |
|---|---|
| Impact | Élevé |
| Probabilité | Faible |
| **Niveau de risque** | **Modéré** |

**Description :** Le module ESP32-S3-WROOM-1 émet en Wi-Fi 802.11 b/g/n sur la bande 2400–2483,5 MHz. Un dépassement de la puissance e.i.r.p. maximale autorisée (20 dBm en Europe, ETSI EN 300 328) constituerait une non-conformité RED article 3.2.

**Mitigation :**
- Le module ESP32-S3-WROOM-1 est **pré-certifié** par Espressif (RED, FCC, IC). La puissance TX est calibrée en usine et limitée à 20 dBm par le firmware Espressif.
- Le produit final utilise l'antenne PCB intégrée au module — pas d'antenne externe modifiée.
- Vérification : s'assurer que `esp_wifi_set_max_tx_power()` n'est pas appelée avec une valeur supérieure à 80 (= 20 dBm) dans le firmware.
- Le firmware actuel ne modifie pas la puissance TX par défaut.

**Risque résiduel :** Faible. La pré-certification du module couvre ce risque sous réserve de ne pas modifier les paramètres RF.

### 2.2 Émissions hors bande / harmoniques

| Paramètre | Valeur |
|---|---|
| Impact | Moyen |
| Probabilité | Faible |
| **Niveau de risque** | **Faible** |

**Description :** Le PCB du produit final peut influencer les émissions parasites (rayonnement par les pistes, harmoniques du quartz, etc.).

**Mitigation :**
- La partie RF (antenne, réseau d'adaptation, blindage) est entièrement contenue dans le module WROOM-1 pré-certifié.
- Respect des recommandations de routage Espressif : zone d'exclusion autour de l'antenne, plan de masse continu sous le module.
- Test EMC du produit final requis (voir test_plan_radio_emc.md).

---

## 3. Risques de sécurité électrique

### 3.1 Tension d'alimentation

| Paramètre | Valeur |
|---|---|
| Impact | Faible |
| Probabilité | Faible |
| **Niveau de risque** | **Négligeable** |

**Description :** L'appareil est alimenté en USB-C 5 V DC, régulé à 3,3 V par un AMS1117-3.3. Les tensions en jeu sont toutes inférieures à 50 V DC (seuil TBTS/SELV selon IEC 62368-1).

**Mitigation :**
- Alimentation TBTS (Très Basse Tension de Sécurité) : 5 V max en entrée, 3,3 V interne.
- Pas de connexion au secteur — l'adaptateur USB est un produit tiers déjà certifié CE.
- Protection thermique intégrée dans l'AMS1117.
- Condensateurs de découplage conformes aux recommandations du datasheet.

**Risque résiduel :** Négligeable. Le produit est exempt des exigences de sécurité liées aux hautes tensions. L'article 3.1(a) de la RED (sécurité) est couvert de manière simplifiée par la conception basse tension.

### 3.2 Risque thermique

| Paramètre | Valeur |
|---|---|
| Impact | Moyen |
| Probabilité | Faible |
| **Niveau de risque** | **Faible** |

**Description :** L'AMS1117-3.3 dissipe environ (5,0 − 3,3) × I mW. À 500 mA (pic WiFi + audio), ~850 mW de dissipation thermique.

**Mitigation :**
- Le LDO est spécifié pour 1 A avec protection thermique interne (shutdown à ~165°C).
- La consommation typique est inférieure à 300 mA (dissipation ~500 mW).
- Le boîtier de l'installation artistique assure une ventilation passive suffisante.
- Pour les versions futures : envisager un régulateur à découpage pour réduire la dissipation.

---

## 4. Risques de cybersécurité

### 4.1 Communication HTTP non chiffrée

| Paramètre | Valeur |
|---|---|
| Impact | Élevé |
| Probabilité | Moyenne |
| **Niveau de risque** | **Élevé** |

**Description :** La communication avec le serveur backend Mascarade se fait actuellement en HTTP clair. Un attaquant sur le réseau local peut intercepter les commandes, les flux audio, et potentiellement injecter des réponses malveillantes.

**Impact réglementaire :** Non-conformité potentielle avec la RED article 3.3(d) (protection du réseau) et EN 18031-1 (sécurité réseau).

**Mitigation :**
- **Court terme :** Le produit fonctionne sur un réseau WiFi dédié à l'installation artistique, non connecté à Internet public. Le risque d'attaque réseau est réduit par l'isolement physique.
- **Moyen terme (avant mise sur le marché) :** Implémenter TLS 1.3 (RFC 8446) pour toutes les communications avec le backend. ESP-IDF supporte mbedTLS nativement.
- **Échéance :** Avant le passage au profil `iot_wifi_eu` (marquage CE).

### 4.2 OTA sans signature

| Paramètre | Valeur |
|---|---|
| Impact | Élevé |
| Probabilité | Moyenne |
| **Niveau de risque** | **Élevé** |

**Description :** Les mises à jour firmware OTA sont téléchargées en HTTP sans vérification de signature. Un attaquant pourrait distribuer un firmware malveillant via un serveur compromis ou une attaque man-in-the-middle.

**Impact réglementaire :** Non-conformité avec RED article 3.3(d) et EN 18031-1 (intégrité des mises à jour logicielles).

**Mitigation :**
- **Court terme :** Les mises à jour OTA ne sont déclenchées que manuellement par l'installateur sur le réseau local dédié.
- **Moyen terme :** Implémenter la signature des images OTA avec vérification RSA-2048 ou ECDSA-256. ESP-IDF fournit `esp_secure_boot_v2` et le support de la signature d'image OTA.
- **Moyen terme :** Distribuer les mises à jour via HTTPS.
- **Échéance :** Avant le passage au profil `iot_wifi_eu`.

### 4.3 Portail captif — authentification basique

| Paramètre | Valeur |
|---|---|
| Impact | Moyen |
| Probabilité | Faible |
| **Niveau de risque** | **Faible** |

**Description :** Le portail captif de configuration utilise une authentification basique sans HTTPS. Les identifiants transitent en clair sur le réseau local.

**Mitigation :**
- Le portail n'est accessible que sur le réseau WiFi local de l'appareil (mode AP).
- Portée physique limitée (~30 m).
- Prévision : migrer vers HTTPS auto-signé pour le portail captif ou utiliser un mécanisme de token temporaire.

### 4.4 Vulnérabilité XSS (corrigée)

| Paramètre | Valeur |
|---|---|
| Impact | Moyen |
| Probabilité | Faible |
| **Niveau de risque** | **Faible** |

**Description :** Une vulnérabilité XSS a été identifiée et corrigée dans l'interface web embarquée.

**Mitigation :** Correctif appliqué. Validation des entrées utilisateur systématique. Revue de code à chaque modification de l'interface web.

---

## 5. Risques CEM (compatibilité électromagnétique)

### 5.1 Émissions conduites et rayonnées

| Paramètre | Valeur |
|---|---|
| Impact | Moyen |
| Probabilité | Moyenne |
| **Niveau de risque** | **Modéré** |

**Description :** Le produit final (PCB + écran LCD SPI + amplificateur audio I2S + alimentation USB) peut générer des émissions parasites au-delà des limites EN 55032 Classe B.

**Sources potentielles :**
- Horloge SPI de l'écran LCD (jusqu'à 80 MHz)
- Bus I2S audio (horloge bit clock ~3 MHz)
- Alimentation à découpage du port USB (si l'adaptateur injecte du bruit)
- Rayonnement du câble USB-C (antenne non intentionnelle)

**Mitigation :**
- Condensateurs de découplage sur chaque rail d'alimentation (100 nF + 10 µF).
- Plan de masse continu sur les couches internes du PCB.
- Traces SPI et I2S courtes avec retour de masse proche.
- Filtrage CEM sur le connecteur USB-C (ferrite ou filtre LC si nécessaire).
- **Test EMC en laboratoire accrédité requis** (voir test_plan_radio_emc.md).

### 5.2 Immunité

| Paramètre | Valeur |
|---|---|
| Impact | Faible |
| Probabilité | Faible |
| **Niveau de risque** | **Négligeable** |

**Description :** Le produit doit résister aux perturbations électromagnétiques de son environnement (EN 55035 / ETSI EN 301 489-17).

**Mitigation :**
- Le module ESP32-S3-WROOM-1 est blindé et testé par Espressif.
- Le contexte d'utilisation (installation artistique intérieure) est un environnement CEM bénin.
- Test d'immunité à prévoir dans la campagne EMC.

---

## 6. Risques environnementaux

### 6.1 Conformité RoHS

| Paramètre | Valeur |
|---|---|
| Impact | Élevé |
| Probabilité | Faible |
| **Niveau de risque** | **Modéré** |

**Description :** Le produit doit respecter la directive RoHS 2011/65/EU (restriction de substances dangereuses : plomb, mercure, cadmium, chrome VI, PBB, PBDE, phtalates DEHP/BBP/DBP/DIBP).

**Mitigation :**
- Tous les composants sont approvisionnés chez des fabricants déclarant la conformité RoHS (Espressif, Texas Instruments, TDK, AMS, Samsung, Murata).
- Collecte des déclarations RoHS fournisseurs (voir supply_chain_declarations.md).
- Assemblage en soudure sans plomb (SAC305).

### 6.2 Conformité REACH

| Paramètre | Valeur |
|---|---|
| Impact | Moyen |
| Probabilité | Faible |
| **Niveau de risque** | **Faible** |

**Description :** Obligation de déclaration si un article contient une substance SVHC (Candidate List) à plus de 0,1% en masse.

**Mitigation :**
- Collecte des déclarations REACH/SVHC auprès des fournisseurs de composants.
- Les composants électroniques standards (MCU, résistances, condensateurs) ne contiennent généralement pas de SVHC au-delà du seuil.
- Veille sur les mises à jour de la Candidate List ECHA.

### 6.3 Obligations WEEE

| Paramètre | Valeur |
|---|---|
| Impact | Moyen |
| Probabilité | Faible |
| **Niveau de risque** | **Faible** |

**Description :** En tant que producteur d'EEE mis sur le marché EU, obligation d'enregistrement WEEE et de financement de la collecte et du recyclage.

**Mitigation :**
- Volume de production très faible (petite série pour installations artistiques).
- Enregistrement producteur nécessaire dans chaque État membre de mise sur le marché.
- Pour la France : enregistrement auprès d'un éco-organisme agréé (Ecosystem ou Ecologic).
- Marquage poubelle barrée sur le produit.

---

## 7. Synthèse des risques

| # | Risque | Impact | Probabilité | Niveau | Statut |
|---|---|---|---|---|---|
| 2.1 | Puissance TX excessive | Élevé | Faible | Modéré | Couvert (module pré-certifié) |
| 2.2 | Émissions hors bande | Moyen | Faible | Faible | Couvert (module pré-certifié) |
| 3.1 | Tension alimentation | Faible | Faible | Négligeable | Couvert (TBTS < 50V) |
| 3.2 | Dissipation thermique LDO | Moyen | Faible | Faible | Couvert (protection thermique) |
| 4.1 | HTTP non chiffré | Élevé | Moyenne | **Élevé** | **Action requise — TLS** |
| 4.2 | OTA sans signature | Élevé | Moyenne | **Élevé** | **Action requise — signature OTA** |
| 4.3 | Portail captif basique | Moyen | Faible | Faible | Acceptable (réseau local) |
| 4.4 | XSS (corrigée) | Moyen | Faible | Faible | Corrigé |
| 5.1 | Émissions CEM | Moyen | Moyenne | Modéré | **Test labo requis** |
| 5.2 | Immunité CEM | Faible | Faible | Négligeable | Test labo à confirmer |
| 6.1 | RoHS | Élevé | Faible | Modéré | Déclarations fournisseurs |
| 6.2 | REACH/SVHC | Moyen | Faible | Faible | Déclarations fournisseurs |
| 6.3 | WEEE | Moyen | Faible | Faible | Enregistrement producteur |

---

## 8. Actions prioritaires avant mise sur le marché

1. **Implémenter TLS 1.3** pour les communications backend (risque 4.1)
2. **Implémenter la signature OTA** avec vérification cryptographique (risque 4.2)
3. **Réaliser les tests EMC** en laboratoire accrédité (risque 5.1)
4. **Collecter les déclarations RoHS/REACH** de tous les fournisseurs (risque 6.1, 6.2)
5. **Enregistrement WEEE** dans les pays de commercialisation (risque 6.3)
6. **Passer le profil compliance** de `prototype` à `iot_wifi_eu` après résolution des actions ci-dessus
