import 'dart:convert';
import 'package:intl/intl.dart';
import '../core/constants.dart';

class SessionHistoryEntry {
  final String networkId;
  final DateTime startTime;
  final int durationMinutes;

  const SessionHistoryEntry({
    required this.networkId,
    required this.startTime,
    required this.durationMinutes,
  });

  String get networkName => AppNetworks.names[networkId] ?? networkId;

  String get formattedTime => DateFormat("HH'h'mm").format(startTime);

  String get formattedDuration => '+ $durationMinutes min';

  bool get isToday {
    final now = DateTime.now();
    return startTime.year == now.year &&
        startTime.month == now.month &&
        startTime.day == now.day;
  }

  factory SessionHistoryEntry.fromJson(Map<String, dynamic> json) {
    return SessionHistoryEntry(
      networkId: json['networkId'] as String,
      startTime: DateTime.fromMillisecondsSinceEpoch(json['startTime'] as int),
      durationMinutes: json['durationMinutes'] as int,
    );
  }

  static List<SessionHistoryEntry> parseList(String jsonStr) {
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((e) => SessionHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
