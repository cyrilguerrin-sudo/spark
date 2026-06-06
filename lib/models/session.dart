import 'package:intl/intl.dart';

class Session {
  final String id;
  final String networkId;
  final String networkName;
  final String intention;
  final int plannedDurationMinutes;
  final int actualDurationMinutes;
  final DateTime startTime;
  final DateTime? endTime;

  const Session({
    required this.id,
    required this.networkId,
    required this.networkName,
    required this.intention,
    required this.plannedDurationMinutes,
    this.actualDurationMinutes = 0,
    required this.startTime,
    this.endTime,
  });

  bool get isToday {
    final now = DateTime.now();
    return startTime.year == now.year &&
        startTime.month == now.month &&
        startTime.day == now.day;
  }

  // Positif = dépassement (rouge), négatif = respecté (vert)
  int get deltaMinutes => actualDurationMinutes - plannedDurationMinutes;
  bool get isRespected => deltaMinutes <= 0;

  // Format "14h21" pour correspondre au style français de la maquette
  String get formattedStartTime => DateFormat("HH'h'mm").format(startTime);

  String get formattedDelta {
    final sign = deltaMinutes > 0 ? '+' : '';
    return '$sign$deltaMinutes min';
  }

  Session copyWith({int? actualDurationMinutes, DateTime? endTime}) {
    return Session(
      id: id,
      networkId: networkId,
      networkName: networkName,
      intention: intention,
      plannedDurationMinutes: plannedDurationMinutes,
      actualDurationMinutes: actualDurationMinutes ?? this.actualDurationMinutes,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}
