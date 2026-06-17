import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../providers/focus_provider.dart';

class FocusBlockedScreen extends ConsumerWidget {
  final String networkId;

  const FocusBlockedScreen({super.key, required this.networkId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(focusProvider);
    final isChecked = session?.isObjectiveChecked ?? false;
    final objective = session?.objective ?? '';
    final networkName = AppNetworks.names[networkId] ?? networkId;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // ── Flamme + titre (centrés) ──
            Expanded(
              child: Center(
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
                    const SizedBox(height: 24),
                    const Text(
                      AppStrings.focusBlockedTitle,
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
                  ],
                ),
              ),
            ),

            // ── Objectif + note + boutons ──
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 36),
              child: Column(
                children: [
                  // Card objectif avec toggle
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 6,
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
                              color: isChecked
                                  ? AppColors.textMuted
                                  : AppColors.textPrimary,
                              decoration: isChecked
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        CupertinoSwitch(
                          value: isChecked,
                          onChanged: isChecked
                              ? null
                              : (val) {
                                  if (val) {
                                    ref
                                        .read(focusProvider.notifier)
                                        .checkObjective();
                                  }
                                },
                          activeTrackColor: AppColors.greenLight,
                        ),
                      ],
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
                      onPressed: () => context.go('/dashboard'),
                      child: const Text(AppStrings.focusBlockedReturn),
                    ),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isChecked
                          ? () {
                              ref.read(focusProvider.notifier).endSession();
                              context.go('/dashboard');
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isChecked ? AppColors.greenLight : null,
                        foregroundColor: isChecked ? Colors.white : null,
                        disabledBackgroundColor: AppColors.bgCardSurface,
                        disabledForegroundColor: AppColors.textMuted,
                      ),
                      child: Text(
                        '${AppStrings.focusBlockedUnlockPrefix}$networkName',
                      ),
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
