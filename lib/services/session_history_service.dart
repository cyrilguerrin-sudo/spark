import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/session_history_entry.dart';

class SessionHistoryService {
  static const _boxName = 'session_history';
  static const _key = 'entries';

  static Box get _box => Hive.box(_boxName);

  static Future<void> saveSession(
    String networkId,
    int startTimeMs,
    int durationSeconds,
  ) async {
    final entry = SessionHistoryEntry(
      networkId: networkId,
      startTimeMs: startTimeMs,
      durationSeconds: durationSeconds,
    );

    final existing = getTodaySessions();
    final updated = [...existing, entry];
    await _box.put(_key, jsonEncode(updated.map((e) => e.toJson()).toList()));
  }

  static List<SessionHistoryEntry> getTodaySessions() {
    final raw = _box.get(_key) as String?;
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final now = DateTime.now();
      return list
          .map((e) => SessionHistoryEntry.fromJson(e as Map<String, dynamic>))
          .where((e) {
            final dt = DateTime.fromMillisecondsSinceEpoch(e.startTimeMs);
            return dt.year == now.year &&
                dt.month == now.month &&
                dt.day == now.day;
          })
          .toList();
    } catch (_) {
      return [];
    }
  }

  static int getTodayTotalSeconds() =>
      getTodaySessions().fold(0, (sum, e) => sum + e.durationSeconds);
}
