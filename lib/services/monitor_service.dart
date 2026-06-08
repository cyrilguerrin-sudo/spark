import 'package:flutter/services.dart';
import '../core/constants.dart';

class MonitorService {
  static const _channel = MethodChannel('com.example.spark/permissions');

  static Future<void> start() async {
    try {
      await _channel.invokeMethod('startMonitorService');
    } catch (_) {}
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopMonitorService');
    } catch (_) {}
  }

  static Future<void> bringToFront() async {
    try {
      await _channel.invokeMethod('bringToFront');
    } catch (_) {}
  }

  /// Écrit le timestamp de fin de session directement dans SharedPreferences.
  /// Appelé une seule fois au démarrage de la session — le service natif lit
  /// cette valeur toutes les secondes et verrouille l'écran quand elle expire.
  static Future<void> setSessionEndTime(int endTimeMs, String networkId) async {
    try {
      await _channel.invokeMethod('setSessionEndTime', {
        'endTimeMs': endTimeMs,
        'networkId': networkId,
      });
    } catch (_) {}
  }

  /// Efface le timestamp de fin de session (annulation ou reset manuel).
  static Future<void> clearSessionEndTime() async {
    try {
      await _channel.invokeMethod('clearSessionEndTime');
    } catch (_) {}
  }

  /// Écrit le timestamp de fin de blocage d'un package dans SharedPreferences.
  /// Appelé par le bouton "Bloquer Insta 5min" — le service natif bloque toute
  /// tentative d'ouverture du package jusqu'à ce timestamp.
  static Future<void> setBlockUntil({
    required String packageName,
    required int blockUntilMs,
  }) async {
    try {
      await _channel.invokeMethod('setBlockUntil', {
        'packageName': packageName,
        'blockUntilMs': blockUntilMs,
      });
    } catch (_) {}
  }

  /// Synchronise la config de surveillance (apps monitorées, session active, focus).
  /// Ne touche plus au timestamp de fin de session — géré par setSessionEndTime.
  static Future<void> updateConfig({
    required List<String> monitoredNetworkIds,
    String? activeSessionNetworkId,
    required bool focusActive,
    required List<String> focusNetworkIds,
  }) async {
    String? toPkg(String id) => AppNetworks.androidPackages[id];

    final monitoredPkgs = monitoredNetworkIds.map(toPkg).whereType<String>().toList();
    final activePkgs = activeSessionNetworkId != null
        ? [toPkg(activeSessionNetworkId)].whereType<String>().toList()
        : <String>[];
    final focusPkgs = focusNetworkIds.map(toPkg).whereType<String>().toList();

    try {
      await _channel.invokeMethod('updateMonitorConfig', {
        'monitoredPackages': monitoredPkgs,
        'activeSessionPackages': activePkgs,
        'focusActive': focusActive,
        'focusPackages': focusPkgs,
      });
    } catch (_) {}
  }
}
