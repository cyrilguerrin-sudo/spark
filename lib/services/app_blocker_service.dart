import 'package:flutter/services.dart';

class AppBlockerService {
  static const _channel = MethodChannel('com.example.spark/permissions');

  static Future<void> launchApp(String packageName) async {
    try {
      await _channel.invokeMethod('launchApp', {'packageName': packageName});
    } catch (_) {}
  }

  /// Lance l'app via un deep link en utilisant la logique native Android.
  /// Supporte les formats :
  ///   - https://  → ACTION_VIEW + setPackage (App Links)
  ///   - intent:// → Intent.parseUri (ex: story-camera Instagram)
  ///   - ""        → lancement par défaut
  static Future<void> launchWithDeepLink({
    required String deepLink,
    required String packageName,
  }) async {
    try {
      await _channel.invokeMethod('launchWithDeepLink', {
        'deepLink': deepLink,
        'packageName': packageName,
      });
    } catch (_) {}
  }
}
