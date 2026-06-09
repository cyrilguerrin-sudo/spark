import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../services/permission_service.dart';
import '../services/storage_service.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/permission_card.dart';

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _nomController;
  late final TextEditingController _prenomController;
  late final TextEditingController _emailController;

  bool _hasUsageStats = false;
  bool _hasOverlay = false;
  bool _hasDeviceAdmin = false;
  bool _hasAccessibility = false;

  static const _frMonths = [
    '',
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];

  @override
  void initState() {
    super.initState();
    _nomController = TextEditingController(text: StorageService.lastName);
    _prenomController = TextEditingController(text: StorageService.firstName);
    _emailController = TextEditingController(text: StorageService.email);
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _emailController.dispose();
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

  Future<void> _save() async {
    await StorageService.saveProfile(
      firstName: _prenomController.text.trim(),
      lastName: _nomController.text.trim(),
      email: _emailController.text.trim(),
    );
  }

  String _formatMemberSince() {
    final raw = StorageService.memberSince;
    if (raw.isEmpty) return '';
    try {
      final date = DateTime.parse(raw);
      return '${date.day} ${_frMonths[date.month]} ${date.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final memberSince = _formatMemberSince();

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                children: [
                  const SizedBox(height: 32),

                  // ── Profil ──
                  _FieldSection(
                    label: 'Nom',
                    controller: _nomController,
                    onDone: _save,
                  ),
                  const SizedBox(height: 16),

                  _FieldSection(
                    label: 'Prénom',
                    controller: _prenomController,
                    onDone: _save,
                  ),
                  const SizedBox(height: 16),

                  _FieldSection(
                    label: 'Email',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    onDone: _save,
                  ),
                  const SizedBox(height: 16),

                  const _FieldSection(
                    label: 'Mot de passe',
                    isPassword: true,
                  ),
                  const SizedBox(height: 8),

                  GestureDetector(
                    onTap: () {},
                    child: const Text(
                      'Mot de passe oublié ?',
                      style: AppTextStyles.caption,
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── Autorisations ──
                  const Text(
                    'Autorisations',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      letterSpacing: -0.9,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  PermissionCard(
                    icon: Icons.bar_chart_rounded,
                    title: 'Accès à l\'utilisation',
                    description:
                        'Permet à Spark de détecter quand tu ouvres une app surveillée.',
                    isGranted: _hasUsageStats,
                    onActivate: PermissionService.openUsageStatsSettings,
                  ),
                  const SizedBox(height: 10),

                  PermissionCard(
                    icon: Icons.layers_rounded,
                    title: 'Affichage par-dessus les apps',
                    description:
                        'Permet à Spark d\'afficher ses écrans par-dessus Instagram et les autres apps.',
                    isGranted: _hasOverlay,
                    onActivate: PermissionService.openOverlaySettings,
                  ),
                  const SizedBox(height: 10),

                  PermissionCard(
                    icon: Icons.lock_rounded,
                    title: 'Administrateur de l\'appareil',
                    description:
                        'Spark verrouille l\'écran quand ta session se termine.',
                    isGranted: _hasDeviceAdmin,
                    onActivate: PermissionService.openDeviceAdminSettings,
                  ),
                  const SizedBox(height: 10),

                  PermissionCard(
                    icon: Icons.accessibility_new_rounded,
                    title: 'Service d\'accessibilité',
                    description:
                        'Détection instantanée de l\'ouverture des apps, comme OneSec. Aucune donnée transmise hors de l\'appareil.',
                    isGranted: _hasAccessibility,
                    onActivate: PermissionService.openAccessibilitySettings,
                  ),

                  const SizedBox(height: 36),

                  // ── Membre depuis ──
                  if (memberSince.isNotEmpty)
                    Center(
                      child: Text.rich(
                        TextSpan(
                          text: AppStrings.profilMemberSincePrefix,
                          style: AppTextStyles.body,
                          children: [
                            TextSpan(
                              text: memberSince,
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  const SizedBox(height: 32),
                ],
              ),
            ),

            SparkBottomNav(
              currentIndex: 2,
              onTap: (i) {
                if (i == 0) context.go('/dashboard');
                if (i == 1) context.go('/edit');
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Champ formulaire ────────────────────────────────────────────────────────

class _FieldSection extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final bool isPassword;
  final TextInputType keyboardType;
  final VoidCallback? onDone;

  const _FieldSection({
    required this.label,
    this.controller,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: AppColors.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword,
          keyboardType: keyboardType,
          textInputAction:
              isPassword ? TextInputAction.done : TextInputAction.next,
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            hintText: isPassword ? '••••••••' : null,
          ),
          onEditingComplete: () {
            FocusScope.of(context).nextFocus();
            onDone?.call();
          },
          readOnly: isPassword,
        ),
      ],
    );
  }
}
