import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps the native SwiftUI `.glassEffect()` bottom nav (iOS 26+) as a
/// PlatformView. See ios/Runner/LiquidGlassNavBar.swift for the native side.
class LiquidGlassBottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const LiquidGlassBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<LiquidGlassBottomNav> createState() => _LiquidGlassBottomNavState();
}

class _LiquidGlassBottomNavState extends State<LiquidGlassBottomNav> {
  MethodChannel? _channel;

  void _onPlatformViewCreated(int id) {
    final channel = MethodChannel('spark/liquid_glass_nav_bar_$id');
    channel.setMethodCallHandler(_onMethodCall);
    _channel = channel;
  }

  Future<void> _onMethodCall(MethodCall call) async {
    if (call.method == 'onTap') {
      final index = call.arguments as int;
      widget.onTap(index);
    }
  }

  @override
  void didUpdateWidget(covariant LiquidGlassBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _channel?.invokeMethod('setCurrentIndex', widget.currentIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: SizedBox(
        height: 60,
        child: UiKitView(
          viewType: 'spark/liquid_glass_nav_bar',
          creationParams: {'currentIndex': widget.currentIndex},
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
        ),
      ),
    );
  }
}
