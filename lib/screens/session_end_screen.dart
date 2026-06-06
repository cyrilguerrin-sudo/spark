import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../providers/session_timer_provider.dart';

class SessionEndScreen extends ConsumerStatefulWidget {
  final String networkId;

  const SessionEndScreen({super.key, required this.networkId});

  @override
  ConsumerState<SessionEndScreen> createState() => _SessionEndScreenState();
}

class _SessionEndScreenState extends ConsumerState<SessionEndScreen> {
  int _countdown = AppDurations.continueButtonDelaySeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown <= 1) t.cancel();
      setState(() => _countdown = (_countdown - 1).clamp(0, 999));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onGuidedExit() {
    // Reset du timer ici → service reprend la surveillance normale
    ref.read(sessionTimerProvider.notifier).reset();
    context.push('/redirect', extra: {'networkId': widget.networkId});
  }

  void _onContinue() {
    // Reset du timer ici → nouvelle session peut démarrer
    ref.read(sessionTimerProvider.notifier).reset();
    context.push('/session-timer', extra: {
      'networkId': widget.networkId,
      'intention': '',
    });
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _countdown == 0;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // ── Flamme + titre (centré) ──
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 240,
                          height: 240,
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
                          height: 170,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 22),
                      child: Text(
                        AppStrings.sessionEndTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 32,
                          color: AppColors.textPrimary,
                          letterSpacing: -1.5,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Boutons bas ──
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 36),
              child: Column(
                children: [
                  // Sortie guidée
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _onGuidedExit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.bgCardSurface,
                        foregroundColor: AppColors.textPrimary,
                      ),
                      child: const Text(AppStrings.sessionEndGuidedExit),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Continuer (grisé pendant le countdown)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: canContinue ? _onContinue : null,
                      style: ElevatedButton.styleFrom(
                        disabledBackgroundColor: AppColors.bgCardSurface,
                        disabledForegroundColor: AppColors.textMuted,
                      ),
                      child: const Text(AppStrings.sessionEndContinue),
                    ),
                  ),

                  if (!canContinue) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${AppStrings.sessionEndContinueCountdownPrefix}'
                      '$_countdown'
                      '${AppStrings.sessionEndContinueCountdownSuffix}',
                      style: AppTextStyles.caption,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
