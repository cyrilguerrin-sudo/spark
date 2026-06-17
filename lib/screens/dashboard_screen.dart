import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../services/storage_service.dart';
import '../widgets/bottom_nav.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pseudo   = StorageService.pseudo;
    final greeting = pseudo.isEmpty ? 'Salut !' : 'Salut $pseudo !';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [Color(0xFF3D1A00), Color(0xFF0A0A0A)],
            radius: 0.85,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 48, 22, 0),
                child: Text(greeting, style: AppTextStyles.titleLarge),
              ),

              // ── Flamme (occupe l'espace restant) ──
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: () => context.go('/focus-config'),
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
                        const SizedBox(height: 20),
                        const Text(
                          'Appuie sur la flamme pour lancer le mode Focus',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            color: Color(0x80BBBBBB),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Bottom Nav ──
              SparkBottomNav(
                currentIndex: 0,
                onTap: (i) {
                  if (i == 1) context.go('/edit');
                  if (i == 2) context.go('/profil');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
