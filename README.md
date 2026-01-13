# NUME3 - Projet VHDL : Jeu Tron

Projet réalisé dans le cadre du module **NUME3 - Conception VHDL/FPGA** à l’**ENSEIRB-MATMECA**.

**Auteurs :** Mattéo BINET   
Aurélien BARTHERE

**Date :** Janvier 2026

---

## 1. Présentation du projet

L'objectif de ce projet est de recréer le célèbre jeu vidéo d'arcade **Tron** (sorti en 1982) sur une carte FPGA en utilisant le langage de description **VHDL**.

Le principe du jeu consiste à diriger deux "motos" lumineuses qui laissent derrière elles une traînée de couleur. L'objectif est de pousser l'adversaire à percuter une traînée (la sienne ou celle de l'autre) ou les bords de l'écran.

Le système a été implémenté et validé sur une carte de développement **Digilent NEXYS4 A7** équipée d'un FPGA Xilinx Artix-7.

---

## 2. Objectifs pédagogiques

- Concevoir une architecture système complète sur FPGA intégrant plusieurs blocs fonctionnels.
- Implémenter des machines à états (FSM) complexes pour la gestion du jeu et de la mémoire.
- Gérer l'affichage vidéo via un contrôleur **VGA** (320x240).
- Maîtriser les contraintes de temps (Timing Analysis) et l'utilisation des ressources FPGA.
- Utiliser l'environnement de développement **Xilinx Vivado** pour la synthèse et l'implémentation.

---

## 3. Cahier des charges

### 3.1 Comportement fonctionnel

Le système fonctionne selon les règles suivantes :
1. **Initialisation :** Le système démarre après le bitstream ou via un reset asynchrone (`rst = '1'`) activé par l'interrupteur J15.
2. **Déplacement :** Les deux joueurs (J1 et J2) se déplacent automatiquement à vitesse constante.
3. **Contrôles :** Chaque joueur dirige sa direction (Haut, Bas, Gauche, Droite) via des boutons poussoirs (J1) ou un module PMOD (J2).
4. **Collision :** Si la tête du joueur touche une couleur différente du noir (mur ou traînée), il perd la partie.

### 3.2 Contraintes de cadencement

Le système repose sur une horloge principale de **100 MHz** issue du quartz de la carte.
Pour gérer la vitesse du jeu, un signal d'activation (`clock enable`) est généré :

| Signal | Fréquence | Rôle |
|:---:|:---:|:---|
| `clk` | 100 MHz | Horloge système principale (VGA, logique) |
| `ce_fsm` | 200 Hz | Cadence de déplacement des joueurs (50 pixels/sec)|

### 3.3 Interface d'Entrées/Sorties

| Type | Signal | Description |
|---|---|---|
| **Entrée** | `clk` | Horloge 100 MHz |
| **Entrée** | `rst` | Reset asynchrone (Switch) |
| **Entrée** | `Boutons` | Commandes directionnelles Joueur 1 |
| **Entrée** | `PMOD` | Commandes directionnelles Joueur 2 |
| **Sortie** | `VGA` | Signaux de synchronisation et couleurs (12 bits) |
| **Sortie** | `LED` | Débogage (Visualisation des états des FSM) |

---

## 4. Architecture matérielle

L'architecture est modulaire et s'articule autour d'un **Top Level** connectant les différents blocs.

### 4.1 Schéma des blocs principaux

| Module | Fonction principale |
|---|---|
| `Tableau_init` | Initialise l'écran (bords verts, fond noir) au démarrage |
| `Reg_In` | Synchronise les entrées boutons (buffer) pour éviter la métastabilité |
| `Gest_freq` | Génère le signal `ce_fsm` à 200 Hz pour la vitesse du jeu |
| `fsm_pos_J1/J2` | Gère la position actuelle/future et détecte les collisions pour chaque joueur. |
| `fsm_rw` | **Bloc central** : Arbitre les accès mémoire (Lecture/Écriture) vers le VGA. |
| `Mux_3` | Multiplexe les coordonnées et couleurs vers le contrôleur VGA. |
| `vga_bitmap` | Contrôleur VGA gérant la mémoire vidéo et l'affichage physique. |

### 4.2 Machine à états centrale (`fsm_rw`)

Le module `fsm_rw` est le chef d'orchestre du système. Il cycle automatiquement entre les états de lecture (détection de collision) et d'écriture (mise à jour de la position) lorsque `ce_fsm` est actif.
Les états sont : `INIT`, `READ_1`, `WRITE_1`, `READ_2`, `WRITE_2`, `WIN_J1`, `WIN_J2`.

---

## 5. Performances et Ressources

### 5.1 Utilisation des ressources (Artix-7 XC7A100T)
Le projet utilise une partie modérée des ressources du FPGA, la majorité étant consommée par le contrôleur VGA.

| Ressource | Utilisation | % Utilisation |
|---|:---:|:---:|
| **LUT** | 403 | 0.64 % |
| **FF (Flip-Flops)** | 274 | 0.22 % |
| **BRAM** | 5 | 3.70 % |
| **IO** | 31 | 14.76 % |

### 5.2 Analyse Temporelle (Timing)
Le design respecte toutes les contraintes temporelles à 100 MHz.
- **Worst Negative Slack (Setup):** +3.480 ns.
- **Worst Hold Slack:** +0.07 ns.

---

## 6. Structure du dépôt

Le dépôt est organisé de la manière suivante :

- **[Annexes/](./Annexes)** : Documents complémentaires et datasheets.
- **[Rapport/](./Rapport)** : Rapport complet du projet (`NUME3___Projet_VHDL_FPGA_du_jeu_Tron.pdf`).
- **[Sources/](./Sources)** : Codes sources VHDL du projet (`top_level.vhd`, `fsm_pos.vhd`, etc.).

---

© 2026 — Mattéo BINET, Aurélien BARTHERE  
Département Électronique — ENSEIRB-MATMECA
