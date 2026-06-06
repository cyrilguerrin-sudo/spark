import 'package:flutter/material.dart';
import '../core/theme.dart';

class TimeSlider extends StatelessWidget {
  final int value;
  final int maxMinutes;
  final ValueChanged<int> onChanged;

  const TimeSlider({
    super.key,
    required this.value,
    required this.maxMinutes,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.orange,
              inactiveTrackColor: AppColors.bgCardSurface,
              thumbColor: AppColors.textPrimary,
              overlayColor: AppColors.orange.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: value.toDouble(),
              min: 0,
              max: maxMinutes.toDouble(),
              divisions: maxMinutes,
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value == 0 ? '—' : '$value min',
          style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
        ),
      ],
    );
  }
}
