import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/constants.dart';
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
  bool _isRequestingAuth  = false;
  List<String> _configuredNetworks = [];
  final Map<String, bool> _isPickingNetwork = {
    AppNetworks.instagram: false,
    AppNetworks.tiktok:    false,
    AppNetworks.youtube:   false,
  };

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

  Future<void> _checkIosPermissions() async {
    final auth = await FamilyControlsService.checkAuthorization();
    if (!mounted) return;
    if (!auth && StorageService.familyControlsAuthorized) {
      await StorageService.setFamilyControlsAuthorized(false);
    }
    final networks = auth
        ? await FamilyControlsService.getConfiguredNetworks()
        : <String>[];
    if (!mounted) return;
    setState(() {
      _hasFamilyControls   = auth;
      _configuredNetworks  = networks;
    });
    if (auth && networks.isNotEmpty && StorageService.familyControlsAuthorized) {
      _navigateToDashboard();
    }
  }

  // Step A: request FamilyControls auth only (no picker).
  Future<void> _requestFamilyControlsAuth() async {
    if (_isRequestingAuth) return;
    setState(() => _isRequestingAuth = true);
    final authorized = await FamilyControlsService.requestAuthorization();
    if (!mounted) return;
    if (authorized) {
      final networks = await FamilyControlsService.getConfiguredNetworks();
      if (!mounted) return;
      setState(() {
        _hasFamilyControls  = true;
        _configuredNetworks = networks;
        _isRequestingAuth   = false;
      });
    } else {
      setState(() => _isRequestingAuth = false);
    }
  }

  // Step B: present picker for a single network.
  Future<void> _pickNetwork(String network) async {
    if (_isPickingNetwork[network] == true) return;
    setState(() => _isPickingNetwork[network] = true);
    debugPrint('[Spark] _pickNetwork($network) → setMonitoredNetwork start');
    await FamilyControlsService.setMonitoredNetwork(network);
    debugPrint('[Spark] _pickNetwork($network) → setMonitoredNetwork done');
    if (!mounted) return;
    final networks = await FamilyControlsService.getConfiguredNetworks();
    debugPrint('[Spark] _pickNetwork($network) → getConfiguredNetworks = $networks');
    if (!mounted) return;
    setState(() {
      _configuredNetworks        = networks;
      _isPickingNetwork[network] = false;
    });
    debugPrint('[Spark] _pickNetwork($network) → setState done, configured=$_configuredNetworks');
  }

  Future<void> _onContinueIos() async {
    await StorageService.setFamilyControlsAuthorized(true);
    if (!mounted) return;
    _navigateToDashboard();
  }

  void _navigateToDashboard() {
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

  Widget _networkRow(String networkId) {
    final isConfigured = _configuredNetworks.contains(networkId);
    final isPicking    = _isPickingNetwork[networkId] == true;
    final name         = AppNetworks.names[networkId] ?? networkId;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.bgCardSurface,
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(color: AppColors.bgCardBorder, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isConfigured ? 'Configuré ✓' : 'Non configuré',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: isConfigured
                        ? AppColors.green
                        : AppColors.textMuted,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          if (isPicking)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  color: AppColors.orange, strokeWidth: 2),
            )
          else
            GestureDetector(
              onTap: () => _pickNetwork(networkId),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isConfigured
                      ? AppColors.bgCardBorder
                      : AppColors.orange,
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
                child: Text(
                  isConfigured ? 'Modifier' : 'Sélectionner',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isConfigured
                        ? AppColors.textSecondary
                        : Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIosScreen(BuildContext context) {
    final canContinue =
        _hasFamilyControls && _configuredNetworks.isNotEmpty && !_isRequestingAuth;

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

                    // ── Step A: FamilyControls auth ──────────────────────────
                    PermissionCard(
                      icon: Icons.phonelink_lock_rounded,
                      title: 'Screen Time',
                      description:
                          'Permet à Spark de surveiller l\'ouverture des réseaux sociaux '
                          'et de bloquer l\'accès quand ta session se termine.',
                      isGranted: _hasFamilyControls,
                      onActivate: _isRequestingAuth
                          ? () {}
                          : _requestFamilyControlsAuth,
                    ),

                    if (_isRequestingAuth) ...[
                      const SizedBox(height: 16),
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

                    // ── Step B: per-network pickers (shown after auth) ────────
                    if (_hasFamilyControls) ...[
                      const SizedBox(height: 32),
                      const Text(
                        'Réseaux à surveiller',
                        style: AppTextStyles.sectionLabel,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Sélectionne chaque app pour l\'associer à Spark.',
                        style: AppTextStyles.body,
                      ),
                      const SizedBox(height: 16),
                      _networkRow(AppNetworks.instagram),
                      _networkRow(AppNetworks.tiktok),
                      _networkRow(AppNetworks.youtube),
                    ],

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
                  onPressed: canContinue ? _onContinueIos : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canContinue
                        ? AppColors.textPrimary
                        : AppColors.bgCardSurface,
                    foregroundColor:
                        canContinue ? Colors.black : AppColors.textMuted,
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
