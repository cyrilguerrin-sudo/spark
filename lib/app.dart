import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'core/constants.dart';
import 'models/social_network.dart';
import 'models/focus_session.dart';
import 'providers/networks_provider.dart';
import 'providers/focus_provider.dart';
import 'providers/session_timer_provider.dart';
import 'services/monitor_service.dart';

class SparkApp extends ConsumerStatefulWidget {
  const SparkApp({super.key});

  @override
  ConsumerState<SparkApp> createState() => _SparkAppState();
}

class _SparkAppState extends ConsumerState<SparkApp> {
  static const _channel = MethodChannel('com.example.spark/permissions');

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler(_handleNativeCall);
    MonitorService.start();
    // Écrire l'état réel des providers dans SharedPreferences dès le démarrage.
    // Sans ça, KEY_ACTIVE peut rester stale d'une session précédente si l'app
    // a été tuée pendant qu'une session était active, bloquant toute interception.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncConfig());
  }

  /// Appelé par AppMonitorService (via MainActivity).
  /// Deux événements possibles :
  ///   onAppIntercepted  → l'utilisateur a ouvert une app surveillée
  ///   onSessionEnded    → le timer de session a expiré (détecté côté natif)
  Future<dynamic> _handleNativeCall(MethodCall call) async {
    final args = call.arguments is Map
        ? Map<String, dynamic>.from(call.arguments as Map)
        : <String, dynamic>{};
    final networkId = args['networkId'] as String? ?? '';

    if (call.method == 'onSessionCancelled') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(sessionTimerProvider.notifier).reset();
      });
      return;
    }

    if (call.method == 'onSessionEnded') {
      if (networkId.isEmpty) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Réinitialise le timer Dart (arrête le compte à rebours affiché)
        ref.read(sessionTimerProvider.notifier).reset();
        appRouter.go('/session-end', extra: {'networkId': networkId});
      });
      return;
    }

    if (call.method == 'onAppBlocked') {
      if (networkId.isEmpty) return;
      final blockUntilMs = args['blockUntilMs'] as int? ?? 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appRouter.go('/session-end', extra: {
          'networkId': networkId,
          'blockedUntilMs': blockUntilMs,
        });
      });
      return;
    }

    if (call.method == 'onAppIntercepted') {
      if (networkId.isEmpty) return;
      final isFocus = args['isFocus'] as bool? ?? false;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isFocus) {
          appRouter.go('/focus-blocked', extra: {'networkId': networkId});
        } else {
          appRouter.go('/intention', extra: {'networkId': networkId});
        }
      });
    }
  }

  /// Recalcule et envoie la config de surveillance au service natif.
  /// Ne touche pas à KEY_SESSION_END_TIME — écrit une seule fois par
  /// SessionTimerNotifier.start() via setSessionEndTime().
  void _syncConfig() {
    final networks = ref.read(networksProvider);
    final focus    = ref.read(focusProvider);
    final timer    = ref.read(sessionTimerProvider);

    final sessionActive = timer.isActive;

    MonitorService.updateConfig(
      monitoredNetworkIds: networks
          .where((n) => n.isEnabled)
          .map((n) => n.id)
          .toList(),
      activeSessionNetworkId: sessionActive ? timer.networkId : null,
      focusActive: focus != null,
      focusNetworkIds: focus?.blockedApps ?? [],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Sync config dès qu'un des providers change
    ref.listen<List<SocialNetwork>>(networksProvider,      (_, __) => _syncConfig());
    ref.listen<FocusSession?>(focusProvider,               (_, __) => _syncConfig());
    ref.listen<SessionTimerState>(sessionTimerProvider,    (_, __) => _syncConfig());

    return MaterialApp.router(
      title: AppStrings.appName,
      theme: AppTheme.dark,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
