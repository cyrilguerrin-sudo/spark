import 'package:hive_flutter/hive_flutter.dart';

class StorageService {
  static const String _userBox = 'user';
  static const String _sessionsBox = 'sessions';
  static const String _networksBox = 'networks';
  static const String _focusBox = 'focus';

  static Future<void> init() async {
    await Future.wait([
      Hive.openBox(_userBox),
      Hive.openBox(_sessionsBox),
      Hive.openBox(_networksBox),
      Hive.openBox(_focusBox),
    ]);
  }

  static Box get user => Hive.box(_userBox);
  static Box get sessions => Hive.box(_sessionsBox);
  static Box get networks => Hive.box(_networksBox);
  static Box get focus => Hive.box(_focusBox);

  // ── Réseaux sociaux ─────────────────────────────────────────────────────────

  static bool getNetworkEnabled(String id) =>
      networks.get('${id}_enabled', defaultValue: false) as bool;

  static Future<void> setNetworkEnabled(String id, bool value) =>
      networks.put('${id}_enabled', value);

  static DateTime? getNetworkBlockedUntil(String id) {
    final raw = networks.get('${id}_blocked_until') as String?;
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static Future<void> setNetworkBlockedUntil(String id, DateTime? value) =>
      networks.put('${id}_blocked_until', value?.toIso8601String() ?? '');

  // ── Première ouverture ──────────────────────────────────────────────────────

  static bool get isFirstLaunch =>
      !(user.get('initialized', defaultValue: false) as bool);

  static Future<void> markInitialized([String firstName = '']) async {
    await user.put('initialized', true);
    await user.put('firstName', firstName);
    await user.put('memberSince', DateTime.now().toIso8601String());
  }

  // ── Profil utilisateur ──────────────────────────────────────────────────────

  static String get pseudo =>
      user.get('pseudo', defaultValue: '') as String;

  static Future<void> savePseudo(String value) =>
      user.put('pseudo', value);

  static String get firstName =>
      user.get('firstName', defaultValue: '') as String;

  static String get lastName =>
      user.get('lastName', defaultValue: '') as String;

  static String get email =>
      user.get('email', defaultValue: '') as String;

  static String get memberSince =>
      user.get('memberSince', defaultValue: '') as String;

  static Future<void> saveProfile({
    required String firstName,
    required String lastName,
    required String email,
  }) async {
    await user.put('firstName', firstName);
    await user.put('lastName', lastName);
    await user.put('email', email);
  }
}
