import 'package:flutter/material.dart';
import '../core/theme.dart';

class FlameButton extends StatelessWidget {
  final VoidCallback? onTap;

  const FlameButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.flameGlow,
              blurRadius: 20,
              spreadRadius: 10,
            ),
          ],
        ),
        child: const Icon(Icons.local_fire_department,
            color: AppColors.orange, size: 80),
      ),
    );
  }
}
