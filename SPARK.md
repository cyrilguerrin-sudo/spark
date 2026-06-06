# CLAUDE.md — Spark App

## 1\. CONTEXTE DU PROJET

Spark est une application mobile Flutter (Android \+ iOS) anti-doomscrolling. Elle intercepte l'ouverture des réseaux sociaux et crée des rituels conscients d'intention, de session et de sortie.

**3 mécanismes core :**

1. Intention à l'ouverture — l'utilisateur choisit pourquoi il ouvre le réseau  
2. Contrat de session — il fixe une durée avant d'entrer  
3. Redirection de sortie — une sortie guidée quand le timer expire

**Mode Spark Focus :**

- L'utilisateur définit un objectif de travail \+ apps à bloquer  
- Si il tente d'ouvrir une app bloquée → écran de rappel avec sa to-do  
- Il doit cocher son objectif pour débloquer l'accès

---

## 2\. STACK TECHNIQUE

- **Framework** : Flutter (Dart)  
- **Cible** : Android \+ iOS (compiler sur Mac avec Xcode)  
- **État** : Provider ou Riverpod (choisir Riverpod pour la scalabilité)  
- **Storage local** : Hive (rapide, pas de SQL)  
- **Vidéo flamme** : video\_player  
- **Animations** : lottie (si export Lottie depuis AE) ou flutter\_animate  
- **Blocage apps** : android\_intent\_plus \+ usage\_stats (Android) / screen time, family control, intents (IOS)  
- **Navigation** : go\_router

**pubspec.yaml — dépendances :**

dependencies:

  flutter:

    sdk: flutter

  riverpod: ^2.5.1

  flutter\_riverpod: ^2.5.1

  hive: ^2.2.3

  hive\_flutter: ^1.1.0

  video\_player: ^2.8.1

  flutter\_animate: ^4.5.0

  go\_router: ^13.0.0

  android\_intent\_plus: ^4.0.2

  permission\_handler: ^11.3.0

  app\_usage: ^3.0.1

  intl: ^0.19.0

---

## 3\. DESIGN SYSTEM (extrait du Figma)

