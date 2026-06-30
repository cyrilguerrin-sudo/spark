import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../providers/focus_provider.dart';

class FocusConfigScreen extends ConsumerStatefulWidget {
  const FocusConfigScreen({super.key});

  @override
  ConsumerState<FocusConfigScreen> createState() => _FocusConfigScreenState();
}

class _FocusConfigScreenState extends ConsumerState<FocusConfigScreen> {
  late final TextEditingController _objectiveController;

  @override
  void initState() {
    super.initState();
    _objectiveController = TextEditingController();
  }

  @override
  void dispose() {
    _objectiveController.dispose();
    super.dispose();
  }

  Future<void> _launchSession() async {
    final objective = _objectiveController.text.trim();
    await ref.read(focusProvider.notifier).activate(
          objective: objective.isEmpty ? 'Session Focus' : objective,
          blockedApps: [
            AppNetworks.instagram,
            AppNetworks.tiktok,
            AppNetworks.youtube,
          ],
        );
    if (mounted) context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // ── Bouton retour ──
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.textPrimary,
                  size: 22,
                ),
                onPressed: () => context.go('/dashboard'),
              ),
            ),

            // ── Contenu scrollable ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const _SmallFlame(),
                    const SizedBox(height: 24),

                    const Text(
                      AppStrings.focusConfigQuestion,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _objectiveController,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body
                          .copyWith(color: AppColors.textSecondary),
                      decoration: const InputDecoration(
                        hintText: AppStrings.focusConfigPlaceholder,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    const Text(
                      AppStrings.focusConfigBlockedApps,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 14),

                    for (final id in [
                      AppNetworks.instagram,
                      AppNetworks.tiktok,
                      AppNetworks.youtube,
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.bgCardSurface,
                            borderRadius:
                                BorderRadius.circular(AppRadius.button),
                            border: Border.all(
                              color: AppColors.bgCardBorder,
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              AppNetworks.names[id]!,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),

                    Text(
                      AppStrings.focusConfigNote,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _launchSession,
                        child: const Text(AppStrings.focusConfigLaunch),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Flamme petite + lueur ────────────────────────────────────────────────────

class _SmallFlame extends StatelessWidget {
  const _SmallFlame();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Image.asset(
          'assets/images/flame_glow.png',
          height: 117,
          fit: BoxFit.contain,
        ),
        Image.asset(
          'assets/images/flame_3d.png',
          height: 90,
          fit: BoxFit.contain,
        ),
      ],
    );
  }
}
