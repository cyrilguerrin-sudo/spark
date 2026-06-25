# SPARK.md — Spark App (iOS)

---

## 1\. CONTEXTE DU PROJET

Spark est une application mobile Flutter (iOS) anti-doomscrolling. Elle intercepte l'ouverture des réseaux sociaux et crée des rituels conscients d'intention, de session et de sortie.

**3 mécanismes core :**

1. **Intention à l'ouverture** — quand l'utilisateur ouvre un réseau surveillé, le Shortcut iOS intercepte le lancement et ouvre Spark. Spark affiche l'écran d'intention, l'user choisit, puis Spark débloque l'app et l'user peut entrer.  
2. **Contrat de session** — l'user fixe une durée (slider 1–20 min). Le timer tourne via DeviceActivityMonitor en natif Swift, avec le timestamp stocké dans App Group UserDefaults.  
3. **Écran de fin de session** — quand le timer expire, DeviceActivityMonitor rebloque l'app via ManagedSettings. L'écran Shield Spark s'affiche par-dessus le réseau social avec deux options : "Bloquer 5 min" ou "Terminer la session" (retour écran d'accueil \+ reset).

**Mode Spark Focus :** l'utilisateur définit un objectif de travail \+ apps à bloquer. Tant que le mode est actif, toute tentative d'ouverture affiche directement l'écran Shield (pas d'écran d'intention). Le mode se désactive quand l'utilisateur coche son objectif sur le dashboard.

⚠️ **Différences fondamentales avec Android :**

- L'interception se fait via Shortcuts iOS (pas d'AccessibilityService)  
- Pas de lockNow() — fin de session \= Shield ManagedSettings par-dessus l'app  
- L'écran de fin de session EST l'écran Shield (pas un écran Flutter)  
- Pas de countdown 20s sur le bouton "Terminer" — iOS Shield ne le permet pas

---

## 2\. STACK TECHNIQUE

- **Framework** : Flutter (Dart)  
- **Cible** : iOS 16+ (minimum pour FamilyControls stable) — iOS 26 recommandé pour Shortcuts sans boucle infinie  
- **État** : Riverpod  
- **Storage local Flutter** : Hive  
- **Storage partagé Flutter↔extensions** : App Groups (group.com.example.spark) via UserDefaults  
- **Navigation** : go\_router  
- **Bundle ID** : com.example.spark

### Frameworks natifs iOS (Swift)

| Framework | Rôle |
| :---- | :---- |
| FamilyControls | Autorise Spark à gérer Screen Time (requestAuthorization) |
| ManagedSettings | Bloque / débloque des apps (ManagedSettingsStore) |
| DeviceActivity | Timer de session natif \+ reblocage à expiration |
| AppIntents | Expose un intent Shortcuts pour intercepter l'ouverture des apps (iOS 26+) |
| SwiftUI | UI des extensions Swift |

### Extensions iOS requises (targets Xcode séparées)

| Extension | Rôle |
| :---- | :---- |
| SparkShieldConfiguration | Personnalise l'écran Shield (titre, sous-titre, labels des boutons) |
| SparkShieldAction | Gère les boutons de l'écran Shield ("Bloquer 5 min" / "Terminer") |
| SparkDeviceActivityMonitor | Timer de session natif — rebloque à expiration, gère pause/reprise 45s |

### Dépendances Flutter (pubspec.yaml)

dependencies:

  flutter:

    sdk: flutter

  riverpod: ^2.5.1

  flutter\_riverpod: ^2.5.1

  hive: ^2.2.3

  hive\_flutter: ^1.1.0

  go\_router: ^13.0.0

  permission\_handler: ^11.3.0

  intl: ^0.19.0

  \# Pas de android\_intent\_plus ni app\_usage sur iOS

### Communication Flutter ↔ natif Swift

Via MethodChannel nommé com.example.spark/familycontrols.

---

## 3\. DESIGN SYSTEM

Identique à Android — voir charte graphique Spark.

### Couleurs (theme.dart → AppColors)

static const Color bgPrimary      \= Color(0xFF0A0A0A);

static const Color bgCard         \= Color(0xFF111111);

static const Color bgCardBorder   \= Color(0xFF1E1E1E);

static const Color bgSessionEnd   \= Color(0xFF171A1A);

static const Color bgCardSurface  \= Color(0xFF1C1C1C);

static const Color green          \= Color(0xFF268429);

