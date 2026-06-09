import 'package:flutter/services.dart';

class PermissionService {
  static const _channel = MethodChannel('com.example.spark/permissions');

  static Future<bool> hasUsageStats() async {
    try {
      return await _channel.invokeMethod<bool>('checkUsageStatsPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openUsageStatsSettings() async {
    await _channel.invokeMethod('openUsageStatsSettings');
  }

  static Future<bool> hasOverlayPermission() async {
    try {
      return await _channel.invokeMethod<bool>('checkOverlayPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openOverlaySettings() async {
    await _channel.invokeMethod('openOverlaySettings');
  }

  static Future<bool> hasDeviceAdmin() async {
    try {
      return await _channel.invokeMethod<bool>('checkDeviceAdminPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openDeviceAdminSettings() async {
    await _channel.invokeMethod('openDeviceAdminSettings');
  }

  static Future<bool> hasAccessibilityPermission() async {
    try {
      return await _channel.invokeMethod<bool>('checkAccessibilityPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openAccessibilitySettings() async {
    await _channel.invokeMethod('openAccessibilitySettings');
  }

  static Future<({bool usageStats, bool overlay, bool deviceAdmin, bool accessibility})> checkAll() async {
    final usage = await hasUsageStats();
    final overlay = await hasOverlayPermission();
    final admin = await hasDeviceAdmin();
    final accessibility = await hasAccessibilityPermission();
    return (usageStats: usage, overlay: overlay, deviceAdmin: admin, accessibility: accessibility);
  }
}
