import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../providers/session_timer_provider.dart';
import '../services/monitor_service.dart';

class SessionEndScreen extends ConsumerStatefulWidget {
  final String networkId;
  final int blockedUntilMs;

  const SessionEndScreen({
    super.key,
    required this.networkId,
    this.blockedUntilMs = 0,
  });

  @override
  ConsumerState<SessionEndScreen> createState() => _SessionEndScreenState();
}

class _SessionEndScreenState extends ConsumerState<SessionEndScreen> {
  int _countdown = AppDurations.continueButtonDelaySeconds;
  int _blockRemainingSeconds = 0;
  Timer? _timer;

  bool get _isBlocked => widget.blockedUntilMs > 0;

  @override
  void initState() {
    super.initState();

    if (_isBlocked) {
      final remaining =
          widget.blockedUntilMs - DateTime.now().millisecondsSinceEpoch;
      _blockRemainingSeconds =
          (remaining / 1000.0).ceil().clamp(0, 9999);
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_isBlocked) {
        if (_blockRemainingSeconds <= 1) t.cancel();
        setState(() =>
            _blockRemainingSeconds = (_blockRemainingSeconds - 1).clamp(0, 9999));
      } else {
        if (_countdown <= 1) t.cancel();
        setState(() => _countdown = (_countdown - 1).clamp(0, 999));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _onBlockInsta() async {
    final pkg = AppNetworks.androidPackages[widget.networkId];
    if (pkg != null) {
      final blockUntilMs = DateTime.now()
          .add(const Duration(minutes: AppDurations.blockInstaDurationMinutes))
          .millisecondsSinceEpoch;
      await MonitorService.setBlockUntil(
        packageName: pkg,
        blockUntilMs: blockUntilMs,
      );
    }
    ref.read(sessionTimerProvider.notifier).reset();
    if (mounted) context.go('/dashboard');
  }

  void _onContinue() {
    ref.read(sessionTimerProvider.notifier).start(
      widget.networkId,
      AppDurations.continueSessionDurationMinutes,
    );
    context.go('/dashboard');
  }

  void _onCloseBlocked() {
    context.go('/dashboard');
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) =>
      _isBlocked ? _buildBlockedMode() : _buildSessionEndMode();

  // ── Layout normal — fin de session ────────────────────────────────────────

  Widget _buildSessionEndMode() {
    final canContinue = _countdown == 0;

    return Scaffold(
      backgroundColor: AppColors.bgSessionEnd,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Text(
                  AppStrings.sessionEndTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -1.4,
                    color: AppColors.textPrimary,
                    height: 1.25,
                  ),
                ),
              ),
              Expanded(child: _buildFlame()),
              Padding(
                padding: const EdgeInsets.only(bottom: 44),
                child: Column(
                  children: [
                    // Bouton 1 — Bloquer Insta 5min
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _onBlockInsta,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.cream,
                          foregroundColor: AppColors.orange,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.button),
                          ),
                          textStyle: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            letterSpacing: -0.5,
                          ),
                          elevation: 0,
                        ),
                        child: const Text(AppStrings.sessionEndBlockButton),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      AppStrings.sessionEndBlockSubtitle,
                      style: AppTextStyles.body,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // Bouton 2 — Continuer 10min (grisé pendant countdown)
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: canContinue ? _onContinue : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.bgCardSurface,
                          foregroundColor: AppColors.textPrimary,
                          disabledBackgroundColor: AppColors.bgCardSurface,
                          disabledForegroundColor: AppColors.textMuted,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.button),
                          ),
                          textStyle: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            letterSpacing: -0.5,
                          ),
                          elevation: 0,
                        ),
                        child: const Text(AppStrings.sessionEndContinue),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      AppStrings.sessionEndContinueSubtitle,
                      style: AppTextStyles.body,
                      textAlign: TextAlign.center,
                    ),
                    if (!canContinue) ...[
                      const SizedBox(height: 6),
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
      ),
    );
  }

  // ── Layout mode blocage actif ─────────────────────────────────────────────

  Widget _buildBlockedMode() {
    final mins = _blockRemainingSeconds ~/ 60;
    final secs = _blockRemainingSeconds % 60;
    final countdownText =
        mins > 0 ? '${mins}min ${secs}s' : '${secs}s';

    return Scaffold(
      backgroundColor: AppColors.bgSessionEnd,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Text(
                  AppStrings.sessionEndBlockedTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -1.4,
                    color: AppColors.textPrimary,
                    height: 1.25,
                  ),
                ),
              ),
              Expanded(child: _buildFlame()),
              Padding(
                padding: const EdgeInsets.only(bottom: 44),
                child: Column(
                  children: [
                    if (_blockRemainingSeconds > 0) ...[
                      Text(
                        '${AppStrings.sessionEndBlockedCountdownPrefix}$countdownText',
                        style: AppTextStyles.body,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _onCloseBlocked,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.bgCardSurface,
                          foregroundColor: AppColors.textPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.button),
                          ),
                          textStyle: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            letterSpacing: -0.5,
                          ),
                          elevation: 0,
                        ),
                        child: const Text(AppStrings.sessionEndBlockedButton),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Shared ────────────────────────────────────────────────────────────────

  Widget _buildFlame() {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 300,
            height: 300,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x50FF5500), Color(0x00FF5500)],
              ),
            ),
          ),
          Image.asset(
            'assets/images/flame_3d.png',
            height: 200,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }
}