static const Color greenLight     \= Color(0xFF4CAF50);

static const Color red            \= Color(0xFF843B26);

static const Color orange         \= Color(0xFFE05A3A);

static const Color cream          \= Color(0xFFF5EDE0);

static const Color textPrimary    \= Color(0xFFFFFFFF);

static const Color textSecondary  \= Color(0xFFBBBBBB);

static const Color textMuted      \= Color(0xFF555555);

### Typographie (Inter)

TextStyle titleLarge \= TextStyle(

  fontFamily: 'Inter', fontWeight: FontWeight.w800,

  fontSize: 32, fontStyle: FontStyle.italic,

  letterSpacing: \-1.6, color: Colors.white,

);

TextStyle metricLarge \= TextStyle(

  fontFamily: 'Inter', fontWeight: FontWeight.w800,

  fontSize: 50, letterSpacing: \-2.5,

);

TextStyle sectionLabel \= TextStyle(

  fontFamily: 'Inter', fontWeight: FontWeight.w700,

  fontSize: 18, letterSpacing: \-0.9, color: Color(0xFFBBBBBB),

);

TextStyle body \= TextStyle(

  fontFamily: 'Inter', fontWeight: FontWeight.w500,

  fontSize: 14, letterSpacing: \-0.7, color: Color(0xFFBBBBBB),

);

### Border radius

- Cards : 20px  
- Boutons : 24px  
- Bottom nav : 20px

---

## 4\. STRUCTURE DES FICHIERS

ios/

├── Runner/

│   ├── AppDelegate.swift                    \# Entry point \+ MethodChannel Flutter↔Swift \+ URL scheme handler

│   ├── SparkAppIntent.swift                 \# App Intent exposé aux Shortcuts (intercepte ouverture apps)

│   └── Info.plist                           \# NSFamilyControlsUsageDescription \+ URL scheme spark://

├── SparkShieldConfiguration/

│   └── ShieldConfigurationExtension.swift   \# UI écran Shield : titre, sous-titre, labels boutons

├── SparkShieldAction/

│   └── ShieldActionExtension.swift          \# Logique boutons Shield (Bloquer 5 min / Terminer)

└── SparkDeviceActivityMonitor/

    └── DeviceActivityMonitorExtension.swift  \# Timer session \+ pause/reprise 45s \+ reblocage

lib/

├── main.dart

├── app.dart                    \# GoRouter \+ thème global \+ handlers MethodChannel

├── core/

│   ├── constants.dart

│   ├── router.dart

│   └── theme.dart

├── models/

│   ├── focus\_session.dart

│   ├── session.dart

│   ├── session\_history\_entry.dart

│   └── social\_network.dart

├── providers/

│   ├── focus\_provider.dart

│   ├── networks\_provider.dart

│   ├── session\_history\_provider.dart

│   ├── session\_timer\_provider.dart

│   └── sessions\_provider.dart

├── screens/

│   ├── dashboard\_screen.dart

│   ├── edit\_screen.dart

│   ├── focus\_blocked\_screen.dart

│   ├── focus\_config\_screen.dart

│   ├── intention\_screen.dart

│   ├── onboarding\_screen.dart

│   ├── permissions\_screen.dart        \# Simplifiée : 1 seule permission (FamilyControls)

│   ├── profil\_screen.dart

│   ├── session\_timer\_screen.dart

│   └── splash\_screen.dart

│   \# session\_end\_screen.dart SUPPRIMÉ — remplacé par l'écran Shield natif iOS

│   \# redirect\_screen.dart SUPPRIMÉ — iOS ne permet pas de forcer la fermeture d'une app

├── services/

│   ├── family\_controls\_service.dart   \# MethodChannel Flutter→Swift (remplace monitor\_service.dart)

│   ├── permission\_service.dart

│   ├── session\_history\_service.dart

│   ├── storage\_service.dart

│   └── usage\_service.dart

└── widgets/

    ├── bottom\_nav.dart

    ├── flame\_button.dart

    ├── network\_toggle.dart

    ├── permission\_card.dart

    ├── session\_card.dart

    └── time\_slider.dart

---

## 5\. ARCHITECTURE NATIF iOS (Swift)

### MethodChannel Flutter ↔ Swift

Canal : com.example.spark/familycontrols

#### Appels Flutter → Swift (dans family\_controls\_service.dart)

