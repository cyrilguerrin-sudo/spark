import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../services/permission_service.dart';
import '../services/storage_service.dart';
import '../widgets/permission_card.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with WidgetsBindingObserver {
  bool _hasUsageStats = false;
  bool _hasOverlay = false;
  bool _hasDeviceAdmin = false;
  bool _hasAccessibility = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final result = await PermissionService.checkAll();
    if (!mounted) return;
    setState(() {
      _hasUsageStats = result.usageStats;
      _hasOverlay = result.overlay;
      _hasDeviceAdmin = result.deviceAdmin;
      _hasAccessibility = result.accessibility;
    });
  }

  void _continue() {
    if (StorageService.isFirstLaunch) {
      context.go('/onboarding');
    } else {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final allGranted = _hasUsageStats && _hasOverlay && _hasDeviceAdmin && _hasAccessibility;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 52),

                    Center(
                      child: Image.asset(
                        'assets/images/spark_logo.png',
                        height: 64,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 36),

                    const SizedBox(height: 32),

                    PermissionCard(
                      icon: Icons.bar_chart_rounded,
                      title: 'Accès à l\'utilisation',
                      description:
                          'Permet à Spark de détecter quand tu ouvres un réseau surveillé.',
                      isGranted: _hasUsageStats,
                      onActivate: PermissionService.openUsageStatsSettings,
                    ),
                    const SizedBox(height: 12),

                    PermissionCard(
                      icon: Icons.layers_rounded,
                      title: 'Affichage par-dessus les apps',
                      description:
                          'Permet à Spark d\'afficher ses écrans par-dessus Instagram et les autres apps.',
                      isGranted: _hasOverlay,
                      onActivate: PermissionService.openOverlaySettings,
                    ),
                    const SizedBox(height: 12),

                    PermissionCard(
                      icon: Icons.lock_rounded,
                      title: 'Administrateur de l\'appareil',
                      description:
                          'Spark verrouille l\'écran quand ta session se termine.',
                      isGranted: _hasDeviceAdmin,
                      onActivate: PermissionService.openDeviceAdminSettings,
                    ),
                    const SizedBox(height: 12),

                    PermissionCard(
                      icon: Icons.accessibility_new_rounded,
                      title: 'Service d\'accessibilité',
                      description:
                          'Permet à Spark de détecter quand tu ouvres un réseau surveillé.',
                      isGranted: _hasAccessibility,
                      onActivate: PermissionService.openAccessibilitySettings,
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // Bouton Continuer — épinglé en bas
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: allGranted ? _continue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        allGranted ? AppColors.textPrimary : AppColors.bgCardSurface,
                    foregroundColor:
                        allGranted ? Colors.black : AppColors.textMuted,
                    disabledBackgroundColor: AppColors.bgCardSurface,
                    disabledForegroundColor: AppColors.textMuted,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                  ),
                  child: const Text(
                    'Continuer',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: -0.4,
                    ),
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
