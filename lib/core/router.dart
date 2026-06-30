import 'package:go_router/go_router.dart';
import '../screens/splash_screen.dart';
import '../screens/permissions_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/profil_screen.dart';
import '../screens/intention_screen.dart';
import '../screens/session_timer_screen.dart';
import '../screens/session_end_screen.dart';
import '../screens/redirect_screen.dart';
import '../screens/focus_config_screen.dart';
import '../screens/focus_blocked_screen.dart';
import '../screens/network_selection_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/permissions',
      name: 'permissions',
      builder: (context, state) => const PermissionsScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      name: 'dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/profil',
      name: 'profil',
      builder: (context, state) => const ProfilScreen(),
    ),
    // extra: {'networkId': String}
    GoRoute(
      path: '/intention',
      name: 'intention',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return IntentionScreen(networkId: extra['networkId'] as String? ?? '');
      },
    ),
    // extra: {'networkId': String, 'intention': String, 'deepLink': String}
    GoRoute(
      path: '/session-timer',
      name: 'sessionTimer',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return SessionTimerScreen(
          networkId: extra['networkId'] as String? ?? '',
          intention: extra['intention'] as String? ?? '',
          deepLink: extra['deepLink'] as String? ?? '',
        );
      },
    ),
    // extra: {'networkId': String, 'blockedUntilMs': int?}
    GoRoute(
      path: '/session-end',
      name: 'sessionEnd',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return SessionEndScreen(
          networkId: extra['networkId'] as String? ?? '',
          blockedUntilMs: extra['blockedUntilMs'] as int? ?? 0,
        );
      },
    ),
    // extra: {'networkId': String}
    GoRoute(
      path: '/redirect',
      name: 'redirect',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return RedirectScreen(networkId: extra['networkId'] as String? ?? '');
      },
    ),
    GoRoute(
      path: '/focus-config',
      name: 'focusConfig',
      builder: (context, state) => const FocusConfigScreen(),
    ),
    // extra: {'networkId': String}
    GoRoute(
      path: '/focus-blocked',
      name: 'focusBlocked',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return FocusBlockedScreen(networkId: extra['networkId'] as String? ?? '');
      },
    ),
    GoRoute(
      path: '/network-select',
      name: 'networkSelect',
      builder: (context, state) => const NetworkSelectionScreen(),
    ),
  ],
);
