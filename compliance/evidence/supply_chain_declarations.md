# Déclarations chaîne d'approvisionnement — Kill_LIFE

**Produit :** Kill_LIFE — Radio internet pilotée par la voix
**Version :** 1.0
**Date :** 2026-03-25
**Auteur :** Équipe KXKM / L'électron rare
**Directives couvertes :** RoHS 2011/65/EU, REACH (CE) 1907/2006, WEEE 2012/19/EU

---

## 1. Inventaire des composants principaux

| Composant | Référence | Fabricant | Fonction |
|---|---|---|---|
| MCU/WiFi | ESP32-S3-WROOM-1-N16R8 | Espressif Systems | Microcontrôleur + radio WiFi |
| LDO | AMS1117-3.3 | Advanced Monolithic Systems | Régulateur de tension 5V → 3,3V |
| DAC audio | PCM5101A | Texas Instruments | Convertisseur I2S → analogique |
| Microphone MEMS | ICS-43434 | TDK InvenSense | Capture audio I2S |
| Écran LCD | Module LCD SPI 1,85" | Waveshare (ou équivalent) | Affichage |
| Connecteur USB-C | USB Type-C | Divers (Molex, JAE, etc.) | Alimentation + données |
| Condensateurs | Céramiques MLCC | Samsung Electro-Mechanics, Murata | Découplage, filtrage |
| Résistances | Chip resistors | Yageo, Samsung | Pull-up, diviseurs, limitation |
| Inductances | Ferrites, inductances CMS | Murata, TDK | Filtrage CEM |
| PCB | FR-4 4 couches (estimé) | Fabricant PCB (JLCPCB, Eurocircuits, etc.) | Support mécanique et électrique |

---

## 2. Conformité RoHS (Directive 2011/65/EU)

### 2.1 Exigences

La directive RoHS restreint l'utilisation des substances suivantes dans les équipements électriques et électroniques (EEE) :

| Substance | Seuil maximal (% masse dans matériau homogène) |
|---|---|
| Plomb (Pb) | 0,1% |
| Mercure (Hg) | 0,1% |
| Cadmium (Cd) | 0,01% |
| Chrome hexavalent (Cr VI) | 0,1% |
| PBB (polybromobiphényles) | 0,1% |
| PBDE (polybromodiphényléthers) | 0,1% |
| DEHP (phtalate) | 0,1% |
| BBP (phtalate) | 0,1% |
| DBP (phtalate) | 0,1% |
| DIBP (phtalate) | 0,1% |

### 2.2 Déclarations fournisseurs — État de collecte

| Composant | Fabricant | Déclaration RoHS | Statut |
|---|---|---|---|
| ESP32-S3-WROOM-1-N16R8 | Espressif Systems | Disponible sur espressif.com — section « Certificates » | **À télécharger** |
| AMS1117-3.3 | Advanced Monolithic Systems | Déclaration RoHS standard disponible via distributeur | **À collecter** |
| PCM5101A | Texas Instruments | Disponible sur ti.com — section Environmental & Export | **À télécharger** |
| ICS-43434 | TDK InvenSense | Disponible sur invensense.tdk.com ou via distributeur | **À télécharger** |
| Condensateurs MLCC | Samsung Electro-Mechanics | Déclarations batch via distributeur (Digi-Key, Mouser) | **À collecter** |
| Résistances | Yageo / Samsung | Déclarations disponibles sur sites fabricants | **À collecter** |
| Inductances / Ferrites | Murata / TDK | Déclarations disponibles sur murata.com, tdk.com | **À collecter** |
| Connecteur USB-C | Molex / JAE | Déclaration RoHS standard | **À collecter** |
| PCB FR-4 | Fabricant PCB | Déclaration RoHS du fabricant (matériau de base, finition) | **À collecter** |

### 2.3 Actions requises

