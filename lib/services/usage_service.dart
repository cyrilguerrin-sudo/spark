import 'package:app_usage/app_usage.dart';

class UsageService {
  static Future<Map<String, Duration>> getTodayUsage() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final stats = await AppUsage().getAppUsage(startOfDay, now);
    return {for (final s in stats) s.packageName: s.usage};
  }
}
