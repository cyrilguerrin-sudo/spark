import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/session.dart';

class SessionCard extends StatelessWidget {
  final Session session;

  const SessionCard({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCardSurface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${session.formattedStartTime} · ${session.networkName}',
            style: AppTextStyles.body,
          ),
          Text(
            session.formattedDelta,
            style: AppTextStyles.body.copyWith(
              color: session.isRespected ? AppColors.green : AppColors.red,
            ),
          ),
        ],
      ),
    );
  }
}
