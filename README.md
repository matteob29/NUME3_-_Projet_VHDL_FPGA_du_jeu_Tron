# NUME3 - Projet VHDL : Jeu Tron

[cite_start]Projet réalisé dans le cadre du module **NUME3 - Conception VHDL/FPGA** à l’**ENSEIRB-MATMECA**[cite: 458].

[cite_start]**Auteurs :** Mattéo BINET [cite: 461]  
[cite_start]Aurélien BARTHERE [cite: 462]  

[cite_start]**Date :** Janvier 2026 [cite: 459]  

---

## 1. Présentation du projet

[cite_start]L'objectif de ce projet est de recréer le célèbre jeu vidéo d'arcade **Tron** (sorti en 1982) sur une carte FPGA en utilisant le langage de description **VHDL**[cite: 468, 469].

Le principe du jeu consiste à diriger deux "motos" lumineuses qui laissent derrière elles une traînée de couleur. [cite_start]L'objectif est de pousser l'adversaire à percuter une traînée (la sienne ou celle de l'autre) ou les bords de l'écran[cite: 505, 506].

[cite_start]Le système a été implémenté et validé sur une carte de développement **Digilent NEXYS4 A7** équipée d'un FPGA Xilinx Artix-7[cite: 470].

---

## 2. Objectifs pédagogiques

- [cite_start]Concevoir une architecture système complète sur FPGA intégrant plusieurs blocs fonctionnels[cite: 471].
- [cite_start]Implémenter des machines à états (FSM) complexes pour la gestion du jeu et de la mémoire[cite: 515].
- [cite_start]Gérer l'affichage vidéo via un contrôleur **VGA** (320x240)[cite: 471].
- [cite_start]Maîtriser les contraintes de temps (Timing Analysis) et l'utilisation des ressources FPGA[cite: 521, 510].
- [cite_start]Utiliser l'environnement de développement **Xilinx Vivado** pour la synthèse et l'implémentation[cite: 472].

---

## 3. Cahier des charges

### 3.1 Comportement fonctionnel

Le système fonctionne selon les règles suivantes :
1. [cite_start]**Initialisation :** Le système démarre après le bitstream ou via un reset asynchrone (`rst = '1'`) activé par l'interrupteur J15[cite: 475].
2. [cite_start]**Déplacement :** Les deux joueurs (J1 et J2) se déplacent automatiquement à vitesse constante[cite: 504].
3. [cite_start]**Contrôles :** Chaque joueur dirige sa direction (Haut, Bas, Gauche, Droite) via des boutons poussoirs (J1) ou un module PMOD (J2)[cite: 503].
4. [cite_start]**Collision :** Si la tête du joueur touche une couleur différente du noir (mur ou traînée), il perd la partie[cite: 506, 619].

### 3.2 Contraintes de cadencement

[cite_start]Le système repose sur une horloge principale de **100 MHz** issue du quartz de la carte[cite: 477].
Pour gérer la vitesse du jeu, un signal d'activation (`clock enable`) est généré :

| Signal | Fréquence | Rôle |
|:---:|:---:|:---|
| `clk` | 100 MHz | [cite_start]Horloge système principale (VGA, logique) [cite: 477] |
| `ce_fsm` | 200 Hz | [cite_start]Cadence de déplacement des joueurs (50 pixels/sec) [cite: 479, 480] |

### 3.3 Interface d'Entrées/Sorties

| Type | Signal | Description |
|---|---|---|
| **Entrée** | `clk` | [cite_start]Horloge 100 MHz [cite: 485] |
| **Entrée** | `rst` | [cite_start]Reset asynchrone (Switch) [cite: 485] |
| **Entrée** | `Boutons` | [cite_start]Commandes directionnelles Joueur 1 [cite: 485] |
| **Entrée** | `PMOD` | [cite_start]Commandes directionnelles Joueur 2 [cite: 485] |
| **Sortie** | `VGA` | [cite_start]Signaux de synchronisation et couleurs (12 bits) [cite: 487] |
| **Sortie** | `LED` | [cite_start]Débogage (Visualisation des états des FSM) [cite: 487] |

---

## 4. Architecture matérielle

[cite_start]L'architecture est modulaire et s'articule autour d'un **Top Level** connectant les différents blocs[cite: 531].

### 4.1 Schéma des blocs principaux

| Module | Fonction principale |
|---|---|
| `Tableau_init` | [cite_start]Initialise l'écran (bords verts, fond noir) au démarrage[cite: 571, 572]. |
| `Reg_In` | [cite_start]Synchronise les entrées boutons (buffer) pour éviter la métastabilité[cite: 579]. |
| `Gest_freq` | Génère le signal `ce_fsm` à 200 Hz pour la vitesse du jeu[cite: 589]. |
| `fsm_pos_J1/J2` | [cite_start]Gère la position actuelle/future et détecte les collisions pour chaque joueur[cite: 617, 618]. |
| `fsm_rw` | [cite_start]**Bloc central** : Arbitre les accès mémoire (Lecture/Écriture) vers le VGA[cite: 650]. |
| `Mux_3` | [cite_start]Multiplexe les coordonnées et couleurs vers le contrôleur VGA[cite: 664]. |
| `vga_bitmap` | [cite_start]Contrôleur VGA gérant la mémoire vidéo et l'affichage physique[cite: 675]. |

### 4.2 Machine à états centrale (`fsm_rw`)

Le module `fsm_rw` est le chef d'orchestre du système. [cite_start]Il cycle automatiquement entre les états de lecture (détection de collision) et d'écriture (mise à jour de la position) lorsque `ce_fsm` est actif[cite: 651, 657].
[cite_start]Les états sont : `INIT`, `READ_1`, `WRITE_1`, `READ_2`, `WRITE_2`, `WIN_J1`, `WIN_J2`[cite: 660].

---

## 5. Performances et Ressources

### 5.1 Utilisation des ressources (Artix-7 XC7A100T)
[cite_start]Le projet utilise une partie modérée des ressources du FPGA, la majorité étant consommée par le contrôleur VGA[cite: 513].

| Ressource | Utilisation | % Utilisation |
|---|:---:|:---:|
| **LUT** | 403 | [cite_start]0.64 % [cite: 511] |
| **FF (Flip-Flops)** | 274 | [cite_start]0.22 % [cite: 511] |
| **BRAM** | 5 | [cite_start]3.70 % [cite: 511] |
| **IO** | 31 | [cite_start]14.76 % [cite: 511] |

### 5.2 Analyse Temporelle (Timing)
[cite_start]Le design respecte toutes les contraintes temporelles à 100 MHz[cite: 530].
- [cite_start]**Worst Negative Slack (Setup):** +3.480 ns[cite: 523].
- **Worst Hold Slack:** +0.07 ns.

---

## 6. Structure du dépôt

Le dépôt est organisé de la manière suivante :

- **[Annexes/](./Annexes)** : Documents complémentaires et datasheets.
- **[Rapport/](./Rapport)** : Rapport complet du projet (`NUME3___Projet_VHDL_FPGA_du_jeu_Tron.pdf`).
- **[Sources/](./Sources)** : Codes sources VHDL du projet (`top_level.vhd`, `fsm_pos.vhd`, etc.).
- **README.md** : Ce fichier.

---

© 2026 — Mattéo BINET, Aurélien BARTHERE  
Département Électronique — ENSEIRB-MATMECA
