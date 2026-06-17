import 'package:flutter/material.dart';
import '../core/theme.dart';

class FlameButton extends StatelessWidget {
  final VoidCallback? onTap;

  const FlameButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            'assets/images/flame_glow.png',
            height: 104,
            fit: BoxFit.contain,
          ),
          const SizedBox(
            width: 120,
            height: 120,
            child: Icon(
              Icons.local_fire_department,
              color: AppColors.orange,
              size: 80,
            ),
          ),
        ],
      ),
    );
  }
}
