import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../models/session.dart';
import '../models/social_network.dart';
import '../providers/sessions_provider.dart';
import '../providers/focus_provider.dart';
import '../providers/networks_provider.dart';
import '../providers/session_timer_provider.dart';
import '../services/storage_service.dart';
import '../services/monitor_service.dart';
import '../widgets/bottom_nav.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  /// Simule l'interception que ferait l'Accessibility Service Android.
  /// → Focus ON + app bloquée  : focus_blocked_screen
  /// → Focus OFF (ou non bloqué) : intention_screen
  static void _openNetwork(BuildContext context, WidgetRef ref, String networkId) {
    final focus = ref.read(focusProvider);
    if (focus != null && focus.blockedApps.contains(networkId)) {
      context.push('/focus-blocked', extra: {'networkId': networkId});
    } else {
      context.push('/intention', extra: {'networkId': networkId});
    }
  }

  String _formatMinutes(int minutes) {
    if (minutes <= 0) return '0 min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '${h}h${m.toString().padLeft(2, '0')}';
    if (h > 0) return '${h}h00';
    return '${m}min';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ── Listener : timer expiré → session_end_screen ────────────────────────
    ref.listen<SessionTimerState>(sessionTimerProvider, (_, next) {
      if (next.status == TimerStatus.expired) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            // Ramène Spark au premier plan si l'utilisateur est sur le réseau social
            MonitorService.bringToFront();
            // NE PAS reset ici — le reset se fait dans session_end_screen
            // quand l'utilisateur fait son choix (continuer ou redirection)
            context.push('/session-end', extra: {'networkId': next.networkId});
          }
        });
      }
    });

    final sessions = ref.watch(sessionsProvider);
    final focusSession = ref.watch(focusProvider);
    final enabledNetworks = ref.watch(networksProvider)
        .where((n) => n.isEnabled)
        .toList();
    final todaySessions = sessions.where((s) => s.isToday).toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));

    final savedMinutes = todaySessions
        .where((s) => s.isRespected)
        .fold(0, (sum, s) => sum + s.deltaMinutes.abs());

    final firstName = StorageService.firstName;
    final greeting = firstName.isEmpty ? 'Salut !' : 'Salut $firstName !';

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Greeting ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 48, 22, 0),
                      child: Text(greeting, style: AppTextStyles.titleLarge),
                    ),
                    const SizedBox(height: 20),

                    // ── Barre Focus (visible si mode Focus actif) ──
                    if (focusSession != null) ...[
                      _FocusActiveBar(
                        objective: focusSession.objective,
                        blockedApps: focusSession.blockedApps,
                        onStop: () {
                          ref.read(focusProvider.notifier).endSession();
                          ref.read(sessionTimerProvider.notifier).reset();
                        },
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ── Flamme centrale ──
                    _FlameSection(
                      onTap: () => context.push('/focus-config'),
                    ),
                    const SizedBox(height: 28),

                    // ── Stats du jour ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            AppStrings.dashboardStatsSectionTitle,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  label: AppStrings.dashboardThanksToSpark,
                                  value: _formatMinutes(savedMinutes),
                                  valueColor: AppColors.green,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                  label: AppStrings.dashboardWithoutSpark,
                                  value: '3h00',
                                  valueColor: AppColors.orange,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Sessions récentes ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.dashboardRecentSessions,
                            style: AppTextStyles.sectionLabel.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (todaySessions.isEmpty)
                            const _EmptySessionsState()
                          else
                            ...todaySessions.map(
                              (s) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _SessionRow(session: s),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Réseaux surveillés ──────────────────────────────────
                    // Simule l'interception Accessibility Service en prototype.
                    // Prod : ce déclencheur est remplacé par le service natif Android.
                    if (enabledNetworks.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Réseaux surveillés',
                              style: AppTextStyles.sectionLabel.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...enabledNetworks.map(
                              (n) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _NetworkLaunchCard(
                                  network: n,
                                  isBlocked: focusSession != null &&
                                      focusSession.blockedApps.contains(n.id),
                                  onTap: () =>
                                      _openNetwork(context, ref, n.id),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── Bottom nav ──
            SparkBottomNav(
              currentIndex: 0,
              onTap: (i) {
                if (i == 1) context.go('/edit');
                if (i == 2) context.go('/profil');
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Barre Mode Focus actif ───────────────────────────────────────────────────

class _FocusActiveBar extends ConsumerWidget {
  final String objective;
  final List<String> blockedApps;
  final VoidCallback onStop;

  const _FocusActiveBar({
    required this.objective,
    required this.blockedApps,
    required this.onStop,
  });

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(sessionTimerProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bgCardSurface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.orange, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ligne titre + timer + fermer
            Row(
              children: [
                const Icon(
                  Icons.local_fire_department,
                  color: AppColors.orange,
                  size: 14,
                ),
                const SizedBox(width: 6),
                const Text(
                  'MODE FOCUS',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: AppColors.orange,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                if (timer.isActive)
                  Text(
                    _fmt(timer.remaining),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.orange,
                      letterSpacing: -0.5,
                    ),
                  ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: onStop,
                  child: const Icon(
                    Icons.close,
                    color: AppColors.textMuted,
                    size: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Objectif
            Text(
              objective.isEmpty ? 'Session Focus' : objective,
              style: AppTextStyles.body
                  .copyWith(color: AppColors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // Apps bloquées — tap pour simuler l'interception
            if (blockedApps.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Bloqué : ',
                    style: AppTextStyles.caption,
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: blockedApps.map((id) {
                        final name = AppNetworks.names[id] ?? id;
                        return GestureDetector(
                          onTap: () => context.push(
                            '/focus-blocked',
                            extra: {'networkId': id},
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.bgCardBorder,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              name,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Flamme + lueur ──────────────────────────────────────────────────────────

class _FlameSection extends StatelessWidget {
  final VoidCallback onTap;

  const _FlameSection({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 220,
                  height: 220,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color(0x33FF5500),
                        Color(0x00FF5500),
                      ],
                    ),
                  ),
                ),
                Image.asset(
                  'assets/images/flame_3d.png',
                  height: 150,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            AppStrings.dashboardFlameHint,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Carte stat ───────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.bgCardSurface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.metricLarge.copyWith(
              fontSize: 40,
              letterSpacing: -2.0,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ligne session ────────────────────────────────────────────────────────────

class _SessionRow extends StatelessWidget {
  final Session session;

  const _SessionRow({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.bgCardSurface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${session.formattedStartTime} - ${session.networkName}',
            style: AppTextStyles.body,
          ),
          Text(
            session.formattedDelta,
            style: AppTextStyles.body.copyWith(
              color: session.isRespected ? AppColors.green : AppColors.red,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Carte réseau (déclencheur d'interception) ────────────────────────────────

class _NetworkLaunchCard extends StatelessWidget {
  final SocialNetwork network;
  final bool isBlocked;
  final VoidCallback onTap;

  const _NetworkLaunchCard({
    required this.network,
    required this.isBlocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bgCardSurface,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          children: [
            Text(network.name, style: AppTextStyles.networkName),
            const Spacer(),
            if (isBlocked) ...[
              const Icon(Icons.lock_outline,
                  color: AppColors.orange, size: 14),
              const SizedBox(width: 4),
              Text(
                'Focus bloqué',
                style:
                    AppTextStyles.caption.copyWith(color: AppColors.orange),
              ),
            ] else
              const Icon(Icons.arrow_forward_ios,
                  color: AppColors.textMuted, size: 14),
          ],
        ),
      ),
    );
  }
}

// ── État vide ────────────────────────────────────────────────────────────────

class _EmptySessionsState extends StatelessWidget {
  const _EmptySessionsState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          'Aucune session aujourd\'hui',
          style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
        ),
      ),
    );
  }
}
