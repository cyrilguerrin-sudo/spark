import 'package:flutter/material.dart';
import '../core/theme.dart';

class HoldButton extends StatefulWidget {
  final String label;
  final VoidCallback onComplete;
  final Duration duration;
  final VoidCallback? onHoldStart;

  const HoldButton({
    super.key,
    required this.label,
    required this.onComplete,
    this.duration = const Duration(seconds: 2),
    this.onHoldStart,
  });

  @override
  State<HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<HoldButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _pressing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    setState(() => _pressing = true);
    widget.onHoldStart?.call();
    _ctrl.forward();
  }

  void _onRelease() {
    setState(() => _pressing = false);
    _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: (_) => _onRelease(),
      onTapCancel: _onRelease,
      child: LayoutBuilder(
        builder: (_, constraints) => AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.bgCardSurface,
              borderRadius: BorderRadius.circular(AppRadius.button),
              border: Border.all(color: AppColors.bgCardBorder, width: 1),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 0,
                  width: constraints.maxWidth * _ctrl.value,
                  child: Container(
                    color: AppColors.orange.withValues(alpha: 0.25),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  child: Center(
                    child: Text(
                      _pressing ? 'Maintenir...' : widget.label,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
