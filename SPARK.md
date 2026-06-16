# **SPARK.md — Spark App**

## **1\. CONTEXTE DU PROJET**

Spark est une application mobile Flutter (Android) anti-doomscrolling. Elle intercepte l'ouverture des réseaux sociaux et crée des rituels conscients d'intention, de session et de sortie.

**3 mécanismes core :**

1. **Intention à l'ouverture** — quand l'utilisateur ouvre un réseau surveillé, Spark s'affiche et lui demande pourquoi il l'ouvre. Il choisit une intention parmi une liste, puis est redirigé via deeplink vers l'endroit correspondant dans l'app.  
2. **Contrat de session** — il fixe une durée avant d'entrer (slider 1–20 min). Le timer tourne en natif Android via SharedPreferences.  
3. **Écran de fin de session** — quand le timer expire, l'écran s'éteint (`lockNow()`), puis à la réouverture un écran de fin s'affiche avec deux options : bloquer le réseau 5 min ou continuer quand même (reset de session).

**Mode Spark Focus :** l'utilisateur définit un objectif de travail \+ apps à bloquer. Tant que le mode est actif, toute tentative d'ouverture d'une app bloquée affiche uniquement l'écran Focus (pas d'écran d'intention). Le mode se désactive quand l'utilisateur coche son objectif sur le dashboard. Durée infinie.

---

## **2\. STACK TECHNIQUE**

* **Framework** : Flutter (Dart)  
* **Cible actuelle** : Android uniquement (iOS nécessite un Mac)  
* **État** : Riverpod  
* **Storage local Flutter** : Hive  
* **Storage natif** : SharedPreferences Android (`"spark_monitor"`)  
* **Navigation** : go\_router  
* **Package name** : `com.example.spark`

### **Dépendances Flutter (pubspec.yaml)**

dependencies:  
  flutter:  
    sdk: flutter  
  riverpod: ^2.5.1  
  flutter\_riverpod: ^2.5.1  
  hive: ^2.2.3  
  hive\_flutter: ^1.1.0  
  go\_router: ^13.0.0  
  android\_intent\_plus: ^4.0.2  
  permission\_handler: ^11.3.0  
  app\_usage: ^3.0.1  
  intl: ^0.19.0

### **Fichiers natifs Android (Kotlin)**