1. **Télécharger** les déclarations RoHS des fabricants principaux (Espressif, TI, TDK) depuis leurs sites web
2. **Demander** aux distributeurs (Mouser, Digi-Key, LCSC) les déclarations RoHS pour les composants passifs
3. **Vérifier** la finition du PCB : privilégier ENIG (Electroless Nickel Immersion Gold) ou OSP (Organic Solderability Preservatives) — finitions sans plomb
4. **Confirmer** l'utilisation de soudure sans plomb SAC305 (Sn96.5/Ag3.0/Cu0.5) pour l'assemblage
5. **Archiver** toutes les déclarations dans le dossier technique (conservation 10 ans)

### 2.4 Exemptions applicables

Vérifier si des exemptions de l'Annexe III de la RoHS s'appliquent :
- Exemption 7(a) : plomb dans le verre des composants électroniques (applicable aux MLCC si couches internes contiennent du plomb — en général non applicable pour les composants modernes)
- Exemption 7(c)-I : composants électriques/électroniques contenant du plomb dans le verre ou la céramique (condensateurs piézoélectriques)

**Note :** Les composants sélectionnés sont tous disponibles en version RoHS-conforme chez les fabricants listés. Aucune exemption ne devrait être nécessaire.

---

## 3. Conformité REACH (Règlement (CE) 1907/2006)

### 3.1 Obligations

En tant que producteur d'un **article** au sens de REACH :
- **Obligation de déclaration** si un article contient une substance de la Candidate List (SVHC) à une concentration supérieure à **0,1% en masse**
- **Obligation de notification** à l'ECHA si le tonnage dépasse 1 tonne/an par SVHC (non applicable ici vu les faibles volumes)
- **Obligation d'information** au client sur demande (délai : 45 jours)

### 3.2 Screening SVHC

| Composant | Fabricant | Déclaration SVHC/REACH | Statut |
|---|---|---|---|
| ESP32-S3-WROOM-1 | Espressif | Déclaration REACH disponible | **À télécharger** |
| PCM5101A | Texas Instruments | Environmental data disponible sur ti.com | **À télécharger** |
| ICS-43434 | TDK InvenSense | Déclaration disponible via portail compliance | **À collecter** |
| AMS1117-3.3 | Advanced Monolithic Systems | Via distributeur | **À collecter** |
| Passifs (MLCC, résistances) | Samsung, Yageo, Murata | Déclarations matériaux disponibles | **À collecter** |
| PCB FR-4 | Fabricant PCB | Déclaration matériau de base | **À collecter** |

### 3.3 Risques SVHC identifiés

Pour les composants électroniques standards (semi-conducteurs, passifs CMS, connecteurs), les SVHC les plus couramment surveillées sont :
- **Plomb** dans les soudures internes des composants (normalement sous les seuils RoHS)
- **DEHP et phtalates** dans les isolants de câbles (câble USB-C fourni — vérifier déclaration fournisseur)
- **Cobalt compounds** dans certaines batteries (non applicable — pas de batterie)

**Évaluation :** Risque faible. Les composants sélectionnés sont des produits industriels standards de fabricants majeurs qui maintiennent la conformité REACH.

### 3.4 Actions requises

1. Collecter les déclarations SVHC des fournisseurs principaux
2. Vérifier la conformité REACH du câble USB-C fourni (si applicable)
3. Mettre en place une veille sur les mises à jour de la Candidate List ECHA (mise à jour semestrielle, environ juin et décembre)
4. Archiver les déclarations dans le dossier technique

---

## 4. Obligations WEEE (Directive 2012/19/EU)

### 4.1 Classification du produit

