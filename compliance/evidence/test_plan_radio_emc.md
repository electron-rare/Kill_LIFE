# Plan de test radio et CEM — Kill_LIFE

**Produit :** Kill_LIFE — Radio internet pilotée par la voix
**Version :** 1.0
**Date :** 2026-03-25
**Auteur :** Équipe KXKM / L'électron rare
**Module radio :** ESP32-S3-WROOM-1-N16R8 (Espressif Systems)

---

## 1. Stratégie de test

### 1.1 Approche module pré-certifié

Le module ESP32-S3-WROOM-1 est **pré-certifié** par Espressif Systems pour les réglementations suivantes :

| Certification | Référence | Couverture |
|---|---|---|
| **EU RED** (CE) | Certificats Espressif sur espressif.com | ETSI EN 300 328, ETSI EN 301 489-17, EN 62368-1 |
| **FCC** | FCC ID : 2AC7Z-ESPS3WROOM1 | Part 15 Subpart C |
| **IC** (Canada) | IC : 21098-ESPS3WROOM1 | RSS-247 |

**Conséquence :** Les tests radio intrinsèques (puissance TX, occupation spectrale, largeur de bande, taux d'erreur) **ne nécessitent pas de re-test** au niveau du produit final, sous réserve que :

1. L'antenne intégrée au module (antenne PCB) est utilisée sans modification
2. Aucune antenne externe n'est ajoutée
3. La zone d'exclusion autour de l'antenne (recommandations Espressif) est respectée sur le PCB hôte
4. Les paramètres RF du firmware ne dépassent pas les limites certifiées (puissance TX ≤ 20 dBm)
5. Le plan de masse du PCB hôte respecte les recommandations du Hardware Design Guidelines Espressif

### 1.2 Tests requis pour le produit final

Malgré la pré-certification du module, le **produit assemblé** (PCB hôte + module + LCD + audio + alimentation + boîtier) doit passer des tests CEM au niveau système :

| Catégorie | Normes applicables | Obligatoire |
|---|---|---|
| Émissions rayonnées | EN 55032:2015/A11:2020 (Classe B) | Oui |
| Émissions conduites | EN 55032:2015/A11:2020 (Classe B) | Oui |
| Immunité rayonnée | EN 55035:2017/A11:2020 | Oui |
| Immunité conduites | EN 55035:2017/A11:2020 | Oui |
| CEM spécifique radio | ETSI EN 301 489-17 V3.3.1 | Oui |
| Radio (spectre) | ETSI EN 300 328 V2.2.2 | Couvert par module |

---

## 2. Plan de test CEM — Émissions

### 2.1 Émissions rayonnées (EN 55032 Classe B)

**Objectif :** Vérifier que les émissions électromagnétiques rayonnées du produit final respectent les limites Classe B (environnement résidentiel).

**Configuration de test :**
- Échantillon : 1 unité de production (ou pré-série représentative)
- État de fonctionnement : WiFi connecté, streaming audio actif, écran LCD allumé
- Alimentation : adaptateur USB-C représentatif de l'utilisation finale
- Câblage : câble USB-C de longueur typique (1 m), câble audio si applicable

**Procédure :**
1. Placer l'EUT (Equipment Under Test) sur la table de test en chambre semi-anéchoïque (SAC) ou OATS
2. Configurer l'EUT en mode streaming audio WiFi (pire cas d'émission)
3. Balayer les fréquences de **30 MHz à 1 GHz** (scan préliminaire en quasi-peak)
4. Balayer **1 GHz à 6 GHz** (peak detector)
5. Mesurer les niveaux maximaux détectés et comparer aux limites EN 55032 Classe B
6. Effectuer des mesures finales en quasi-peak et average sur les fréquences critiques

**Limites applicables (EN 55032 Classe B, 10 m) :**
- 30–230 MHz : 30 dBµV/m (quasi-peak)
- 230–1000 MHz : 37 dBµV/m (quasi-peak)
- 1–3 GHz : 50 dBµV/m (peak), 40 dBµV/m (average)
- 3–6 GHz : 54 dBµV/m (peak), 44 dBµV/m (average)

### 2.2 Émissions conduites (EN 55032 Classe B)

**Objectif :** Vérifier les émissions conduites sur le port d'alimentation USB.

**Configuration de test :**
- LISN (Line Impedance Stabilization Network) sur l'alimentation USB 5V
- Mêmes conditions de fonctionnement que 2.1

**Procédure :**
1. Connecter l'alimentation USB via le LISN
2. Balayer **150 kHz à 30 MHz**
3. Mesurer en quasi-peak et average

**Limites applicables (EN 55032 Classe B) :**
- 150 kHz–500 kHz : 66–56 dBµV (quasi-peak), 56–46 dBµV (average)
- 500 kHz–5 MHz : 56 dBµV (quasi-peak), 46 dBµV (average)
- 5–30 MHz : 60 dBµV (quasi-peak), 50 dBµV (average)

**Note :** L'alimentation USB-C est un produit tiers. Les émissions conduites mesurées incluent la contribution de l'adaptateur. Utiliser un adaptateur représentatif de qualité CE.

---

## 3. Plan de test CEM — Immunité

### 3.1 Tests d'immunité (EN 55035 / ETSI EN 301 489-17)

| Test | Norme de base | Niveau | Critère |
|---|---|---|---|
| Décharges électrostatiques (ESD) | IEC 61000-4-2 | ±4 kV contact, ±8 kV air | Critère B |
| Champ RF rayonné | IEC 61000-4-3 | 3 V/m (80 MHz–6 GHz) | Critère A |
| Transitoires rapides (EFT/Burst) | IEC 61000-4-4 | ±1 kV sur port alimentation | Critère B |
| Surge | IEC 61000-4-5 | ±0,5 kV ligne-ligne | Critère B |
| Immunité conduite RF | IEC 61000-4-6 | 3 V (150 kHz–80 MHz) | Critère A |
| Creux de tension | IEC 61000-4-11 | Selon EN 55035 | Critère B/C |