| Fichier | Rôle |
| ----- | ----- |
| `AppMonitorService.kt` | Service foreground qui tourne en arrière-plan. Contient le `poll()` (toutes les 500ms) qui détecte les apps au premier plan et gère toute la logique de session (timer, pause, reprise, silent reset, blocage). |
| `MainActivity.kt` | Pont Flutter↔natif via MethodChannel `com.example.spark/permissions`. Reçoit les appels Flutter et dispatche les événements natifs vers Flutter (`onAppIntercepted`, `onSessionEnded`, `onAppBlocked`, `onSessionCancelled`). |
| `SparkAccessibilityService.kt` | Service d'accessibilité Android. Détecte l'ouverture des apps via `TYPE_WINDOW_STATE_CHANGED`, `TYPE_WINDOWS_CHANGED`, `TYPE_WINDOW_CONTENT_CHANGED`. Détection plus rapide que le poll(). Ne fonctionne pas sur Honor/Huawei (MagicUI bloque les services d'accessibilité tiers). |
| `SparkDeviceAdminReceiver.kt` | Permet à Spark d'être administrateur de l'appareil pour appeler `lockNow()` (éteindre l'écran à la fin d'une session). |

---

## **3\. DESIGN SYSTEM**

Lien Figma : https://www.figma.com/design/TxnAKO8YNWFRXeaCN13E4m/Maquette-final-coeur-de-Spark

### **Couleurs (`theme.dart` → `AppColors`)**

// Fonds  
static const Color bgPrimary     \= Color(0xFF0A0A0A);  
static const Color bgCard        \= Color(0xFF111111);  
static const Color bgCardBorder  \= Color(0xFF1E1E1E);  
static const Color bgSessionEnd  \= Color(0xFF171A1A);  
static const Color bgCardSurface \= Color(0xFF1C1C1C);

// Accents  
static const Color green         \= Color(0xFF268429);  // Grâce à Spark / succès  
static const Color greenLight    \= Color(0xFF4CAF50);  // Sessions respectées  
static const Color red           \= Color(0xFF843B26);  // Dépassement  
static const Color orange        \= Color(0xFFE05A3A);  // Focus actif  
static const Color cream         \= Color(0xFFF5EDE0);  // Bouton primaire session end

// Texte  
static const Color textPrimary   \= Color(0xFFFFFFFF);  
static const Color textSecondary \= Color(0xFFBBBBBB);  
static const Color textMuted     \= Color(0xFF555555);

### **Typographie (Inter)**

// Titre principal ("Salut \+ nom user \!")  
TextStyle titleLarge \= TextStyle(  
  fontFamily: 'Inter', fontWeight: FontWeight.w800,  
  fontSize: 32, fontStyle: FontStyle.italic,  
  letterSpacing: \-1.6, color: Colors.white,  
);

// Chiffre clé ("2h12")  
TextStyle metricLarge \= TextStyle(  
  fontFamily: 'Inter', fontWeight: FontWeight.w800,  
  fontSize: 50, letterSpacing: \-2.5,  
);

// Label section ("Sessions récentes")  
TextStyle sectionLabel \= TextStyle(  
  fontFamily: 'Inter', fontWeight: FontWeight.w700,  
  fontSize: 18, letterSpacing: \-0.9, color: Color(0xFFBBBBBB),  
);

// Corps texte  
TextStyle body \= TextStyle(  
  fontFamily: 'Inter', fontWeight: FontWeight.w500,  
  fontSize: 14, letterSpacing: \-0.7, color: Color(0xFFBBBBBB),  
);

### **Border radius**

* Cards : 20px  
* Boutons : 24px  
* Bottom nav : 20px

---

## **4\. STRUCTURE DES FICHIERS**

android/app/src/main/kotlin/com/example/spark/  
├── AppMonitorService.kt  
├── MainActivity.kt  
├── SparkAccessibilityService.kt  
└── SparkDeviceAdminReceiver.kt

lib/  
├── main.dart  
├── app.dart                          \# GoRouter \+ thème global \+ handlers MethodChannel natif  
├── core/  
│   ├── constants.dart                \# Durées, strings, clés  
│   ├── router.dart                   \# Routes nommées go\_router  
│   └── theme.dart                    \# AppColors, typographie, thème global  
├── models/  
│   ├── focus\_session.dart            \# Objectif \+ apps bloquées (Focus)  
│   ├── session.dart                  \# Durée, intention, timestamp  
│   ├── session\_history\_entry.dart    \# Entrée historique session (networkId, startTimeMs, durationSeconds)  
│   └── social\_network.dart           \# Nom, icône, packageName  
├── providers/  
│   ├── focus\_provider.dart           \# État du mode Focus  
│   ├── networks\_provider.dart        \# Réseaux activés \+ leurs packages  
│   ├── session\_history\_provider.dart \# StateNotifier pour l'historique des sessions du jour  
│   ├── session\_timer\_provider.dart   \# Timer de session Flutter (sync avec natif)  
│   └── sessions\_provider.dart        \# Historique sessions (legacy)  
├── screens/  
│   ├── dashboard\_screen.dart         \# Écran principal (stats \+ sessions récentes)  
│   ├── edit\_screen.dart              \# Sélection des réseaux à surveiller  
│   ├── focus\_blocked\_screen.dart     \# Interception en mode Focus  
│   ├── focus\_config\_screen.dart      \# Configuration du mode Focus  
│   ├── intention\_screen.dart         \# Choix d'intention à l'ouverture d'un réseau  
│   ├── onboarding\_screen.dart        \# Premier lancement (intro)  
│   ├── permissions\_screen.dart       \# Demande des 4 permissions requises  
│   ├── profil\_screen.dart            \# Profil utilisateur \+ statut permissions  
│   ├── redirect\_screen.dart          \# Sortie guidée après session  
│   ├── session\_end\_screen.dart       \# Écran de fin de session (bloquer 5min / continuer)  
│   ├── session\_timer\_screen.dart     \# Slider durée \+ lancement session  
│   └── splash\_screen.dart            \# Écran de chargement initial  
├── services/  
│   ├── app\_blocker\_service.dart      \# Logique blocage Android (legacy)  
│   ├── monitor\_service.dart          \# MethodChannel Flutter→natif (toutes les commandes)  
│   ├── permission\_service.dart       \# Vérification \+ demande des permissions  
│   ├── session\_history\_service.dart  \# Lecture/écriture historique sessions (Hive)  
│   ├── storage\_service.dart          \# Hive read/write général  
│   └── usage\_service.dart            \# Lecture temps d'écran UsageStats  
└── widgets/  
    ├── bottom\_nav.dart               \# Navigation globale (3 onglets)  
    ├── flame\_button.dart             \# Flamme animée centrale  
    ├── network\_toggle.dart           \# Toggle réseau (Edit)  
    ├── permission\_card.dart          \# Carte permission (onboarding)  
    ├── session\_card.dart             \# Carte session récente  
    └── time\_slider.dart              \# Slider durée session

---

## **5\. ARCHITECTURE NATIF ANDROID**

### **MethodChannel**

Le canal de communication Flutter↔natif s'appelle `com.example.spark/permissions`.

**Appels Flutter → natif (dans `monitor_service.dart`) :**

| Méthode | Description |
| ----- | ----- |
| `setFocusMode` | Active/désactive le mode Focus : écrit `KEY_FOCUS_ACTIVE` \+ `KEY_FOCUS_PKGS` dans SharedPreferences |
| `setSessionEndTime` | Démarre une session : écrit `KEY_SESSION_END_TIME`, `KEY_SESSION_START_TIME`, `KEY_SESSION_NETWORK_ID`, `KEY_ACTIVE` |
| `clearSessionEndTime` | Reset complet de la session côté natif |
| `setMonitoredNetworks` | Met à jour la liste des réseaux surveillés (`KEY_MONITORED`) |
| `setBlockUntil` | Bloque un réseau pendant 5 min |
| `startService` | Démarre AppMonitorService |
| `stopService` | Arrête AppMonitorService |
| `getSessionHistory` | Retourne le JSON de l'historique des sessions du jour |
| `getOrComputeBaseline` | Retourne la baseline UsageStats 7 jours (plancher 90 min) |
| `hasPendingSessionEnd` | Vérifie si une fin de session natif est en attente |
| `checkUsageStats` | Vérifie la permission UsageStats |
| `checkOverlay` | Vérifie la permission SYSTEM\_ALERT\_WINDOW |
| `checkAccessibility` | Vérifie si SparkAccessibilityService est actif |
| `openUsageSettings` | Ouvre les paramètres UsageStats |
| `openOverlaySettings` | Ouvre les paramètres overlay |
| `openAccessibilitySettings` | Ouvre les paramètres accessibilité |
| `openDeviceAdmin` | Ouvre les paramètres administrateur |

**Appels natif → Flutter (dans `app.dart`) :**

| Méthode | Description |
| ----- | ----- |
| `onAppIntercepted` | Un réseau surveillé est au premier plan sans session active → afficher l'écran d'intention |
| `onSessionEnded` | Le timer a expiré et l'écran a été verrouillé → afficher l'écran de fin de session |
| `onAppBlocked` | Le réseau est en période de blocage 5 min → afficher l'écran de blocage |
| `onSessionCancelled` | Silent reset déclenché → reset du timer Flutter sans navigation |

### **SharedPreferences keys (`"spark_monitor"`)**

| Clé | Type | Description |
| ----- | ----- | ----- |
| `KEY_SESSION_END_TIME` | Long | Timestamp de fin de session (0 \= pas de session) |
| `KEY_SESSION_REMAINING_MS` | Long | Temps restant quand session en pause |
| `KEY_SESSION_PAUSED_AT_MS` | Long | Timestamp de mise en pause |
| `KEY_SESSION_NETWORK_ID` | String | Réseau actif ("instagram", "tiktok", "youtube") |
| `KEY_SESSION_START_TIME` | Long | Timestamp de début de session |
| `KEY_ACTIVE` | StringSet | Packages actuellement en session active |
| `KEY_MONITORED` | StringSet | Packages surveillés par Spark |
| `KEY_PENDING_SESSION_ENDED` | String | networkId d'une fin de session en attente de dispatch Flutter |
| `KEY_SESSION_CANCELLED` | String | networkId d'un silent reset en attente de dispatch Flutter |
| `KEY_BLOCK_UNTIL_MS` | Long | Timestamp de fin du blocage 5 min |
| `KEY_BLOCK_PKG` | String | Package bloqué |
| `KEY_FOCUS_ACTIVE` | Boolean | Mode Focus actif |
| `KEY_FOCUS_PKGS` | StringSet | Packages bloqués en mode Focus |
| `KEY_SESSION_HISTORY` | String | JSON array des sessions du jour |
| `KEY_BASELINE_MINUTES` | Int | Baseline UsageStats calculée (minutes/jour) |

### **Réseaux surveillés et packages**

| Réseau | networkId | Package(s) Android |
| ----- | ----- | ----- |
| Instagram | `instagram` | `com.instagram.android` |
| TikTok | `tiktok` | `com.zhiliaoapp.musically`, `com.ss.android.ugc.trill` |
| YouTube | `youtube` | `com.google.android.youtube` |

### **Logique du poll() — AppMonitorService**

Le poll() tourne toutes les **500ms**. À chaque tick :

1. **Gestion du timer de session** (si `KEY_SESSION_NETWORK_ID` non vide) :

   * `appInFg` \= `isSessionPkgForeground()` avec fenêtre 30 min (ACTIVITY\_RESUMED)  
   * Si `appInFg = true` :  
     * `remainingMs > 0` → reprise du timer  
     * `sessionEndTime > 0 && now >= sessionEndTime` → `handleSessionEnd()`  
   * Si `appInFg = false` :  
     * `sessionEndTime > 0 && now >= sessionEndTime` → `handleSessionEnd()` (timer expiré en arrière-plan)  
     * `sessionEndTime > 0` → mise en pause (sauvegarde `remainingMs` et `pausedAtMs`)  
     * `pausedAtMs > 0 && durée >= 45s` → `silentReset()` (reset silencieux sans écran de fin)  
2. **Nettoyage blocage expiré**

3. **Détection foreground** via `getForegroundPackage()` \+ vérification secondaire `isSessionPkgForeground()` (fenêtre 10s) pour éviter les faux positifs

4. **Mode Focus** : si `KEY_FOCUS_ACTIVE = true` et le package détecté est dans `KEY_FOCUS_PKGS` → lancer `MainActivity` avec `EXTRA_IS_FOCUS = true` (priorité sur l'interception normale)

5. **Blocage actif** : si réseau bloqué est au premier plan → afficher écran de blocage

6. **Interception normale** : si réseau surveillé au premier plan sans session active → lancer `MainActivity` avec `EXTRA_NETWORK_ID`

### **Permissions requises (Android)**

| Permission | Usage |
| ----- | ----- |
| `PACKAGE_USAGE_STATS` | Lire les apps en premier plan via UsageStatsManager |
| `SYSTEM_ALERT_WINDOW` | Afficher Spark par-dessus les autres apps (exempte du blocage background activity) |
| `BIND_ACCESSIBILITY_SERVICE` | SparkAccessibilityService pour détection rapide |
| `BIND_DEVICE_ADMIN` | `lockNow()` pour éteindre l'écran en fin de session |

---

## **6\. ÉCRANS IMPLÉMENTÉS**

### **Splash → `splash_screen.dart`**

Chargement silencieux. Redirige vers `permissions_screen` si première fois, sinon `dashboard`.

### **Onboarding → `onboarding_screen.dart`**

Écran d'intro affiché avant l'écran des permissions.

### **Permissions → `permissions_screen.dart`**

4 cartes de permission : UsageStats, Overlay, Accessibilité, Device Admin. Redirige vers `dashboard` quand toutes accordées.

### **Dashboard → `dashboard_screen.dart`**

Écran principal de Spark. Design épuré, fond dégradé chaud brun/noir.

**Layout de haut en bas :**

1. **Header** : "Salut \[Prénom\] \!" — Inter ExtraBold Italic, 32px, blanc, padding top 48px, horizontal 22px  
2. **Flamme centrale** (centrée, occupe la majorité de l'écran) :  
   * Asset image : `assets/images/flame.png`  
   * Lueur derrière : Container rond, couleur orange `#E05A3A` opacity 0.15, blurRadius 60  
   * Fond du dashboard : dégradé radial depuis le centre — `#3D1A00` au centre vers `#0A0A0A` sur les bords  
   * Texte sous la flamme : "Appuie sur la flamme pour lancer le mode Focus" — Inter Medium, 13px, `#BBB`, opacity 0.5, centré  
   * **Action tap flamme** : navigate vers `/focus-config`  
3. **Bottom Nav** fixé en bas (fond `rgba(255,255,255,0.05)`, border top blanc, radius 20px) :  
   * 3 icônes : Home (actif, fond orange arrondi) | crayon (Edit) | personne (Profil)

**État normal** (Focus inactif) : tel que décrit ci-dessus.

**État Focus actif** : fond brun/orange plus intense, titre "Tu es en mode Focus \!" à la place du texte sous la flamme, card avec l'objectif \+ toggle pour désactiver.

### **Edit → `edit_screen.dart`**

Toggles pour activer/désactiver Instagram, TikTok, YouTube.

### **Profil → `profil_screen.dart`**

Informations utilisateur \+ statut des permissions.

### **Intention → `intention_screen.dart`**

Déclenché par `onAppIntercepted`. Affiche les intentions selon le réseau :

* Instagram / TikTok : "Parler avec mes amis", "Je cherche un truc de précis", "Poster", "Je mérite une pause", "L'habitude, sans raison"  
* YouTube : mêmes sauf "Parler avec mes amis"

Bouton "Fermer" (toujours actif) \+ "Entrer quand même" (grisé sans intention cochée). Au tap → deeplink vers le bon endroit dans l'app \+ navigate vers `session_timer_screen`.

### **Session Timer → `session_timer_screen.dart`**

Slider 1–20 min. Bouton "Lancer la session" (grisé si 0). Au tap : appelle `setSessionEndTime` via MethodChannel.

### **Session End → `session_end_screen.dart`**

Déclenché par `onSessionEnded`. Deux boutons :

* "Bloquer \[réseau\] 5 min" : appelle `setBlockUntil`, retour dashboard  
* "Continuer quand même" : reset session, retour dashboard

Bouton "Continuer" grisé 20s avec countdown.

### **Redirect → `redirect_screen.dart`**

Sortie guidée après session (non encore connectée au flow principal).

### **Focus Config → `focus_config_screen.dart`**

Déclenché par tap sur la flamme du dashboard (uniquement si mode Focus inactif).

**Layout :**

* Bouton retour (flèche gauche)  
* Flamme Spark centrée (petite)  
* Titre : "C'est quoi ton objectif pour cette session ?"  
* Champ texte : placeholder "Exemple : Terminer mon montage.." (card `bgCard`, radius 20px)  
* Section "Apps bloquées :" — liste des réseaux activés dans Edit avec toggles ON/OFF  
* Note : "Tu devras cocher ton objectif pour déverrouiller les apps." (Inter Medium, 12px, `#BBB`)  
* Bouton "Lancer la session" : fond blanc, texte noir, radius 24px

**Action au tap "Lancer la session" :**

1. Sauvegarde l'objectif \+ les packages bloqués dans `focus_provider`  
2. Appelle `setFocusMode(true, blockedPackages)` via MethodChannel → écrit `KEY_FOCUS_ACTIVE = true` et `KEY_FOCUS_PKGS` dans SharedPreferences  
3. Navigate vers `/dashboard`  
4. Le dashboard bascule en mode Focus (fond brun/orange, objectif affiché)

### **Focus Blocked → `focus_blocked_screen.dart`**

Déclenché par `onAppIntercepted` quand `KEY_FOCUS_ACTIVE = true` et le réseau est dans `KEY_FOCUS_PKGS`. **Remplace complètement l'écran d'intention** — pas d'écran d'intention en mode Focus.

**Layout :**

* Fond sombre  
* Flamme Spark centrée  
* Titre : "Tu es en mode Focus \!"  
* Card avec l'objectif affiché (texte, fond `bgCard`, radius 20px)  
* Bouton "Fermer" : ferme Spark, retour au launcher. **Aucun autre bouton** — impossible d'entrer dans l'app bloquée.

### **Dashboard en mode Focus → `dashboard_screen.dart` (état Focus)**

Quand `KEY_FOCUS_ACTIVE = true`, le dashboard affiche un état différent :

**Layout :**

* Header "Salut \[Prénom\] \!" (identique)  
* Fond chaud brun/orange (pas le fond noir habituel)  
* Titre central : "Tu es en mode Focus \!"  
* Card avec l'objectif \+ **toggle à droite** (OFF \= Focus actif)  
* **Quand l'utilisateur coche le toggle** :  
  1. Appelle `setFocusMode(false, [])` via MethodChannel → efface `KEY_FOCUS_ACTIVE` et `KEY_FOCUS_PKGS`  
  2. Met à jour `focus_provider` → `isActive = false`  
  3. Dashboard revient à l'état normal  
  4. Toutes les apps bloquées se débloquent automatiquement

---

## **7\. CE QUI FONCTIONNE (validé sur Honor Android 15\)**

* ✅ Détection ouverture Instagram / TikTok / YouTube  
* ✅ Écran d'intention avec intentions spécifiques par réseau  
* ✅ Deeplinks selon intention (Instagram et YouTube fonctionnels, TikTok partiel)  
* ✅ Timer de session natif avec pause/reprise  
* ✅ `lockNow()` à l'expiration du timer (avec fallback overlay si échec)  
* ✅ Écran de fin de session avec countdown 20s  
* ✅ Blocage 5 min fonctionnel  
* ✅ Reset silencieux après 45s d'inactivité hors réseau  
* ✅ `hasPendingSessionEnd` évite l'écran de fin si silent reset  
* ✅ AccessibilityService actif sur Oppo (pas sur Honor/Huawei)  
* ✅ Sélection des réseaux surveillés (Edit)  
* ✅ Onboarding \+ permissions

## **8\. CE QUI NE FONCTIONNE PAS / À IMPLÉMENTER**

* ❌ **Mode Spark Focus** : les écrans `focus_config_screen` et `focus_blocked_screen` existent mais ne sont pas connectés au flow natif. Il faut :  
  1. Ajouter le handler `setFocusMode` dans `MainActivity.kt` (écrit `KEY_FOCUS_ACTIVE` \+ `KEY_FOCUS_PKGS`)  
  2. Dans `poll()` de `AppMonitorService.kt` : si `KEY_FOCUS_ACTIVE = true` et le package est dans `KEY_FOCUS_PKGS` → lancer `MainActivity` avec un extra `EXTRA_IS_FOCUS = true` au lieu du flow normal  
  3. Dans `app.dart` : si `onAppIntercepted` reçoit `isFocus = true` → navigate vers `/focus-blocked` au lieu de `/intention`  
  4. Dans `dashboard_screen.dart` : afficher l'état Focus (fond brun, objectif \+ toggle) quand `focus_provider.isActive = true`  
* ❌ **Dashboard** : pas mis à jour  
* ❌ **Redirect screen :**  non connecté au flow et quand j’ai finis une session, rien ne se passe et mon écran ne s’éteind pas et je n’ai pas l’écran de fin de session.  
* ❌ **Profil** sans données réelles (pas de compte utilisateur)

---

## **9\. DEVICE DE TEST**

| Device | ADB ID | OS | Notes |
| ----- | ----- | ----- | ----- |
| Honor CRT NX1 | `AYAV6R3704035491` | Android 15 |  |
|  |  |  |  |

---

## **10\. COMMANDES UTILES**

\# Lancer sur le Honor  
flutter run \-d AYAV6R3704035491

\# Voir les devices connectés  
cd C:\\Users\\cyril\\AppData\\Local\\Android\\Sdk\\platform-tools  
.\\adb devices

\# Force stop Spark  
.\\adb \-s AYAV6R3704035491 shell am force-stop com.example.spark

\# Build APK debug  
flutter build apk \--debug

\# Build APK release  
flutter build apk \--release

\# Git : sauvegarder  
cd C:\\spark  
git add .  
git commit \-m "message"  
git push

---

## **11\. RÈGLES POUR CLAUDE CODE**

1. **Toujours lire ce fichier en premier** avant toute modification  
2. **Une seule tâche à la fois** — ne pas grouper plusieurs modifications  
3. **Jamais de couleurs hardcodées** — toujours `AppColors.X`  
4. **Pas de setState** pour la logique métier — tout passe par Riverpod  
5. **Après chaque modification de `AppMonitorService.kt`**, tester impérativement : fin de session normale \+ silent reset \+ réouverture après reset  
6. **Toujours entourer les opérations SharedPreferences dans `saveSessionToHistory()`** d'un try/catch  
7. **Le poll()** tourne toutes les 500ms — ne pas augmenter

