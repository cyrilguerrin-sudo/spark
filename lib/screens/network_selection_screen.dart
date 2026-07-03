import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../services/family_controls_service.dart';

class NetworkSelectionScreen extends StatefulWidget {
  const NetworkSelectionScreen({super.key});

  @override
  State<NetworkSelectionScreen> createState() => _NetworkSelectionScreenState();
}

class _NetworkSelectionScreenState extends State<NetworkSelectionScreen> {
  List<String>? _networks;
  String? _selected;

  @override
  void initState() {
    super.initState();
    _loadNetworks();
  }

  Future<void> _loadNetworks() async {
    final networks = await FamilyControlsService.getConfiguredNetworks();
    if (!mounted) return;
    if (networks.isEmpty) {
      context.go('/dashboard');
      return;
    }
    setState(() => _networks = networks);
  }

  void _onContinue() {
    HapticFeedback.mediumImpact();
    context.go('/intention', extra: {'networkId': _selected});
  }

  @override
  Widget build(BuildContext context) {
    if (_networks == null) {
      return const Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.orange),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 48, 22, 0),
              child: Text(
                'Quelle app voulais-tu ouvrir ?',
                style: AppTextStyles.titleLarge,
              ),
            ),

            // ── Options centrées, comme le slider du timer ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final networkId in _networks!)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _NetworkOption(
                          label: AppNetworks.names[networkId] ?? networkId,
                          isSelected: _selected == networkId,
                          onTap: () => setState(() => _selected = networkId),
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

// ── Option réseau (carte sélectionnable) ─────────────────────────────────────

class _NetworkOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NetworkOption({
    required this.label,
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
                label,
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
