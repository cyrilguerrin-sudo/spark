import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../providers/focus_provider.dart';
import '../services/monitor_service.dart';

class FocusBlockedScreen extends ConsumerWidget {
  final String networkId;

  const FocusBlockedScreen({super.key, required this.networkId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session   = ref.watch(focusProvider);
    final objective = session?.objective ?? '';

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // ── Titre + flamme (centrés) ──
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      AppStrings.focusBlockedTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                        fontSize: 28,
                        color: AppColors.textPrimary,
                        letterSpacing: -1.2,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 32),
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
                  ],
                ),
              ),
            ),

            // ── Objectif + note + bouton ──
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 36),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgCardSurface,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: Text(
                      objective.isEmpty ? 'Session Focus' : objective,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text(
                    AppStrings.focusBlockedNote,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => MonitorService.goToHomeScreen(),
                      child: const Text('Fermer'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
