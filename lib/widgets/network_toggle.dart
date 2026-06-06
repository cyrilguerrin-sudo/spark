import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/social_network.dart';

class NetworkToggle extends StatelessWidget {
  final SocialNetwork network;
  final ValueChanged<bool> onToggle;

  const NetworkToggle({
    super.key,
    required this.network,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.bgCardSurface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(network.name, style: AppTextStyles.networkName),
          GestureDetector(
            onTap: () => onToggle(!network.isEnabled),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52,
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: network.isEnabled ? AppColors.orange : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