| Méthode | Description |
| :---- | :---- |
| requestAuthorization | Demande la permission FamilyControls (popup système Apple) |
| setMonitoredNetworks | Enregistre les apps à surveiller via FamilyActivityPicker token |
| setSessionEndTime | Débloque l'app surveillée \+ démarre le timer DeviceActivity |
| clearSessionEndTime | Rebloque l'app \+ reset session |
| setFocusMode | Active/désactive le mode Focus |
| getSessionHistory | Retourne le JSON de l'historique du jour depuis App Group UserDefaults |
| checkAuthorization | Vérifie si FamilyControls est autorisé |

#### Appels Swift → Flutter (dans app.dart)

| Méthode | Description |
| :---- | :---- |
| onAppIntercepted | Shortcut a ouvert Spark → afficher intention\_screen |
| onSessionCancelled | Silent reset 45s → reset timer Flutter sans navigation |

ℹ️ Plus de onSessionEnded ni onAppBlocked côté Flutter — la fin de session et le blocage 5 min sont gérés entièrement dans les extensions Swift via l'écran Shield natif.

### App Group UserDefaults (storage partagé)

Clé App Group : group.com.example.spark

| Clé | Type | Description |
| :---- | :---- | :---- |
| KEY\_SESSION\_END\_TIME | Double | Timestamp fin de session (0 \= pas de session) |
| KEY\_SESSION\_NETWORK\_ID | String | Réseau actif ("instagram", "tiktok", "youtube") |
| KEY\_SESSION\_START\_TIME | Double | Timestamp début de session |
| KEY\_SESSION\_PAUSED\_AT | Double | Timestamp mise en pause (0 \= pas en pause) |
| KEY\_SESSION\_REMAINING\_MS | Double | Temps restant au moment de la pause |
| KEY\_MONITORED\_TOKENS | Data | FamilyActivitySelection encodée (apps surveillées) |
| KEY\_BLOCK\_UNTIL | Double | Timestamp fin du blocage 5 min (0 \= pas de blocage) |
| KEY\_BLOCK\_NETWORK\_ID | String | Réseau en cours de blocage 5 min |
| KEY\_FOCUS\_ACTIVE | Bool | Mode Focus actif |
| KEY\_FOCUS\_TOKENS | Data | FamilyActivitySelection encodée (apps Focus) |
| KEY\_SESSION\_HISTORY | String | JSON array sessions du jour |

⚠️ Ne jamais faire confiance à un booléen seul — toujours vérifier le timestamp. Si KEY\_SESSION\_END\_TIME est dans le passé, la session est expirée même si d'autres flags disent le contraire.

### Réseaux surveillés et Bundle IDs iOS

| Réseau | networkId | Bundle ID iOS |
| :---- | :---- | :---- |
| Instagram | instagram | com.burbn.instagram |
| TikTok | tiktok | com.zhiliaoapp.musically |
| YouTube | youtube | com.google.ios.youtube |

⚠️ La sélection des apps se fait via FamilyActivityPicker (UI Apple native) — impossible de hardcoder les Bundle IDs directement.

---

## 6\. FLOWS COMPLETS

### Flow interception normale (Shortcuts)

User ouvre Instagram

  → Shortcut iOS se déclenche ("Quand Instagram s'ouvre → Spark AppIntent")

  → SparkAppIntent vérifie KEY\_SESSION\_END\_TIME dans App Group UserDefaults

      → Si session active en cours : laisse Instagram s'ouvrir normalement (Launch Pass)

      → Si pas de session : ouvre Spark via continueInForeground()

  → Spark s'affiche → Flutter navigue vers /intention

  → User choisit son intention \+ durée

  → Flutter appelle setSessionEndTime via MethodChannel

  → Swift écrit KEY\_SESSION\_END\_TIME \+ KEY\_SESSION\_NETWORK\_ID dans UserDefaults

  → Swift retire Instagram du Shield (ManagedSettingsStore.shield.applications \= nil)

  → Swift démarre DeviceActivityMonitor pour surveiller l'expiration

  → Spark renvoie l'user vers Instagram (deeplink instagram://)

  → User est sur Instagram, timer tourne en natif

### Flow pause/reprise 45 secondes

Instagram passe en arrière-plan

  → DeviceActivityMonitor détecte la sortie du foreground

  → Écrit KEY\_SESSION\_PAUSED\_AT \= now() \+ KEY\_SESSION\_REMAINING\_MS \= temps restant

  → Lance un schedule DeviceActivity de 45 secondes

