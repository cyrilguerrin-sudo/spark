import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../models/social_network.dart';
import '../providers/networks_provider.dart';
import '../widgets/bottom_nav.dart';

class EditScreen extends ConsumerWidget {
  const EditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final networks = ref.watch(networksProvider);
    final notifier = ref.read(networksProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ── Titre ──
                    const Padding(
                      padding: EdgeInsets.fromLTRB(22, 36, 22, 0),
                      child: Text(
                        AppStrings.editTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Liste des réseaux ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Column(
                        children: networks
                            .map(
                              (n) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _NetworkItem(
                                  network: n,
                                  onToggle: () =>
                                      notifier.toggleNetwork(n.id),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── Bottom nav ──
            SparkBottomNav(
              currentIndex: 1,
              onTap: (i) {
                if (i == 0) context.go('/dashboard');
                if (i == 2) context.go('/profil');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkItem extends StatelessWidget {
  final SocialNetwork network;
  final VoidCallback onToggle;

  const _NetworkItem({required this.network, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgCardSurface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(network.name, style: AppTextStyles.networkName),
          CupertinoSwitch(
            value: network.isEnabled,
            onChanged: (_) => onToggle(),
            activeTrackColor: AppColors.orange,
          ),
        ],
      ),
    );
  }
}