- **Catégorie WEEE :** Catégorie 4 — Matériel grand public et panneaux photovoltaïques (ou Catégorie 6 — Équipements informatiques et de télécommunications, selon l'interprétation)
- **Type :** Appareil fixe (installation artistique)
- **Usage :** Professionnel (B2B, installations artistiques)

### 4.2 Obligations du producteur

En tant que **producteur** d'EEE mis sur le marché de l'UE :

| Obligation | Description | Statut |
|---|---|---|
| **Enregistrement producteur** | S'enregistrer auprès du registre national dans chaque État membre de mise sur le marché | **À faire** |
| **Éco-organisme** | Adhérer à un éco-organisme agréé pour le financement de la collecte et du traitement | **À faire** |
| **Marquage** | Apposer le symbole de la poubelle barrée sur le produit (Annexe IX, Directive 2012/19/EU) | **À faire** |
| **Information utilisateur** | Fournir des instructions de fin de vie dans la documentation produit | **À faire** |
| **Déclaration annuelle** | Déclarer les quantités mises sur le marché annuellement | **Annuel** |

### 4.3 Enregistrement par pays cible

| Pays | Organisme d'enregistrement | Éco-organismes agréés | Statut |
|---|---|---|---|
| **France** | ADEME (registre des producteurs, SYDEREP) | Ecosystem, Ecologic | **À enregistrer** |
| **Autres pays UE** | Selon les marchés visés | Variable par pays | **À définir** |

### 4.4 Cas petite série / installation artistique

**Considérations spécifiques :**
- Les volumes sont très faibles (quelques dizaines d'unités)
- La mise sur le marché est principalement en France (installations L'électron rare)
- L'enregistrement producteur est **obligatoire même pour de petits volumes**
- L'éco-contribution est calculée au poids et très faible pour des petits appareils électroniques (ordre de grandeur : quelques centimes par unité)
- Certains éco-organismes proposent des tarifs adaptés aux petits producteurs

### 4.5 Actions requises

1. **S'enregistrer sur SYDEREP** (registre ADEME) en tant que producteur d'EEE
2. **Adhérer à un éco-organisme** (Ecosystem ou Ecologic) — contacter pour un devis petit producteur
3. **Intégrer le marquage poubelle barrée** dans le design du boîtier ou de l'étiquette produit
4. **Préparer la notice** d'information fin de vie pour l'utilisateur final

---

## 5. Synthèse et plan d'action

### 5.1 Documents à collecter

| Document | Source | Priorité |
|---|---|---|
| Certificat RoHS ESP32-S3-WROOM-1 | espressif.com | Haute |
| Certificat RoHS PCM5101A | ti.com | Haute |
| Certificat RoHS ICS-43434 | invensense.tdk.com | Haute |
| Déclaration RoHS AMS1117-3.3 | Distributeur (Mouser/Digi-Key) | Haute |
| Déclarations RoHS passifs | Distributeur ou fabricant | Moyenne |
| Déclarations REACH/SVHC (tous composants) | Fabricants / distributeurs | Moyenne |
| Certificat RED module ESP32-S3-WROOM-1 | espressif.com | Haute |

### 5.2 Enregistrements à effectuer

| Action | Organisme | Priorité |
|---|---|---|
| Enregistrement producteur WEEE France | ADEME / SYDEREP | Haute (avant mise sur le marché) |
| Adhésion éco-organisme | Ecosystem ou Ecologic | Haute (avant mise sur le marché) |

### 5.3 Marquages produit

| Marquage | Requis par | Emplacement |
|---|---|---|
| **CE** | RED 2014/53/EU | Produit + emballage + documentation |
| **Poubelle barrée** | WEEE 2012/19/EU | Produit (étiquette ou gravure) |
| **Identifiant producteur** | WEEE | Documentation |
| **Référence module radio** | RED | Documentation technique |

---

## 6. Archivage

Tous les documents collectés doivent être archivés dans le dossier technique du produit et conservés pendant **10 ans** minimum après la dernière mise sur le marché (exigence RED article 21, RoHS article 7).

Structure d'archivage recommandée :
```
compliance/
  evidence/
    supply_chain/
      rohs/
        espressif_esp32s3_rohs.pdf
        ti_pcm5101a_rohs.pdf
        tdk_ics43434_rohs.pdf
        ams_ams1117_rohs.pdf
        passifs_rohs/
      reach/
        espressif_esp32s3_reach.pdf
        ti_pcm5101a_reach.pdf
        ...
      weee/
        syderep_registration.pdf
        eco_organisme_contrat.pdf
      red_module/
        espressif_esp32s3_wroom1_red_cert.pdf
```
