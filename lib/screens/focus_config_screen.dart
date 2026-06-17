import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../providers/networks_provider.dart';
import '../providers/focus_provider.dart';

class FocusConfigScreen extends ConsumerStatefulWidget {
  const FocusConfigScreen({super.key});

  @override
  ConsumerState<FocusConfigScreen> createState() => _FocusConfigScreenState();
}

class _FocusConfigScreenState extends ConsumerState<FocusConfigScreen> {
  late final TextEditingController _objectiveController;
  late List<String> _selectedApps;

  @override
  void initState() {
    super.initState();
    _objectiveController = TextEditingController();
    // Pré-cocher tous les réseaux activés dans l'onglet Edit
    _selectedApps = ref
        .read(networksProvider)
        .where((n) => n.isEnabled)
        .map((n) => n.id)
        .toList();
  }

  @override
  void dispose() {
    _objectiveController.dispose();
    super.dispose();
  }

  void _toggleApp(String networkId) {
    setState(() {
      if (_selectedApps.contains(networkId)) {
        _selectedApps.remove(networkId);
      } else {
        _selectedApps.add(networkId);
      }
    });
  }

  void _launchSession() {
    final objective = _objectiveController.text.trim();
    ref.read(focusProvider.notifier).startSession(
          objective: objective.isEmpty ? 'Session Focus' : objective,
          blockedApps: List.from(_selectedApps),
        );
    context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final enabledNetworks =
        ref.watch(networksProvider).where((n) => n.isEnabled).toList();

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
                onPressed: () => context.pop(),
              ),
            ),

            // ── Contenu scrollable ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Flamme + lueur (petite)
                    const _SmallFlame(),
                    const SizedBox(height: 24),

                    // Question
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

                    // Champ objectif
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

                    // Label "Apps bloquées :"
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

                    // Chips des apps
                    if (enabledNetworks.isEmpty)
                      Text(
                        'Active des réseaux dans l\'onglet Edit',
                        style: AppTextStyles.body
                            .copyWith(color: AppColors.textMuted),
                        textAlign: TextAlign.center,
                      )
                    else
                      Column(
                        children: enabledNetworks
                            .map(
                              (n) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _AppChip(
                                  name: n.name,
                                  selected: _selectedApps.contains(n.id),
                                  onTap: () => _toggleApp(n.id),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    const SizedBox(height: 20),

                    // Note
                    Text(
                      AppStrings.focusConfigNote,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Bouton lancer
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

// ── Chip d'application bloquée ───────────────────────────────────────────────

class _AppChip extends StatelessWidget {
  final String name;
  final bool selected;
  final VoidCallback onTap;

  const _AppChip({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.bgCardSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.button),
          border: Border.all(
            color: selected
                ? AppColors.bgCardBorder
                : AppColors.textMuted.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            name,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: selected ? AppColors.textPrimary : AppColors.textMuted,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ),
    );
  }
}
