import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../models/session.dart';
import '../providers/sessions_provider.dart';
import '../providers/session_timer_provider.dart';
import '../services/app_blocker_service.dart';
import '../services/family_controls_service.dart';
import '../widgets/time_slider.dart';

class SessionTimerScreen extends ConsumerStatefulWidget {
  final String networkId;
  final String intention;
  final String deepLink;

  const SessionTimerScreen({
    super.key,
    required this.networkId,
    required this.intention,
    this.deepLink = '',
  });

  @override
  ConsumerState<SessionTimerScreen> createState() =>
      _SessionTimerScreenState();
}

class _SessionTimerScreenState extends ConsumerState<SessionTimerScreen> {
  int _selectedMinutes = 0;

  Future<void> _launchSession() async {
    final endTimeMs = DateTime.now()
        .add(Duration(minutes: _selectedMinutes))
        .millisecondsSinceEpoch;

    final session = Session(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      networkId: widget.networkId,
      networkName: AppNetworks.names[widget.networkId] ?? widget.networkId,
      intention: widget.intention,
      plannedDurationMinutes: _selectedMinutes,
      actualDurationMinutes: _selectedMinutes,
      startTime: DateTime.now(),
    );
    ref.read(sessionsProvider.notifier).addSession(session);
    ref.read(sessionTimerProvider.notifier).start(widget.networkId, _selectedMinutes);

    if (Platform.isIOS) {
      // Sur iOS, c'est FamilyControls (channel familycontrols) qui gère le Shield.
      // MonitorService utilise le channel Android-only et ne fait rien sur iOS.
      await FamilyControlsService.setSessionEndTime(endTimeMs, widget.networkId);
      if (mounted) {
        context.go('/session-started', extra: {
          'networkId': widget.networkId,
          'durationMinutes': _selectedMinutes,
        });
      }
    } else {
      // Sur Android, ouvre l'app directement puis revient au dashboard.
      final pkg = AppNetworks.androidPackages[widget.networkId];
      if (pkg != null) {
        await AppBlockerService.launchWithDeepLink(
          deepLink: widget.deepLink,
          packageName: pkg,
        );
      }
      if (mounted) context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Bouton retour ──
            IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: AppColors.textPrimary,
                size: 22,
              ),
              onPressed: () => context.pop(),
            ),

            // ── Contenu centré ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.timerQuestion,
                      style: AppTextStyles.body,
                    ),
                    const SizedBox(height: 28),

                    // Slider + valeur
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bgCardSurface,
                        borderRadius:
                            BorderRadius.circular(AppRadius.card),
                      ),
                      child: TimeSlider(
                        value: _selectedMinutes,
                        maxMinutes: AppDurations.sessionTimerMaxMinutes,
                        onChanged: (v) =>
                            setState(() => _selectedMinutes = v),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Bouton lancer ──
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 36),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedMinutes > 0 ? _launchSession : null,
                  style: ElevatedButton.styleFrom(
                    disabledBackgroundColor: AppColors.bgCardSurface,
                    disabledForegroundColor: AppColors.textMuted,
                  ),
                  child: const Text(AppStrings.timerLaunch),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
