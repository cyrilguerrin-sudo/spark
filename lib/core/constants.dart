class AppDurations {
  AppDurations._();

  static const int sessionTimerMaxMinutes = 20;
  static const int sessionTimerMaxMinutesRepeated = 10;
  static const int continueButtonDelaySeconds = 20;
  static const int blockDurationMinutes = 30;
  static const int blockInstaDurationMinutes = 5;
  static const int continueSessionDurationMinutes = 10;
}

class AppStrings {
  AppStrings._();

  static const String appName = 'Spark';

  // Dashboard
  static const String dashboardGreeting = 'Salut ';
  static const String dashboardThanksToSpark = 'Grâce à Spark';
  static const String dashboardWithoutSpark = 'Si tu n\'avais pas Spark';
  static const String dashboardRecentSessions = 'Sessions récentes';
  static const String dashboardStatsSectionTitle =
      'Temps de réseaux sociaux aujourd\'hui :';
  static const String dashboardFlameHint =
      'Appuie sur la flamme pour lancer le mode Focus';

  // Onboarding
  static const String onboardingTitle =
      'Pour que Spark fonctionne correctement, il faut activer certaines autorisations';
  static const String onboardingSubtitle =
      'Tes données sont complètement privées et ne quittent pas ton téléphone';
  static const String onboardingCta = 'Continuer !';

  // Intention
  static const String intentionTitlePrefix = 'Salut ';
  static const String intentionSubtitlePrefix = 'Pourquoi tu ouvres ';
  static const String intentionSubtitleSuffix = ' ?';
  static const List<String> intentionOptions = [
    'Parler avec mes amis',
    'Je cherche un truc de précis',
    'Poster',
    'Je mérite une pause',
    'L\'habitude, sans raison',
  ];
  static const String intentionClose = 'Fermer';
  static const String intentionProceed = 'Entrer quand même';
  static const String continueCta = 'Continuer';

  // Timer de session
  static const String timerQuestion = 'Combien de temps tu te donnes ?';
  static const String timerLaunch = 'Lancer la session';

  // Fin de session — mode normal
  static const String sessionEndTitle =
      'Tu as terminé ta session !\nEt c\'est à toi de décider de la suite !';
  static const String sessionEndBlockButton = 'Bloquer Insta 5min';
  static const String sessionEndBlockSubtitle =
      'Le temps de déconnecter et de se remettre en mouvement';
  static const String sessionEndContinue = 'Continuer quand même';
  static const String sessionEndContinueSubtitle = 'Retour au dashboard';
  static const String sessionEndContinueCountdownPrefix = 'disponible dans ';
  static const String sessionEndContinueCountdownSuffix = 's';

  // Fin de session — mode blocage actif (Instagram bloqué 5min)
  static const String sessionEndBlockedTitle = 'Instagram est bloqué';
  static const String sessionEndBlockedButton = 'Ok, je ferme';
  static const String sessionEndBlockedCountdownPrefix = 'Se débloque dans ';

  // Redirection de sortie
  static const String redirectTitle =
      'Tu t\'en es rendu compte, et c\'est déjà énorme !';
  static const String redirectQuestion =
      'Qu\'est-ce que tu veux faire maintenant ?';
  static const String redirectOpt1 = 'Me reposer vraiment';
  static const String redirectOpt1Sub = 'Pas sur un écran, une vraie pause.';
  static const String redirectOpt2 = 'Avancer sur quelque chose';
  static const String redirectOpt2Sub = 'revenir à ce qui compte';
  static const String redirectOpt3 = 'Faire autre chose librement';
  static const String redirectOpt3Sub = 'Sortir de ce piège addictif.';
  static const String redirectValidatePrefix = 'Valider et bloquer ';
  static const String redirectValidateSuffix = ' pour 30min';

  // Spark Focus — config
  static const String focusConfigQuestion =
      'C\'est quoi ton objectif pour cette session ?';
  static const String focusConfigPlaceholder = 'Exemple : Terminer mon montage..';
  static const String focusConfigBlockedApps = 'Apps bloquées :';
  static const String focusConfigNote =
      'Tu devras cocher ton objectif pour déverrouiller les apps.';
  static const String focusConfigLaunch = 'Lancer la session';