User revient sur Instagram dans les 45s

  → DeviceActivityMonitor détecte le retour au foreground

  → Reprend le timer depuis KEY\_SESSION\_REMAINING\_MS

  → Efface KEY\_SESSION\_PAUSED\_AT

45s écoulées sans retour

  → DeviceActivityMonitor déclenche silentReset()

  → Efface tous les KEY\_SESSION\_\* dans UserDefaults

  → Retire le Shield si actif

  → Envoie onSessionCancelled à Flutter via MethodChannel → reset timer Flutter

### Flow fin de session (écran Shield)

Timer expire (KEY\_SESSION\_END\_TIME atteint)

  → DeviceActivityMonitor rebloque Instagram via ManagedSettingsStore.shield.applications

  → iOS affiche l'écran Shield Spark par-dessus Instagram

  → SparkShieldConfiguration affiche :

      Titre : "Session terminée"

      Sous-titre : "Tu as tenu \[durée\]. Que veux-tu faire ?"

      Bouton primaire : "Bloquer 5 min"

      Bouton secondaire : "Terminer la session"

User tape "Bloquer 5 min" (bouton primaire)

  → ShieldActionExtension écrit KEY\_BLOCK\_UNTIL \= now() \+ 5min dans UserDefaults

  → Démarre un DeviceActivity schedule de 5 min

  → Shield reste actif → Instagram reste bloqué 5 min

  → À l'expiration des 5 min : DeviceActivityMonitor retire le Shield automatiquement

User tape "Terminer la session" (bouton secondaire)

  → ShieldActionExtension efface tous les KEY\_SESSION\_\* dans UserDefaults

  → ShieldActionExtension répond .close au ShieldActionResponse

  → iOS ferme Instagram \+ Shield → user se retrouve sur l'écran d'accueil

  → Si l'user rouvre Instagram → Shortcut se redéclenche → écran d'intention → nouvelle session

### Flow Mode Focus

User configure le Focus (objectif \+ apps à bloquer) → tap "Lancer"

  → Flutter appelle setFocusMode(true, tokens) via MethodChannel

  → Swift écrit KEY\_FOCUS\_ACTIVE \= true \+ KEY\_FOCUS\_TOKENS dans UserDefaults

  → ManagedSettingsStore shield les apps Focus

User ouvre une app bloquée en mode Focus

  → Shortcut se déclenche → SparkAppIntent détecte KEY\_FOCUS\_ACTIVE \= true

  → Répond .close → Shield ManagedSettings s'affiche directement (pas d'écran d'intention)

  → Shield affiche : "Tu es en mode Focus" \+ objectif

  → Un seul bouton : "Fermer" (.close) → retour écran d'accueil

User coche son objectif sur le dashboard

  → Flutter appelle setFocusMode(false, \[\]) via MethodChannel

  → Swift efface KEY\_FOCUS\_ACTIVE \+ KEY\_FOCUS\_TOKENS

  → ManagedSettingsStore retire le Shield → toutes les apps se débloquent

---

## 7\. ÉCRAN SHIELD — COMPORTEMENT ET LIMITES

L'écran Shield Apple a une structure fixe imposée par iOS :

- Icône de l'app bloquée (automatique)  
- Titre (customisable via ShieldConfigurationExtension)  
- Sous-titre (customisable)  
- Bouton primaire (customisable label)  
- Bouton secondaire (customisable label)

**Ce qu'on peut faire :** textes, labels des boutons, logique des actions. **Ce qu'on ne peut PAS faire :**

