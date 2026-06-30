import 'package:flutter/material.dart';
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 52),
              const Text(
                'Quelle app voulais-tu ouvrir ?',
                style: AppTextStyles.titleLarge,
              ),
              const SizedBox(height: 32),
              for (final networkId in _networks!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.go(
                        '/intention',
                        extra: {'networkId': networkId},
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.bgCardSurface,
                        foregroundColor: AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.button),
                          side: const BorderSide(
                              color: AppColors.bgCardBorder, width: 1),
                        ),
                      ),
                      child: Text(
                        AppNetworks.names[networkId] ?? networkId,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