**Critères de performance :**
- **Critère A :** Fonctionnement normal pendant le test (streaming audio sans interruption)
- **Critère B :** Dégradation temporaire acceptée, récupération automatique après le test
- **Critère C :** Perte de fonction temporaire, intervention utilisateur acceptée pour redémarrer

**Configuration de test :**
- EUT en mode streaming WiFi actif
- Surveiller : connexion WiFi maintenue, audio continu, écran fonctionnel
- Documenter tout redémarrage, perte de connexion, ou artefact audio/visuel

---

## 4. Test radio — ETSI EN 300 328

### 4.1 Couverture par la pré-certification du module

Les tests suivants sont couverts par la certification Espressif du module ESP32-S3-WROOM-1 :

- Puissance e.i.r.p. maximale (≤ 20 dBm)
- Densité spectrale de puissance
- Occupation de bande (99% BW)
- Émissions non désirées dans la bande et hors bande
- Mécanisme d'accès adaptatif (écoute avant émission / LBT ou équivalent pour FHSS/DSSS)

### 4.2 Vérifications au niveau produit final

Bien que la re-certification radio ne soit pas requise, les vérifications suivantes sont recommandées :

1. **Vérification de la configuration WiFi firmware :**
   - `esp_wifi_set_max_tx_power()` : valeur ≤ 80 (= 20 dBm)
   - Mode : 802.11 b/g/n uniquement (2,4 GHz)
   - Pas de mode 5 GHz activé (l'ESP32-S3 ne le supporte pas de toute façon)
   - Canaux configurés : 1–13 (Europe, non 14 qui est Japon uniquement)

2. **Vérification de l'intégrité de l'antenne :**
   - Zone d'exclusion respectée (pas de cuivre, pas de composant à moins de 15 mm du bord d'antenne)
   - Plan de masse continu sous le module sauf zone d'exclusion d'antenne
   - Pas de boîtier métallique couvrant l'antenne

3. **Mesure de puissance optionnelle :**
   - Si un doute existe, une mesure rapide de puissance TX en conduit (via connecteur U.FL sur module de test) peut confirmer la conformité

---

## 5. Exigences laboratoire

### 5.1 Accréditation

Les tests CEM doivent être réalisés par un **laboratoire accrédité** :
- Accréditation **ISO/IEC 17025** pour les normes concernées
- Idéalement notifié RED (Organisme Notifié) si une évaluation par tierce partie est requise
- Pour une auto-déclaration (module A, Annexe II de la RED), un laboratoire accrédité 17025 suffit

### 5.2 Laboratoires recommandés (France)

| Laboratoire | Localisation | Spécialité |
|---|---|---|
| EMITECH | Montigny-le-Bretonneux (78) | CEM, Radio, RED |
| Bureau Veritas LCIE | Fontenay-aux-Roses (92) | CEM, Sécurité, RED |
| SOPEMEA | Vélizy-Villacoublay (78) | CEM, Environnement |
| NEXIO (ex-Agipi) | Toulouse (31) | CEM, Radio |

**Note :** Pour un produit basé sur un module pré-certifié avec alimentation basse tension, la campagne de test CEM est généralement courte (2–3 jours) et peu coûteuse (estimation : 2 000–4 000 EUR).

### 5.3 Équipements de pré-test (optionnel, en interne)

Pour limiter les risques d'échec au laboratoire, un pré-test informel peut être réalisé avec :
- Récepteur EMI de base ou analyseur de spectre avec pré-amplificateur
- Antenne biconique (30–300 MHz) et antenne log-périodique (300 MHz–3 GHz)
- LISN USB pour les conduites
- Environnement : pièce calme (pas de chambre anéchoïque nécessaire pour un pré-screening)

---

## 6. Documentation à fournir au laboratoire

1. **Dossier technique produit :**
   - Schéma électronique
   - Layout PCB (Gerbers)
   - BOM (Bill of Materials)
   - Description fonctionnelle du produit

2. **Certificats module :**
   - Certificat RED du module ESP32-S3-WROOM-1 (disponible sur espressif.com)
   - Rapports de test radio du module (si disponibles auprès d'Espressif)

3. **Configuration de test :**
   - Modes de fonctionnement à tester (streaming WiFi, veille, OTA)
   - Adaptateur USB-C utilisé
   - Firmware version exacte

4. **Échantillons :**
   - 2 unités minimum (1 pour les tests, 1 de secours)
   - Avec tous les câbles et accessoires représentatifs

---

## 7. Procédure de conformité RED (module A — auto-déclaration)

Pour un produit utilisant un module radio pré-certifié, la procédure d'évaluation de conformité la plus courante est le **module A (contrôle interne de la fabrication)** — Annexe II de la RED :

1. Réaliser les tests CEM du produit final (sections 2 et 3 ci-dessus)
2. Préparer le dossier technique (documentation technique selon article 21 RED)
3. Rédiger la **Déclaration UE de Conformité** (DoC)
4. Apposer le **marquage CE** sur le produit
5. Désigner un **responsable de la mise sur le marché** (fabricant ou importateur dans l'UE)
6. Conserver le dossier technique pendant **10 ans** après la mise sur le marché

**Note :** Si les normes harmonisées ne couvrent pas toutes les exigences essentielles (notamment EN 18031 avec restrictions), un Organisme Notifié (module B+C) peut être nécessaire. Vérifier le statut des restrictions publiées au JOUE 2025/138.
