import 'package:flutter/material.dart';
import '../core/theme.dart';

class SparkBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const SparkBottomNav({
    super.key,
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
