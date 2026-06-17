import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../providers/focus_provider.dart';
import '../services/storage_service.dart';
import '../widgets/bottom_nav.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pseudo       = StorageService.pseudo;
    final greeting     = pseudo.isEmpty ? 'Salut !' : 'Salut $pseudo !';
    final focusSession = ref.watch(focusProvider);

    if (focusSession != null) {
      return _FocusDashboard(
        greeting: greeting,
        objective: focusSession.objective,
        onDeactivate: () => ref.read(focusProvider.notifier).deactivate(),
      );
    }

    return _NormalDashboard(
      greeting: greeting,
      onFocusTap: () => context.go('/focus-config'),
      onNavTap: (i) {
        if (i == 1) context.go('/edit');
        if (i == 2) context.go('/profil');
      },
    );
  }
}

// ── Dashboard normal ─────────────────────────────────────────────────────────

class _NormalDashboard extends StatelessWidget {
  final String greeting;
  final VoidCallback onFocusTap;
  final ValueChanged<int> onNavTap;

  const _NormalDashboard({
    required this.greeting,
    required this.onFocusTap,
    required this.onNavTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [Color(0xFF3D1A00), Color(0xFF0A0A0A)],
            radius: 0.85,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 48, 22, 0),
                child: Text(greeting, style: AppTextStyles.titleLarge),
              ),
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: onFocusTap,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Image.asset(
                              'assets/images/flame_glow.png',
                              height: 208,
                              fit: BoxFit.contain,
                            ),
                            Image.asset(
                              'assets/images/flame_3d.png',
                              height: 160,
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Appuie sur la flamme pour lancer le mode Focus',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            color: Color(0x80BBBBBB),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SparkBottomNav(currentIndex: 0, onTap: onNavTap),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Dashboard Focus actif ────────────────────────────────────────────────────

class _FocusDashboard extends StatelessWidget {
  final String greeting;
  final String objective;
  final VoidCallback onDeactivate;

  const _FocusDashboard({
    required this.greeting,
    required this.objective,
    required this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [Color(0xFF5C2000), Color(0xFF0A0A0A)],
            radius: 0.85,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 48, 22, 0),
                child: Text(greeting, style: AppTextStyles.titleLarge),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Tu es en mode Focus !',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w800,
                            fontStyle: FontStyle.italic,
                            fontSize: 28,
                            color: Colors.white,
                            letterSpacing: -1.2,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.bgCardSurface,
                            borderRadius: BorderRadius.circular(AppRadius.card),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  objective.isEmpty ? 'Session Focus' : objective,
                                  style: AppTextStyles.body.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              CupertinoSwitch(
                                value: false,
                                onChanged: (val) {
                                  if (val) onDeactivate();
                                },
                                activeTrackColor: AppColors.orange,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
      ),
    );
  }
}
