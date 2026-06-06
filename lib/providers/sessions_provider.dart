import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session.dart';
import '../core/constants.dart';

class SessionsNotifier extends StateNotifier<List<Session>> {
  SessionsNotifier() : super([]);

  void addSession(Session session) {
    state = [...state, session];
  }

  void updateSession(Session updated) {
    state = [
      for (final s in state)
        if (s.id == updated.id) updated else s,
    ];
  }

  List<Session> sessionsToday(String networkId) {
    return state.where((s) => s.networkId == networkId && s.isToday).toList();
  }

  // Limite 10min à partir de la 2ème session sur le même réseau dans la journée
  int maxSessionDuration(String networkId) {
    return sessionsToday(networkId).isNotEmpty
        ? AppDurations.sessionTimerMaxMinutesRepeated
        : AppDurations.sessionTimerMaxMinutes;
  }

  // Temps économisé = somme des (planifié - réel) pour les sessions respectées
  int get savedMinutesToday {
    return state
        .where((s) => s.isToday && s.isRespected)
        .fold(0, (sum, s) => sum + s.deltaMinutes.abs());
  }
}

final sessionsProvider =
    StateNotifierProvider<SessionsNotifier, List<Session>>(
  (ref) => SessionsNotifier(),
);
