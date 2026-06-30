import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/constants.dart';

class SessionStartedScreen extends StatelessWidget {
  final String networkId;
  final int durationMinutes;

  const SessionStartedScreen({
    super.key,
    required this.networkId,
    required this.durationMinutes,
  });

  String get _networkName => AppNetworks.names[networkId] ?? networkId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),

              // Icône
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.lock_open_rounded,
                  color: AppColors.orange,
                  size: 32,
                ),
              ),
              const SizedBox(height: 28),

              // Titre
              Text(
                'Tu peux ouvrir $_networkName',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 28,
                  letterSpacing: -1.2,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              // Sous-titre avec la durée
              Text(
                'Le Shield est levé pour $durationMinutes min. '
                'Il se réactivera automatiquement à la fin de ta session.',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  fontSize: 15,
                  height: 1.5,
                  letterSpacing: -0.3,
                  color: AppColors.textSecondary,
                ),
              ),

              const Spacer(),

              // Bouton principal
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/dashboard'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.textPrimary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                  ),
                  child: const Text(
                    'Compris',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}