  // Spark Focus — interception
  static const String focusBlockedTitle = 'Tu es en mode Focus !';
  static const String focusBlockedNote =
      'Tu devras cocher ton objectif pour déverrouiller les apps.';
  static const String focusBlockedReturn = 'Retourner travailler';
  static const String focusBlockedUnlockPrefix = 'Déverrouiller ';

  // Edit screen
  static const String editTitle =
      'Sélectionne les réseaux sociaux pour lesquels tu veux que Spark intervienne';

  // Profil screen
  static const String profilMemberSincePrefix = 'Membre depuis le ';
}

/// Option d'intention associée à une action :
/// - deepLink == null  → ferme sans ouvrir l'app (ex: "L'habitude")
/// - deepLink == ''    → ouvre l'app normalement (launch par défaut)
/// - deepLink == uri   → ouvre l'app sur l'onglet correspondant
class IntentionOption {
  final String label;
  final String? deepLink;

  const IntentionOption({required this.label, this.deepLink = ''});

  bool get closesApp => deepLink == null;
}

class AppNetworks {
  AppNetworks._();

  static const String instagram = 'instagram';
  static const String tiktok = 'tiktok';
  static const String youtube = 'youtube';
  static const String twitter = 'twitter';
  static const String snapchat = 'snapchat';
  static const String facebook = 'facebook';

  static const Map<String, String> names = {
    instagram: 'Instagram',
    tiktok: 'TikTok',
    youtube: 'YouTube',
    twitter: 'Twitter / X',
    snapchat: 'Snapchat',
    facebook: 'Facebook',
  };

  static const Map<String, String> androidPackages = {
    instagram: 'com.instagram.android',
    tiktok: 'com.zhiliaoapp.musically',
    youtube: 'com.google.android.youtube',
    twitter: 'com.twitter.android',
    snapchat: 'com.snapchat.android',
    facebook: 'com.facebook.katana',
  };

  /// Options d'intention par réseau.
  /// Instagram : deep links vers les onglets natifs.
  /// Autres réseaux : lancement par défaut (deepLink = '').
  static List<IntentionOption> intentionsFor(String networkId) {
    switch (networkId) {
      case instagram:
        return const [
          // scheme natif instagram:// via intent URI (plus fiable que le HTTPS App Link pour l'inbox)
          IntentionOption(
            label: 'Parler avec mes amis',
            deepLink: 'intent://direct-inbox#Intent;package=com.instagram.android;scheme=instagram;end',
          ),
          IntentionOption(
            label: 'Je cherche un truc de précis',
            deepLink: 'https://www.instagram.com/explore/',
          ),
          // intent:// URI confirmé pour la story/caméra Instagram sur Android récent
          IntentionOption(
            label: 'Poster',
            deepLink: 'intent://story-camera#Intent;package=com.instagram.android;scheme=instagram;end',
          ),
          IntentionOption(
            label: 'Je mérite une pause',
            deepLink: '', // lancement par défaut
          ),
          IntentionOption(
            label: 'L\'habitude, sans raison',
            deepLink: null, // ferme sans ouvrir
          ),
        ];
      case tiktok:
        return const [
          IntentionOption(
            label: 'Je cherche un truc de précis',
            deepLink: 'https://www.tiktok.com/search',
          ),
          IntentionOption(
            label: 'Je mérite une pause',
            deepLink: '',
          ),
          IntentionOption(
            label: 'L\'habitude, sans raison',
            deepLink: null,
          ),
        ];
      case youtube:
        return const [
          IntentionOption(
            label: 'Je cherche un truc de précis',
            deepLink: 'https://www.youtube.com/results?search_query=',
          ),
          IntentionOption(
            label: 'Je mérite une pause',
            deepLink: '',
          ),
          IntentionOption(
            label: 'L\'habitude, sans raison',
            deepLink: null,
          ),
        ];
      default:
        return const [
          IntentionOption(label: 'Parler avec mes amis'),
          IntentionOption(label: 'Je cherche un truc de précis'),
          IntentionOption(label: 'Poster'),
          IntentionOption(label: 'Je mérite une pause'),
          IntentionOption(label: 'L\'habitude, sans raison', deepLink: null),
        ];
    }
  }
}