[https://www.figma.com/design/TxnAKO8YNWFRXeaCN13E4m/Maquette-final-coeur-de-Spark?node-id=0-1\&t=AOy40NaecgGo2bzv-1](https://www.figma.com/design/TxnAKO8YNWFRXeaCN13E4m/Maquette-final-coeur-de-Spark?node-id=0-1&t=AOy40NaecgGo2bzv-1)

**Couleurs :**

// Fond principal

static const Color bgPrimary \= Color(0xFF0A0A0A);

static const Color bgCard \= Color(0xFF111111);

static const Color bgCardBorder \= Color(0xFF1E1E1E);

// Accents

static const Color green \= Color(0xFF268429);      // Grâce à Spark / succès

static const Color greenLight \= Color(0xFF4CAF50); // Sessions respectées

static const Color red \= Color(0xFF843B26);        // Dépassement

static const Color orange \= Color(0xFFE05A3A);     // Focus actif / dépassement

// Texte

static const Color textPrimary \= Color(0xFFFFFFFF);

static const Color textSecondary \= Color(0xFFBBBBBB);

static const Color textMuted \= Color(0xFF555555);

**Typographie (Inter) :**

// Titre principal (ex: "Salut Cyril \!")

TextStyle titleLarge \= TextStyle(

  fontFamily: 'Inter',

  fontWeight: FontWeight.w800,

  fontSize: 32,

  fontStyle: FontStyle.italic,

  letterSpacing: \-1.6,

  color: Colors.white,

);

// Chiffre clé (ex: "2h12")

TextStyle metricLarge \= TextStyle(

  fontFamily: 'Inter',

  fontWeight: FontWeight.w800,

  fontSize: 50,

  letterSpacing: \-2.5,

);

// Label section (ex: "Sessions récentes")

TextStyle sectionLabel \= TextStyle(

  fontFamily: 'Inter',

  fontWeight: FontWeight.w700,

  fontSize: 18,

  letterSpacing: \-0.9,

  color: Color(0xFFBBBBBB),

);

// Corps texte

TextStyle body \= TextStyle(

  fontFamily: 'Inter',

  fontWeight: FontWeight.w500,

  fontSize: 14,

  letterSpacing: \-0.7,

  color: Color(0xFFBBBBBB),

);

**Border radius :**

- Cards : 20px  
- Boutons : 24px  
- Bottom nav : 20px  
- Écran complet : 44px (device frame)

---

## 4\. STRUCTURE DES FICHIERS

lib/

├── main.dart

├── app.dart                    \# GoRouter \+ thème global

├── core/

│   ├── theme.dart              \# Couleurs, typo, thème

│   ├── constants.dart          \# Durées, limites

│   └── router.dart             \# Routes nommées

├── models/

│   ├── social\_network.dart     \# Nom, icône, limite temps

│   ├── session.dart            \# Durée, intention, timestamp

│   └── focus\_session.dart      \# Objectif, apps bloquées

├── providers/

│   ├── sessions\_provider.dart  \# Historique sessions

│   ├── networks\_provider.dart  \# Réseaux activés \+ limites

│   └── focus\_provider.dart     \# État du mode Focus

├── screens/

│   ├── splash\_screen.dart

│   ├── onboarding\_screen.dart

│   ├── dashboard\_screen.dart

│   ├── edit\_screen.dart

│   ├── profil\_screen.dart

│   ├── intention\_screen.dart   \# Popup intention ouverture réseau

│   ├── session\_timer\_screen.dart

│   ├── session\_end\_screen.dart \# "Tu as terminé ta session \!"

│   ├── redirect\_screen.dart    \# Sortie guidée

│   ├── focus\_config\_screen.dart \# Config Spark Focus

│   └── focus\_blocked\_screen.dart \# Interception en mode Focus

├── widgets/

│   ├── flame\_button.dart       \# Flamme animée centrale

│   ├── bottom\_nav.dart         \# Navigation globale

│   ├── session\_card.dart       \# Carte session récente

│   ├── network\_toggle.dart     \# Toggle réseau (Edit)

│   └── time\_slider.dart        \# Slider durée session

└── services/

    ├── app\_blocker\_service.dart \# Logique blocage Android

    ├── usage\_service.dart       \# Lecture temps d'écran

    └── storage\_service.dart     \# Hive read/write

---

## 5\. ÉCRANS ET FLUX DÉTAILLÉS

### ÉCRAN 1 — Splash (spark\_chargement)

- Fond noir `#0A0A0A`  
- Logo Spark centré (flamme 3D \+ texte "Spark")  
- Chargement silencieux → redirect vers Dashboard si utilisateur connu, Onboarding si première fois  
- Asset : `assets/images/spark_logo.png`

---

### ÉCRAN 2 — Onboarding / Permissions

- Fond noir  
- Titre centré : **"Pour que Spark fonctionne correctement, il faut activer certaines autorisations"** (Inter Bold, 18px, blanc)  
- Sous-titre : **"Tes données sont complètement privées et ne quittent pas ton téléphone"** (Inter Medium, 14px, `#BBB`)  
- Bouton bas : **"Continuer \!"** (bouton blanc, texte noir, border radius 24px, largeur 323px)  
- Action : demande permission `usage_stats` \+ `BIND_ACCESSIBILITY_SERVICE`

---

### ÉCRAN 3 — Dashboard (écran principal)

**Layout de haut en bas :**

1. **Header** (padding top 48px, horizontal 22px)  
     
   - Texte : "Salut \[Prénom\] \!" — Inter ExtraBold Italic, 32px, blanc

   

2. **Flamme centrale** (zone cliquable, centrée)  
     
   - Asset vidéo/GIF : `assets/flame/flame_idle.gif` (statique au repos)  
   - Asset vidéo : `assets/flame/flame_spin.mp4` (au tap — BlendMode.screen)  
   - Lueur derrière : Container rond, `#FF6600` opacity 0.15, blurRadius 20  
   - Texte sous la flamme : "Appuie sur la flamme pour lancer le mode Focus" (Inter Medium, 13px, `#BBB`, opacity 0.5, centré)  
   - **Action tap** : navigate vers `focus_config_screen`

   

3. **Stats du jour** (horizontal 22px, deux cards côte à côte)  
     
   - Card gauche : label "Grâce à Spark" \+ chiffre en vert `#268429` (ex: "2h12")  
   - Card droite : label "Si tu n'avais pas Spark" \+ chiffre en rouge `#843B26` (ex: "3h06")  
   - Background cards : `rgba(56,56,56,0.2)`, border radius 20px

   

4. **Sessions récentes** (label "Sessions récentes" \+ liste)  
     
   - Chaque item : heure \+ nom réseau à gauche, delta temps à droite  
   - Delta positif (dépassement) : rouge `#843B26`, préfixe "+"  
   - Delta négatif (respecté) : vert `#268429`  
   - Background item : `rgba(56,56,56,0.2)`, border radius 20px

   

5. **Bottom Nav** (fixé en bas, fond `rgba(255,255,255,0.05)`, border top blanc)  
     
   - 3 icônes : Home (gauche) | Flamme Spark centrée surélevée | Profil (droite)  
   - Flamme nav \= bouton rond 86px, gradient orange/rouge, icône flamme blanche

---

### ÉCRAN 4 — Onglet Edit

**Layout :**

1. Titre : "Sélectionne les réseaux sociaux pour lesquels tu veux que Spark intervienne" (Inter Bold, 18px, blanc, padding 22px)  
     
2. **Liste des réseaux** — chaque item (card `rgba(56,56,56,0.2)`, radius 20px) :  
     
   - Nom du réseau à gauche (Inter SemiBold, 18px, blanc)  
   - Toggle à droite :  
     - ON : fond orange/rouge, cercle blanc à droite  
     - OFF : fond gris, cercle gris à gauche  
   - **Réseaux disponibles** : Instagram, TikTok, YouTube, Twitter/X, Snapchat, Facebook

   

3. **Bottom Nav** identique — onglet Edit actif (icône crayon)

---

### ÉCRAN 5 — Profil

**Layout :**

1. Champs de formulaire (cards `rgba(56,56,56,0.2)`, radius 20px) :  
     
   - Nom (label \+ valeur)  
   - Prénom (label \+ valeur)  
   - Email (label \+ valeur)  
   - Mot de passe (label \+ `********`)  
   - Lien "Mot de passe oublié ?" sous le champ

   

2. Texte bas : "Membre depuis le \[date\]" (centré, `#BBB`)  
     
3. **Bottom Nav** — onglet Profil actif

---

### ÉCRAN 6 — Intention ouverture réseau (intention\_screen)

**Déclenché quand :** l'utilisateur ouvre une app surveillée par Spark

**Layout :**

1. Titre : "Salut \[Prénom\] \!" (Inter ExtraBold Italic, 32px, blanc)  
     
2. Sous-titre : "Pourquoi tu ouvres \[nom du réseau\] ?" (Inter Medium, 14px, `#BBB`)  
     
3. **Boutons d'intention** (liste verticale, chacun card `rgba(56,56,56,0.2)`, radius 20px) :  
     
   - "Parler avec mes amis"  
   - "Je cherche un truc de précis"  
   - "Poster"  
   - "Je mérite une pause"  
   - "L'habitude, sans raison"  
   - Sélection \= bordure blanche, coche à droite

   

4. **Règles importantes :**  
     
   - Bouton "Fermer" : toujours actif (ferme Spark, n'ouvre pas le réseau)  
   - Bouton "Entrer quand même" : **grisé tant qu'aucune intention n'est cochée**  
   - Une fois une intention cochée → "Entrer quand même" s'active → navigate vers `session_timer_screen`

---

### ÉCRAN 7 — Timer de session (session\_timer\_screen)

**Layout :**

1. Question : "Combien de temps tu te donnes ?" (Inter Medium, 14px, `#BBB`)  
2. **Slider horizontal** :  
   - Valeur initiale : 0 (grisé)  
   - Min : 1 min, Max : 20 min (10 min si 2ème session ou plus sur le même réseau ce jour)  
   - Valeur affichée à droite du slider : "X min"  
   - Slider background : `rgba(56,56,56,0.2)`, track orange `#E05A3A`  
3. **Bouton "Lancer la session"** :  
   - **Grisé tant que slider \= 0**  
   - Actif dès que slider \> 0 : fond blanc, texte noir  
   - Action : lance le timer, ouvre le réseau social, navigate vers `session_timer_screen` actif

---

### ÉCRAN 8 — Fin de session (session\_end\_screen)

**Déclenché quand :** le timer expire

**Layout :**

1. Flamme Spark centrée (grande, avec lueur)  
2. Titre : "Tu as terminé ta session \!" (Inter Bold, 32px, blanc)  
3. **Bouton principal** : "Je me suis perdu, aide moi à sortir \!"  
   - Fond `rgba(56,56,56,0.2)`, texte blanc, radius 20px  
   - Action → navigate vers `redirect_screen`  
4. **Bouton secondaire** : "Je suis encore là, continuer."  
   - **Grisé pendant 10 secondes** après l'apparition de l'écran  
   - Texte sous le bouton : "«continuer» disponible dans Xs"  
   - Après 10s : s'active → navigate vers `session_timer_screen` (max 10 min)

---

### ÉCRAN 9 — Redirection de sortie (redirect\_screen)

**Déclenché quand :** l'utilisateur clique "Je me suis perdu, aide moi à sortir \!"

**Layout :**

1. Titre : "Tu t'en es rendu compte, et c'est déjà énorme \!" (Inter Bold, blanc)  
2. Question : "Qu'est-ce que tu veux faire maintenant ?" (Inter Medium, `#BBB`)  
3. **Options de redirection** (cards sélectionnables) :  
   - "Me reposer vraiment" / sous-titre : "Pas sur un écran, une vraie pause."  
   - "Avancer sur quelque chose" / sous-titre : "revenir à ce qui compte"  
   - "Faire autre chose librement" / sous-titre : "Sortir de ce piège addictif."  
   - Sélection \= bordure blanche \+ coche  
4. **Bouton** : "Valider et bloquer \[nom du réseau\] pour 30min"  
   - **Grisé tant qu'aucune option n'est cochée**  
   - Une fois active : fond blanc, texte noir  
   - Action : bloque l'app 30 min, retour Dashboard

---

### ÉCRAN 10 — Configuration Spark Focus (focus\_config\_screen)

**Déclenché quand :** tap sur la flamme du Dashboard

**Layout :**

1. Bouton retour (flèche gauche, haut gauche)  
2. Flamme Spark centrée (petite, avec lueur)  
3. Question : "C'est quoi ton objectif pour cette session ?"  
4. **Champ texte** : placeholder "Exemple : Terminer mon montage.."  
   - Card `rgba(56,56,56,0.2)`, radius 20px  
5. Section : "Apps bloquées :"  
   - Liste des réseaux activés dans l'onglet Edit avec cases à cocher  
   - Instagram / TikTok / YouTube (pré-cochés selon réseaux actifs)  
6. **Note** : "Tu devras cocher ton objectif pour déverrouiller les apps." (Inter Medium, 12px, `#BBB`, centré)  
7. **Bouton "Lancer la session"** : fond blanc, texte noir, radius 24px  
   - Action : lance le mode Focus, retour Dashboard avec overlay Focus actif

---

### ÉCRAN 11 — Interception en mode Focus (focus\_blocked\_screen)

**Déclenché quand :** l'utilisateur tente d'ouvrir une app bloquée pendant le Focus

**Layout :**

1. Flamme Spark centrée (grande)  
2. Titre : "Tu es en mode Focus \!" (Inter Bold, 32px, blanc)  
3. **To-do item** (card `rgba(56,56,56,0.2)`, radius 20px) :  
   - Affiche l'objectif défini au lancement  
   - Toggle à droite (coché \= objectif accompli)  
4. **Note** : "Tu devras cocher ton objectif pour déverrouiller les apps."  
5. **Bouton "Retourner travailler"** : fond blanc, texte noir  
   - Action : ferme l'écran, retour à l'app précédente (pas le réseau bloqué)  
6. **Si objectif coché** : bouton "Déverrouiller \[nom app\]" s'active en vert

---

## 6\. LOGIQUE MÉTIER IMPORTANTE

### Compteur de sessions par réseau (même jour)

// Si c'est la 2ème fois ou plus qu'on ouvre le même réseau aujourd'hui

// → slider limité à 10 min au lieu de 20 min

int sessionCountToday(String networkId) {

  return sessions

    .where((s) \=\> s.networkId \== networkId && s.isToday)

    .length;

}

int maxSessionDuration(String networkId) {

  return sessionCountToday(networkId) \>= 1 ? 10 : 20;

}

### Calcul "temps économisé"

// Temps économisé \= somme des (limite \- durée réelle) pour sessions respectées

// Temps "sans Spark" \= estimation basée sur durée moyenne avant Spark (définie à l'onboarding ou fixée à 3h)

### Blocage 30 min après redirection

// Après "Valider et bloquer \[réseau\] pour 30min"

// → stocker timestamp de fin de blocage dans Hive

// → vérifier à chaque ouverture si le blocage est encore actif

DateTime blockedUntil \= DateTime.now().add(Duration(minutes: 30));

### Mode Focus

// État global du Focus dans le provider

class FocusState {

  bool isActive;

  String objective;

  bool objectiveChecked;

  List\<String\> blockedApps;

  DateTime startTime;

}

// Si isActive \= true ET l'app ouverte est dans blockedApps

// → afficher focus\_blocked\_screen à la place

---

## 7\. ASSETS REQUIS

assets/

├── images/

│   └── spark\_logo.png          \# Logo Spark (flamme \+ texte)

├── flame/

│   ├── flame\_idle.gif          \# Flamme statique au repos

│   └── flame\_spin.mp4          \# Rotation 360° au tap

└── fonts/

    └── Inter/                  \# Regular, Medium, SemiBold, Bold, ExtraBold

---

## 8\. RÈGLES DE CODE

1. **Jamais de couleurs hardcodées** dans les widgets — toujours utiliser `AppColors.X`  
2. **Pas de setState** pour la logique métier — tout passe par Riverpod  
3. **Nommage des fichiers** : snake\_case, suffixe `_screen.dart` ou `_widget.dart`  
4. **Tous les textes** passent par des constantes dans `core/constants.dart`  
5. **Le Bottom Nav** est un widget global réutilisé sur tous les écrans principaux  
6. **BlendMode.screen** obligatoire sur tout widget vidéo flamme  
7. **Tester sur émulateur Pixel 8 / Android 14** à chaque modification d'écran

---

## 9\. COMMANDES UTILES

\# Lancer l'app sur l'émulateur Android

flutter run

\# Recharger à chaud

r

\# Recharger à froid (si erreurs de state)

R

\# Voir les erreurs

flutter logs

\# Build APK pour test

flutter build apk \--debug

\# Build release Android

flutter build apk \--release

---

## 10\. ORDRE DE DÉVELOPPEMENT RECOMMANDÉ

1. Setup projet Flutter \+ packages \+ thème \+ router  
2. Splash screen \+ Dashboard (structure)  
3. Flamme centrale (gif statique \+ vidéo au tap \+ lueur)  
4. Bottom nav  
5. Flux intention → timer → fin de session → redirection  
6. Onglet Edit (toggles réseaux)  
7. Onglet Profil  
8. Mode Spark Focus (config \+ interception)  
9. Service de blocage Android  
10. Tests sur émulateur \+ corrections  
11. Build APK → envoyer à Léo pour build iOS

