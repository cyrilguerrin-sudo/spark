import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../services/storage_service.dart';
import '../widgets/bottom_nav.dart';

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  late final TextEditingController _pseudoController;

  static const _frMonths = [
    '',
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];

  @override
  void initState() {
    super.initState();
    _pseudoController = TextEditingController(text: StorageService.pseudo);
  }

  @override
  void dispose() {
    _pseudoController.dispose();
    super.dispose();
  }

  Future<void> _savePseudo() async {
    await StorageService.savePseudo(_pseudoController.text.trim());
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

  Future<void> _openWhatsApp() async {
    final uri = Uri.parse('https://chat.whatsapp.com/C82xK0M64No4UowvOyCe0c');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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

                  // ── Pseudo ──
                  const Text(
                    'Pseudo',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
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
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    onEditingComplete: () {
                      FocusScope.of(context).unfocus();
                      _savePseudo();
                    },
                    onTapOutside: (_) => _savePseudo(),
                  ),

                  const SizedBox(height: 48),

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

                  // ── Communauté WhatsApp ──
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openWhatsApp,
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text('Rejoindre la communauté WhatsApp'),
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
