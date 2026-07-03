import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/constants.dart';

class IntentionScreen extends StatefulWidget {
  final String networkId;

  const IntentionScreen({super.key, required this.networkId});

  @override
  State<IntentionScreen> createState() => _IntentionScreenState();
}

class _IntentionScreenState extends State<IntentionScreen> {
  IntentionOption? _selected;

  String get _networkName =>
      AppNetworks.names[widget.networkId] ?? 'ce réseau';

  List<IntentionOption> get _options =>
      AppNetworks.intentionsFor(widget.networkId);

  void _onContinue() {
    HapticFeedback.mediumImpact();
    final option = _selected!;

    // "L'habitude, sans raison" → ferme sans ouvrir, retour dashboard
    if (option.closesApp) {
      context.go('/dashboard');
      return;
    }

    context.push('/session-timer', extra: {
      'networkId': widget.networkId,
      'intention': option.label,
      'deepLink': option.deepLink ?? '',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 48, 22, 0),
              child: Text(
                'Pourquoi tu ouvres $_networkName ?',
                style: AppTextStyles.titleLarge,
              ),
            ),

            // ── Options d'intention, centrées comme le slider du timer ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final option in _options)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _IntentionOption(
                          option: option,
                          isSelected: _selected == option,
                          onTap: () => setState(() => _selected = option),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── Boutons bas ──
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 36),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selected != null ? _onContinue : null,
                      style: ElevatedButton.styleFrom(
                        disabledBackgroundColor: AppColors.bgCardSurface,
                        disabledForegroundColor: AppColors.textMuted,
                      ),
                      child: const Text(AppStrings.continueCta),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => context.go('/dashboard'),
                      child: Text(
                        AppStrings.intentionClose,
                        style: AppTextStyles.body,
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

// ── Option d'intention (carte sélectionnable) ────────────────────────────────

class _IntentionOption extends StatelessWidget {
  final IntentionOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _IntentionOption({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.bgCardSurface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: isSelected
              ? Border.all(color: AppColors.textPrimary, width: 1.5)
              : Border.all(color: Colors.transparent, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                option.label,
                style: AppTextStyles.body.copyWith(
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check, color: AppColors.textPrimary, size: 18),
          ],
        ),
      ),
    );
  }
}
