import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/liquid_glass_support_provider.dart';
import 'liquid_glass_bottom_nav.dart';

/// Dispatches to the native Liquid Glass nav bar on iOS 26+, falling back to
/// [_LegacyBottomNav] everywhere else (older iOS, Android, or while the
/// support check is still resolving).
class SparkBottomNav extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const SparkBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supportsGlass = ref.watch(liquidGlassSupportProvider);
    if (supportsGlass.value == true) {
      return LiquidGlassBottomNav(currentIndex: currentIndex, onTap: onTap);
    }
    return _LegacyBottomNav(currentIndex: currentIndex, onTap: onTap);
  }
}

class _LegacyBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _LegacyBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.bottomNavBg,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            _NavItem(
              icon: Icons.home_rounded,
              active: currentIndex == 0,
              onTap: () => onTap(0),
            ),
            _NavItem(
              icon: Icons.person,
              active: currentIndex == 1,
              onTap: () => onTap(1),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: active ? _ActiveIndicator(icon: icon) : _InactiveIcon(icon: icon),
        ),
      ),
    );
  }
}

class _ActiveIndicator extends StatelessWidget {
  final IconData icon;

  const _ActiveIndicator({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF7043), AppColors.orange],
        ),
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }
}

class _InactiveIcon extends StatelessWidget {
  final IconData icon;

  const _InactiveIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Icon(icon, color: AppColors.textMuted, size: 22);
  }
}
