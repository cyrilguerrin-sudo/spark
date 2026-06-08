# CLAUDE.md — Spark App

## 1. CONTEXTE DU PROJET

Spark est une application mobile Flutter (Android + iOS) anti-doomscrolling. Elle intercepte l'ouverture des réseaux sociaux et crée des rituels conscients d'intention, de session et de sortie.

**3 mécanismes core :**
1. Intention à l'ouverture — l'utilisateur choisit pourquoi il ouvre le réseau
2. Contrat de session — il fixe une durée avant d'entrer
3. Redirection de sortie — une sortie guidée quand le timer expire

**Mode Spark Focus :**
- L'utilisateur définit un objectif de travail + apps à bloquer
- Si il tente d'ouvrir une app bloquée → écran de rappel avec sa to-do
- Il doit cocher son objectif pour débloquer l'accès

---

## 2. ÉTAT ACTUEL DU PROJET (ce qui fonctionne)

### ✅ Implémenté et fonctionnel
- **Interception Android** : AppMonitorService détecte l'ouverture d'Instagram via UsageStatsManager et lance MainActivity
- **Écran d'intention** : s'affiche quand l'utilisateur ouvre Instagram, avec les choix spécifiques au réseau
- **Timer de session natif** : KEY_SESSION_END_TIME écrit dans SharedPreferences, le service poll toutes les secondes
- **Device Admin / lockNow** : à l'expiration du timer, l'écran se verrouille automatiquement via DevicePolicyManager.lockNow()
- **Écran de fin de session** : s'affiche après le déverrouillage via KEY_PENDING_SESSION_ENDED
- **Deeplinks Instagram** : redirection vers le bon onglet selon l'intention choisie
- **3 permissions** : UsageStats, SYSTEM_ALERT_WINDOW, Device Admin (écran de permissions au premier lancement)
- **Sauvegarde des réseaux** : les réseaux sélectionnés dans Edit persistent via Hive
- **Anti-swipe** : mécanisme de cooldown 2s pour ramener l'utilisateur sur Spark si il tente de swiper pendant l'écran d'intention

### ⚠️ En cours / À corriger
- L'écran de fin de session peut être ignoré (l'utilisateur peut swiper)
- Après une session, il faut parfois re-toggler Instagram dans Edit pour que l'interception remarche

---

## 3. LOGIQUE DE SESSION — COMPORTEMENT ATTENDU

### Pendant la session
- Si l'utilisateur **ferme Instagram** (swipe depuis les apps récentes) → la session se termine silencieusement → la prochaine ouverture d'Instagram affichera l'écran d'intention normalement
- Si l'utilisateur **utilise une autre app** sans fermer Instagram (Instagram en arrière-plan) → la session **continue** normalement, le timer continue de tourner

### Fin de session (timer expire)
1. L'écran se verrouille automatiquement via `lockNow()`
2. L'utilisateur rallume l'écran → l'**écran de fin de session** s'affiche
3. Cet écran est **impossible à ignorer** :
   - Si l'utilisateur tente de swiper ou de fermer Spark → l'écran se réaffiche automatiquement
   - Si l'utilisateur tente d'ouvrir Instagram → l'écran d'intention NE s'affiche PAS, l'écran de fin de session se réaffiche à la place
   - L'écran reste actif tant qu'aucun des deux boutons n'est pressé

