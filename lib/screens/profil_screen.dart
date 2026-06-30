import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../services/family_controls_service.dart';
import '../services/storage_service.dart';
import '../widgets/bottom_nav.dart';

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  late final TextEditingController _pseudoController;

  bool _hasFamilyControls = false;
  bool _isActivating      = false;
  List<String> _configuredNetworks = [];
  final Map<String, bool> _isPickingNetwork = {
    AppNetworks.instagram: false,
    AppNetworks.tiktok:    false,
    AppNetworks.youtube:   false,
  };

  @override
  void initState() {
    super.initState();
    _pseudoController = TextEditingController(text: StorageService.pseudo);
    if (Platform.isIOS) {
      _hasFamilyControls = StorageService.familyControlsAuthorized;
      _checkFamilyControlsState();
      _loadConfiguredNetworks();
    }
  }

  @override
  void dispose() {
    _pseudoController.dispose();
    super.dispose();
  }

  Future<void> _savePseudo() async {
    await StorageService.savePseudo(_pseudoController.text.trim());
  }

  Future<void> _checkFamilyControlsState() async {
    final auth = await FamilyControlsService.checkAuthorization();
    if (!mounted) return;
    if (auth != _hasFamilyControls) {
      await StorageService.setFamilyControlsAuthorized(auth);
      setState(() => _hasFamilyControls = auth);
    }
  }

  Future<void> _loadConfiguredNetworks() async {
    final networks = await FamilyControlsService.getConfiguredNetworks();
    if (!mounted) return;
    setState(() => _configuredNetworks = networks);
  }

  Future<void> _activateFamilyControls() async {
    setState(() => _isActivating = true);
    final authorized = await FamilyControlsService.requestAuthorization();
    if (!mounted) return;
    await StorageService.setFamilyControlsAuthorized(authorized);
    setState(() {
      _hasFamilyControls = authorized;
      _isActivating      = false;
    });
  }

  Future<void> _pickNetwork(String network) async {
    if (_isPickingNetwork[network] == true) return;
    setState(() => _isPickingNetwork[network] = true);
    await FamilyControlsService.setMonitoredNetwork(network);
    if (!mounted) return;
    final networks = await FamilyControlsService.getConfiguredNetworks();
    if (!mounted) return;
    setState(() {
      _configuredNetworks        = networks;
      _isPickingNetwork[network] = false;
    });
  }

  Future<void> _openWhatsApp() async {
    final uri = Uri.parse('https://chat.whatsapp.com/C82xK0M64No4UowvOyCe0c');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static const TextStyle _sectionLabel = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w700,
    fontSize: 15,
    color: AppColors.textPrimary,
    letterSpacing: -0.4,
  );

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bgCardSurface,
          borderRadius: BorderRadius.circular(AppRadius.button),
          border: Border.all(color: AppColors.bgCardBorder, width: 1),
        ),
        child: child,
      );

  Widget _networkRow(String networkId) {
    final isConfigured = _configuredNetworks.contains(networkId);
    final isPicking    = _isPickingNetwork[networkId] == true;
    final name         = AppNetworks.names[networkId] ?? networkId;

    return _card(
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
                    color: isConfigured ? AppColors.green : AppColors.textMuted,
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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

                  // ── Pseudo ────────────────────────────────────────────────
                  const Text('Pseudo', style: _sectionLabel),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _pseudoController,
                    textInputAction: TextInputAction.done,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Ton pseudo',
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                    onEditingComplete: () {
                      FocusScope.of(context).unfocus();
                      _savePseudo();
                    },
                    onTapOutside: (_) => _savePseudo(),
                  ),

                  const SizedBox(height: 32),

                  // ── Autorisations (iOS only) ───────────────────────────────
                  if (Platform.isIOS) ...[
                    const Text('Autorisations', style: _sectionLabel),
                    const SizedBox(height: 12),

                    _card(
                      child: Row(
                        children: [
                          const Icon(Icons.phonelink_lock_rounded,
                              color: AppColors.textSecondary, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Screen Time',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _hasFamilyControls ? 'Autorisé' : 'Non autorisé',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    color: _hasFamilyControls
                                        ? AppColors.green
                                        : AppColors.red,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_isActivating)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: AppColors.orange, strokeWidth: 2),
                            )
                          else if (!_hasFamilyControls)
                            GestureDetector(
                              onTap: _activateFamilyControls,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.orange,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.button),
                                ),
                                child: const Text(
                                  'Activer',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Colors.white,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        // Uses native Swift UIApplication.shared.open — bypasses
                        // url_launcher which silently fails for App-Prefs scheme.
                        onPressed: FamilyControlsService.openScreenTimeSettings,
                        icon: const Icon(Icons.settings_outlined, size: 16),
                        label: const Text('Gérer dans Réglages'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(
                              color: AppColors.bgCardBorder, width: 1),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            letterSpacing: -0.3,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.button),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Réseaux surveillés ────────────────────────────────
                    const Text('Réseaux surveillés', style: _sectionLabel),
                    const SizedBox(height: 12),

                    for (final networkId in [
                      AppNetworks.instagram,
                      AppNetworks.tiktok,
                      AppNetworks.youtube,
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _networkRow(networkId),
                      ),

                    const SizedBox(height: 22),
                  ],

                  // ── Communauté ────────────────────────────────────────────
                  const Text('Communauté', style: _sectionLabel),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openWhatsApp,
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text('Rejoindre le groupe WhatsApp'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          letterSpacing: -0.3,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.button),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),

            SparkBottomNav(
              currentIndex: 1,
              onTap: (i) {
                if (i == 0) context.go('/dashboard');
              },
            ),
          ],
        ),
      ),
    );
  }
}
