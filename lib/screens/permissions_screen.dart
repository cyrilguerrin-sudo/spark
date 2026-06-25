import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../services/family_controls_service.dart';
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

  // ── Android state ──────────────────────────────────────────────────────────
  bool _hasUsageStats   = false;
  bool _hasOverlay      = false;
  bool _hasDeviceAdmin  = false;
  bool _hasAccessibility = false;

  // ── iOS state ──────────────────────────────────────────────────────────────
  bool _hasFamilyControls = false;
  // True while requestAuthorization + setMonitoredNetworks are in flight.
  bool _isRequesting = false;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (Platform.isIOS) {
      _checkIosPermissions();
    } else {
      _checkPermissions();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (Platform.isIOS) {
        _checkIosPermissions();
      } else {
        _checkPermissions();
      }
    }
  }

  // ── Android logic (unchanged) ──────────────────────────────────────────────

  Future<void> _checkPermissions() async {
    final result = await PermissionService.checkAll();
    if (!mounted) return;
    setState(() {
      _hasUsageStats    = result.usageStats;
      _hasOverlay       = result.overlay;
      _hasDeviceAdmin   = result.deviceAdmin;
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

  // ── iOS logic ──────────────────────────────────────────────────────────────

  /// Checks FamilyControls status and auto-navigates if already authorized.
  Future<void> _checkIosPermissions() async {
    final auth = await FamilyControlsService.checkAuthorization();
    if (!mounted) return;
    setState(() => _hasFamilyControls = auth);
    if (auth) _continueFromIos();
  }

  /// Full authorization flow:
  ///   1. System FamilyControls dialog (requestAuthorization)
  ///   2. FamilyActivityPicker to select apps (setMonitoredNetworks)
  ///   3. Navigate to /dashboard
  Future<void> _requestFamilyControls() async {
    if (_isRequesting) return;
    setState(() => _isRequesting = true);

    final authorized = await FamilyControlsService.requestAuthorization();
    if (!mounted) return;

    if (authorized) {
      setState(() => _hasFamilyControls = true);
      // Present FamilyActivityPicker; awaits until user taps OK and picker dismisses.
      await FamilyControlsService.setMonitoredNetworks();
      if (!mounted) return;
      _continueFromIos();
      return;
    }

    // Auth denied — reset loading state, card stays in "Activer" mode.
    setState(() => _isRequesting = false);
  }

  void _continueFromIos() {
    context.go('/dashboard');
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return _buildIosScreen(context);
    }

    // ── Android screen (identical to original) ──────────────────────────────
    final allGranted =
        _hasUsageStats && _hasOverlay && _hasDeviceAdmin && _hasAccessibility;

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

            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: allGranted ? _continue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: allGranted
                        ? AppColors.textPrimary
                        : AppColors.bgCardSurface,
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

  // ── iOS screen ─────────────────────────────────────────────────────────────

  Widget _buildIosScreen(BuildContext context) {
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

                    const Text(
                      'Une autorisation requise',
                      style: AppTextStyles.sectionLabel,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tes données sont complètement privées et ne quittent jamais ton téléphone.',
                      style: AppTextStyles.body,
                    ),
                    const SizedBox(height: 32),

                    PermissionCard(
                      icon: Icons.phonelink_lock_rounded,
                      title: 'Screen Time',
                      description:
                          'Permet à Spark de surveiller l\'ouverture des réseaux sociaux '
                          'et de bloquer l\'accès quand ta session se termine. '
                          'Tu choisiras ensuite quelles apps surveiller.',
                      isGranted: _hasFamilyControls,
                      onActivate: _isRequesting ? () {} : _requestFamilyControls,
                    ),

                    if (_isRequesting) ...[
                      const SizedBox(height: 20),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: AppColors.orange,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Autorisation en cours…',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // "Continuer" — enabled once FamilyControls is authorized.
            // The user can reach this state either after the full flow above,
            // or on a subsequent launch if already authorized.
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      (_hasFamilyControls && !_isRequesting) ? _continueFromIos : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasFamilyControls
                        ? AppColors.textPrimary
                        : AppColors.bgCardSurface,
                    foregroundColor:
                        _hasFamilyControls ? Colors.black : AppColors.textMuted,
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