- Countdown interactif (pas de timer visuel sur l'écran Shield)  
- Design Flutter custom (c'est une UI native Apple)  
- lockNow() / mise en veille de l'écran — impossible sur iOS  
- Ouvrir l'app principale depuis le Shield via API officielle

Le countdown 20s avant "Terminer" (présent sur Android) n'est pas reproductible sur iOS. Remplacé par un sous-titre texte invitant à la réflexion.

---

## 8\. SETUP SHORTCUTS (côté utilisateur)

L'user doit créer une automation Shortcuts une fois par réseau surveillé :

Shortcuts → Automatisation → Nouvelle automatisation personnelle

→ Déclencheur : App → Instagram → "Est ouverte"

→ Action : Activer Spark (SparkAppIntent)

→ Exécuter immédiatement (sans confirmation)

À répéter pour TikTok et YouTube.

Sur iOS 26 : le flow est natif et sans boucle infinie grâce à .foreground(.dynamic). Sur iOS 16–25 : fallback nécessaire (workaround boucle infinie à implémenter).

---

## 9\. PERMISSIONS REQUISES (iOS)

| Permission | Usage |
| :---- | :---- |
| FamilyControls (entitlement Apple) | Accès Screen Time API — approbation manuelle sur developer.apple.com |
| NSFamilyControlsUsageDescription | Texte affiché lors de la demande d'autorisation |
| URL Scheme spark:// | Deeplink retour vers Instagram après session |
| App Group group.com.example.spark | Storage partagé Runner \+ toutes les extensions |

---

## 10\. ENTITLEMENTS ET CONFIGURATION XCODE

### Fichier Runner.entitlements

\<key\>com.apple.developer.family-controls\</key\>

\<true/\>

\<key\>com.apple.security.application-groups\</key\>

\<array\>

  \<string\>group.com.example.spark\</string\>

\</array\>

⚠️ L'entitlement com.apple.developer.family-controls doit être demandé sur developer.apple.com avant tout test sur device réel. Délai d'approbation : 2–5 jours.

### Toutes les extensions partagent le même App Group

Ajouter group.com.example.spark dans les entitlements de chaque target :

- Runner  
- SparkShieldConfiguration  
- SparkShieldAction  
- SparkDeviceActivityMonitor

---

## 11\. CE QUI EST PORTÉ DE ANDROID (réutilisable tel quel)

- ✅ Tout le code Dart/Flutter (screens, providers, models, widgets)  
- ✅ Design system (AppColors, typographie, thème)  
- ✅ go\_router et navigation  
- ✅ Hive storage Flutter  
- ✅ Logique Riverpod  
- ✅ intention\_screen, session\_timer\_screen, dashboard\_screen, focus\_config\_screen

---

## 12\. CE QUI EST À CRÉER (spécifique iOS)

- ❌ AppDelegate.swift — MethodChannel \+ URL scheme handler  
- ❌ SparkAppIntent.swift — App Intent Shortcuts avec Launch Pass logic  
- ❌ SparkShieldConfiguration extension — titre/sous-titre/boutons écran Shield fin de session  
- ❌ SparkShieldAction extension — "Bloquer 5 min" (.defer \+ schedule 5 min) / "Terminer" (.close \+ reset)  
- ❌ SparkDeviceActivityMonitor extension — timer session \+ pause/reprise 45s \+ reblocage  
- ❌ family\_controls\_service.dart — remplace monitor\_service.dart  
- ❌ permissions\_screen.dart — simplifiée (1 seule permission FamilyControls)  
- ❌ Configuration Xcode : entitlements, App Groups, URL scheme spark://

---

## 13\. DEVICE DE TEST

| Device | OS | Notes |
| :---- | :---- | :---- |
| iPhone (cable ou TestFlight) | iOS 16+ | FamilyControls ne fonctionne pas sur simulateur Xcode |

Tout test doit se faire sur device réel. Le simulateur ne supporte pas Screen Time API.

---

## 14\. COMMANDES UTILES

\# Lancer sur iPhone connecté en cable

flutter run \-d \<device\_id\>

\# Lister les devices iOS connectés

flutter devices

\# Build IPA pour TestFlight

flutter build ipa

\# Ouvrir Xcode pour gérer extensions et entitlements

open ios/Runner.xcworkspace

---

## 15\. RÈGLES POUR CLAUDE CODE (iOS)

1. Toujours lire ce fichier en premier avant toute modification  
2. Une seule tâche à la fois  
3. Jamais de couleurs hardcodées — toujours AppColors.X  
4. Pas de setState pour la logique métier — tout passe par Riverpod  
5. Tout storage partagé entre Runner et extensions passe par App Group UserDefaults (group.com.example.spark) — jamais par Hive (inaccessible aux extensions Swift)  
6. Toujours vérifier le timestamp KEY\_SESSION\_END\_TIME plutôt qu'un booléen seul  
7. L'écran de fin de session est l'écran Shield natif iOS — ne pas créer de session\_end\_screen Flutter  
8. Pas de lockNow() ni mise en veille — impossible sur iOS  
9. Tester sur device réel uniquement (simulateur ne supporte pas FamilyControls)  
10. Après chaque modification du flow, tester dans l'ordre : Shortcut → intention → session → pause 45s → fin de session → Shield → "Terminer" → retour accueil

