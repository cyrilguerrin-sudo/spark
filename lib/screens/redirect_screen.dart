import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../providers/networks_provider.dart';

class RedirectScreen extends ConsumerStatefulWidget {
  final String networkId;

  const RedirectScreen({super.key, required this.networkId});

  @override
  ConsumerState<RedirectScreen> createState() => _RedirectScreenState();
}

class _RedirectScreenState extends ConsumerState<RedirectScreen> {
  int? _selectedIndex;

  static const _options = [
    (
      title: AppStrings.redirectOpt1,
      subtitle: AppStrings.redirectOpt1Sub,
    ),
    (
      title: AppStrings.redirectOpt2,
      subtitle: AppStrings.redirectOpt2Sub,
    ),
    (
      title: AppStrings.redirectOpt3,
      subtitle: AppStrings.redirectOpt3Sub,
    ),
  ];

  void _onValidate() {
    ref.read(networksProvider.notifier).blockNetwork(
          widget.networkId,
          const Duration(minutes: AppDurations.blockDurationMinutes),
        );
    context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final networkName =
        AppNetworks.names[widget.networkId] ?? widget.networkId;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Contenu scrollable ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 48, 22, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      AppStrings.redirectTitle,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.8,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      AppStrings.redirectQuestion,
                      style: AppTextStyles.body,
                    ),
                    const SizedBox(height: 28),

                    // Options de redirection
                    ...List.generate(_options.length, (i) {
                      final opt = _options[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _RedirectOption(
                          title: opt.title,
                          subtitle: opt.subtitle,
                          isSelected: _selectedIndex == i,
                          onTap: () =>
                              setState(() => _selectedIndex = i),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // ── Bouton valider ──
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 36),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedIndex != null ? _onValidate : null,
                  style: ElevatedButton.styleFrom(
                    disabledBackgroundColor: AppColors.bgCardSurface,
                    disabledForegroundColor: AppColors.textMuted,
                  ),
                  child: Text(
                    '${AppStrings.redirectValidatePrefix}'
                    '$networkName'
                    '${AppStrings.redirectValidateSuffix}',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Option de redirection (titre + sous-titre, sélectionnable) ───────────────

class _RedirectOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _RedirectOption({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bgCardSurface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: isSelected
                ? AppColors.textPrimary
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.caption),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check,
                color: AppColors.textPrimary,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}
