import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/family_controls_service.dart';

/// Whether the device supports the native Liquid Glass material (iOS 26+).
/// Checked once and cached for the app's lifetime.
final liquidGlassSupportProvider = FutureProvider<bool>((ref) {
  return FamilyControlsService.supportsLiquidGlass();
});
