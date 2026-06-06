import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../services/storage_service.dart';

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

  void _onProceed() {
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

  String get _proceedLabel =>
      _selected?.closesApp == true ? 'Ok, je referme' : 'Entrer quand même';

  @override
  Widget build(BuildContext context) {
    final firstName = StorageService.firstName;
    final greeting = firstName.isEmpty ? 'Salut !' : 'Salut $firstName !';

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 48, 22, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(greeting, style: AppTextStyles.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    '${AppStrings.intentionSubtitlePrefix}$_networkName'
                    '${AppStrings.intentionSubtitleSuffix}',
                    style: AppTextStyles.body,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Options d'intention ──
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                itemCount: _options.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final option = _options[i];
                  return _IntentionOption(
                    option: option,
                    isSelected: _selected == option,
                    onTap: () => setState(() => _selected = option),
                  );
                },
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
                      onPressed: _selected != null ? _onProceed : null,
                      style: ElevatedButton.styleFrom(
                        disabledBackgroundColor: AppColors.bgCardSurface,
                        disabledForegroundColor: AppColors.textMuted,
                      ),
                      child: Text(_proceedLabel),
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
