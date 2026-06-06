import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/router.dart';
import '../services/storage_service.dart';
import '../services/permission_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  /// Retourne true si le splash screen est encore la route au sommet de la pile.
  /// Si une interception a pushé /intention entre-temps, on annule la navigation.
  bool _isStillActive() {
    try {
      final topPath = appRouter
          .routerDelegate
          .currentConfiguration
          .uri
          .path;
      return topPath == '/';
    } catch (_) {
      return false;
    }
  }

  Future<void> _init() async {
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    // Une interception a pushé une route par-dessus le splash → ne pas écraser
    if (!_isStillActive()) return;

    final perms = await PermissionService.checkAll();
    if (!mounted) return;

    // Vérifier à nouveau après le gap async
    if (!_isStillActive()) return;

    if (!perms.usageStats || !perms.overlay) {
      context.go('/permissions');
    } else if (StorageService.isFirstLaunch) {
      context.go('/onboarding');
    } else {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Center(
        child: _SparkLogo(),
      ),
    );
  }
}

class _SparkLogo extends StatelessWidget {
  const _SparkLogo();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/spark_logo.png',
      width: 220,
      fit: BoxFit.contain,
    );
  }
}