### Bouton 1 — "Bloquer Insta 5min"
- Instagram est bloqué pendant 5 minutes (toute tentative d'ouverture est interceptée sans montrer l'écran d'intention)
- L'écran de fin de session se ferme
- La session est terminée

### Bouton 2 — "Je suis encore là, continuer" (disponible après 20s)
- Lance une nouvelle session de 10 minutes
- À l'expiration des 10 minutes → même écran de fin de session réapparaît
- **Exception** : si l'utilisateur ferme Instagram pendant ces 10 minutes → la session se termine silencieusement, l'écran de fin de session ne réapparaît pas

---

## 4. STACK TECHNIQUE

- **Framework** : Flutter (Dart)
- **Cible** : Android + iOS (compiler sur Mac avec Xcode pour iOS)
- **État** : Riverpod
- **Storage local** : Hive
- **Animations** : flutter_animate
- **Blocage apps** : android_intent_plus + UsageStatsManager (Android)
- **Navigation** : go_router
- **Service natif** : AppMonitorService.kt (foreground service Android)
- **Device Admin** : SparkDeviceAdminReceiver.kt + device_admin_policies.xml

### pubspec.yaml — dépendances
```yaml
dependencies:
  flutter:
    sdk: flutter
  riverpod: ^2.5.1
  flutter_riverpod: ^2.5.1
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  flutter_animate: ^4.5.0
  go_router: ^13.0.0
  android_intent_plus: ^4.0.2
  permission_handler: ^11.3.0
  app_usage: ^3.0.1
  intl: ^0.19.0
```

---

## 5. DESIGN SYSTEM (extrait du Figma)

**Figma** : https://www.figma.com/design/TxnAKO8YNWFRXeaCN13E4m/Maquette-final-coeur-de-Spark?node-id=0-1

### Couleurs
```dart
static const Color bgPrimary = Color(0xFF0A0A0A);
static const Color bgCard = Color(0xFF111111);
static const Color bgCardBorder = Color(0xFF1E1E1E);
static const Color green = Color(0xFF268429);
static const Color greenLight = Color(0xFF4CAF50);
static const Color red = Color(0xFF843B26);
static const Color orange = Color(0xFFE05A3A);
static const Color textPrimary = Color(0xFFFFFFFF);
static const Color textSecondary = Color(0xFFBBBBBB);
static const Color textMuted = Color(0xFF555555);
```

### Typographie (Inter)
```dart
TextStyle titleLarge = TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w800, fontSize: 32, fontStyle: FontStyle.italic, letterSpacing: -1.6, color: Colors.white);
TextStyle metricLarge = TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w800, fontSize: 50, letterSpacing: -2.5);
TextStyle sectionLabel = TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 18, letterSpacing: -0.9, color: Color(0xFFBBBBBB));
TextStyle body = TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 14, letterSpacing: -0.7, color: Color(0xFFBBBBBB));
```

### Border radius
- Cards : 20px
- Boutons : 24px
- Bottom nav : 20px
- Écran complet : 44px

---

## 6. ARCHITECTURE NATIVE ANDROID

### Fichiers Kotlin
- `AppMonitorService.kt` — foreground service, poll toutes les secondes, gère l'interception et le timer
- `MainActivity.kt` — reçoit les intents du service, dispatch vers Flutter via MethodChannel
- `SparkDeviceAdminReceiver.kt` — receiver Device Admin minimal

### SharedPreferences clés importantes
```kotlin
const val KEY_MONITORED = "monitored_pkgs"          // Set<String> des packages surveillés
const val KEY_ACTIVE = "active_session_pkgs"         // Package en session active
const val KEY_SESSION_END_TIME = "session_end_time"  // Timestamp fin de session (ms)
const val KEY_SESSION_NETWORK_ID = "session_network" // networkId en cours ("instagram")
const val KEY_PENDING_SESSION_ENDED = "pending_session_ended" // Signal pour Flutter
const val KEY_FOCUS_ACTIVE = "focus_active"
const val KEY_FOCUS_PKGS = "focus_pkgs"
const val KEY_LOCK_PKG = "lock_pkg"                  // Anti-swipe pendant intention
```

### MethodChannel
- `onAppIntercepted(networkId, isFocus)` → Flutter navigue vers /intention ou /focus-blocked
- `onSessionEnded(networkId)` → Flutter reset timer + navigue vers /session-end
- `checkUsagePermission` / `openUsageSettings`
- `checkOverlayPermission` / `openOverlaySettings`
- `checkDeviceAdminPermission` / `openDeviceAdminSettings`

---

## 7. STRUCTURE DES FICHIERS

```
lib/
├── main.dart
├── app.dart                    # GoRouter + thème global + _handleNativeCall
├── core/
│   ├── theme.dart
│   ├── constants.dart
│   └── router.dart
├── models/
│   ├── social_network.dart
│   ├── session.dart
│   └── focus_session.dart
├── providers/
│   ├── sessions_provider.dart
│   ├── networks_provider.dart
│   ├── session_timer_provider.dart
│   └── focus_provider.dart
├── screens/
│   ├── splash_screen.dart
│   ├── onboarding_screen.dart
│   ├── permissions_screen.dart # 3 permissions requises
│   ├── dashboard_screen.dart
│   ├── edit_screen.dart
│   ├── profil_screen.dart
│   ├── intention_screen.dart
│   ├── session_timer_screen.dart
│   ├── session_end_screen.dart
│   ├── redirect_screen.dart
│   ├── focus_config_screen.dart
│   └── focus_blocked_screen.dart
├── widgets/
│   ├── flame_button.dart
│   ├── bottom_nav.dart
│   ├── session_card.dart
│   ├── network_toggle.dart
│   ├── time_slider.dart
│   └── permission_card.dart
└── services/
    ├── app_blocker_service.dart
    ├── monitor_service.dart
    ├── permission_service.dart
    ├── usage_service.dart
    └── storage_service.dart
```

---

## 8. ÉCRANS ET FLUX

### ÉCRAN 1 — Splash
- Fond noir, logo centré
- Redirect vers Dashboard si utilisateur connu, Permissions si première fois

### ÉCRAN 2 — Permissions (premier lancement)
- 3 cartes avec bouton "Activer" chacune :
  1. Accès à l'utilisation (UsageStats)
  2. Affichage par-dessus les apps (SYSTEM_ALERT_WINDOW)
  3. Administrateur de l'appareil (Device Admin)
- Bouton "Continuer" désactivé tant que les 3 permissions ne sont pas accordées
- Section "Autorisations" également accessible depuis l'onglet Profil

### ÉCRAN 3 — Dashboard
- Header : "Salut [Prénom] !" (Inter ExtraBold Italic, 32px)
- Flamme centrale cliquable → focus_config_screen
- Stats du jour (temps économisé vs sans Spark)
- Sessions récentes
- Bottom Nav : Home | Flamme Spark | Profil

### ÉCRAN 4 — Edit
- Liste des réseaux avec toggle ON/OFF
- Réseaux : Instagram, TikTok, YouTube, Twitter/X, Snapchat, Facebook
- La sélection est sauvegardée dans Hive et synchronisée avec AppMonitorService

### ÉCRAN 5 — Profil
- Infos utilisateur (nom, prénom, email)
- Section "Autorisations" avec les 3 permission cards

### ÉCRAN 6 — Intention ouverture réseau
- Déclenché par AppMonitorService quand une app surveillée est ouverte
- Titre : "Salut [Prénom] !"
- Sous-titre : "Pourquoi tu ouvres [réseau] ?"
- Boutons d'intention spécifiques au réseau (ex Instagram) :
  - "Parler avec mes amis" → deeplink chat
  - "Je cherche un truc précis" → deeplink explore
  - "Poster" → deeplink camera
  - "Je mérite une pause" → ouverture normale
  - "L'habitude, sans raison" → ferme et redirige vers Spark
- Bouton "Entrer quand même" grisé tant qu'aucune intention n'est cochée

### ÉCRAN 7 — Timer de session
- Slider 1-20 min (max 10 min si 2ème session aujourd'hui)
- Bouton "Lancer la session" grisé si slider = 0

### ÉCRAN 8 — Fin de session (À IMPLÉMENTER - design redesigné)
**Déclenché quand** : timer expire → lockNow() → utilisateur rallume l'écran

**Comportement** :
- L'écran est IMPOSSIBLE à ignorer (overlay WindowManager ou lockTask)
- Si l'utilisateur swipe / ferme Spark → l'écran se réaffiche automatiquement
- Si l'utilisateur ouvre Instagram → l'écran de fin de session se réaffiche (PAS l'écran d'intention)
- Reste actif jusqu'au choix d'un bouton

**Design** :
- Fond sombre #171A1A
- Titre : "Tu as terminé ta session ! Et c'est à toi de décider de la suite !"
- Image flamme 3D centrée (assets/images/flame_3d.png)
- **Bouton 1** — "Bloquer Insta 5min" (pill crème/orange, texte sombre)
  - Sous-titre : "Le temps de déconnecter et de se remettre en mouvement"
  - Action : bloque Instagram 5 min, ferme l'écran
- **Bouton 2** — "Je suis encore là, continuer" (pill gris sombre, texte blanc)
  - Disponible après **20 secondes** (countdown affiché)
  - Sous-titre : "10min supplémentaire pour terminer ce que je devais faire."
  - Action : lance une nouvelle session de 10 min, même logique de fin

### ÉCRAN 9 — Redirection de sortie
- Options : "Me reposer vraiment" / "Avancer sur quelque chose" / "Faire autre chose librement"
- Bouton "Valider et bloquer [réseau] pour 30min"

### ÉCRAN 10 — Configuration Spark Focus
- Objectif de travail (champ texte)
- Apps à bloquer (liste des réseaux activés)

### ÉCRAN 11 — Interception en mode Focus
- "Tu es en mode Focus !"
- Affiche l'objectif avec toggle
- Bouton "Retourner travailler"
- Si objectif coché : bouton "Déverrouiller [app]" en vert

---

## 9. LOGIQUE MÉTIER

### Détection fermeture Instagram pendant session
- Si Instagram n'a pas été au premier plan depuis plus de **3 minutes** pendant une session active → la session se termine silencieusement (clear KEY_SESSION_END_TIME, KEY_ACTIVE, KEY_SESSION_NETWORK_ID)
- Pas d'overlay, pas d'écran de fin → prochaine ouverture = écran d'intention normal

### Blocage 5min après fin de session
```kotlin
// Après bouton 1 "Bloquer Insta 5min"
prefs.putLong(KEY_BLOCK_UNTIL_MS, System.currentTimeMillis() + 5 * 60 * 1000)
prefs.putString(KEY_BLOCK_PKG, "com.instagram.android")
// Dans poll() : si blocked et pkg == blockPkg → intercepte avec cooldown 2s, pas d'écran d'intention
```

### Compteur de sessions (slider max)
```dart
int maxSessionDuration(String networkId) {
  return sessionCountToday(networkId) >= 1 ? 10 : 20;
}
```

### Blocage 30min après redirection
```dart
DateTime blockedUntil = DateTime.now().add(Duration(minutes: 30));
```

---

## 10. ASSETS

```
assets/
├── images/
│   ├── spark_logo.png
│   ├── flame_3d.png
│   ├── spark_logo_vector.png
│   └── spark_typography.png
└── fonts/
    └── Inter/ # Regular, Medium, SemiBold, Bold, ExtraBold (format Inter_18pt-*.ttf)
```

---

## 11. RÈGLES DE CODE

1. Jamais de couleurs hardcodées — toujours `AppColors.X`
2. Pas de setState pour la logique métier — tout passe par Riverpod
3. Nommage : snake_case, suffixe `_screen.dart` ou `_widget.dart`
4. Tous les textes passent par des constantes dans `core/constants.dart`
5. Bottom Nav est un widget global réutilisé
6. Device Admin requis pour lockNow() — toujours vérifier isAdminActive() avant d'appeler
7. Ne jamais modifier KEY_SESSION_END_TIME depuis Flutter directement — passer par MonitorService.setSessionEndTime()

---

## 12. COMMANDES UTILES

```bash
# Lancer sur le Honor (ID fixe)
flutter run -d AYAV6R3704035491

# Hot restart
r (dans le terminal flutter run)

# Build APK debug
flutter build apk --debug

# Sauvegarder sur GitHub
git add .
git commit -m "description"
git push origin main

# Désinstaller l'app du téléphone
adb uninstall com.example.spark
```

---

## 13. PROCHAINE ÉTAPE À IMPLÉMENTER

**Étape 1** — Modifier session_end_screen.dart + AppMonitorService pour que l'écran de fin de session soit impossible à ignorer, avec le nouveau design (bouton "Bloquer 5min" + "Continuer 10min" disponible après 20s).

**Étape 2** — Blocage 5min dans poll() : intercepter Instagram sans montrer l'écran d'intention.

**Étape 3** — Détection fermeture Instagram : si absent du premier plan > 3min pendant session → terminer silencieusement.

**Étape 4** — Synchronisation Flutter après choix bouton (reset timer, navigate dashboard).
