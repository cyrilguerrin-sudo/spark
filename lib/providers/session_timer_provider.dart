import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/monitor_service.dart';

enum TimerStatus { idle, running, expired }

class SessionTimerState {
  final TimerStatus status;
  final Duration remaining;
  final String networkId;
  final int endTimeMs;

  const SessionTimerState({
    this.status = TimerStatus.idle,
    this.remaining = Duration.zero,
    this.networkId = '',
    this.endTimeMs = 0,
  });

  bool get isActive => status == TimerStatus.running;

  SessionTimerState copyWith({
    TimerStatus? status,
    Duration? remaining,
  }) {
    return SessionTimerState(
      status: status ?? this.status,
      remaining: remaining ?? this.remaining,
      networkId: networkId,
      endTimeMs: endTimeMs,
    );
  }
}

class SessionTimerNotifier extends StateNotifier<SessionTimerState> {
  SessionTimerNotifier() : super(const SessionTimerState());

  Timer? _timer;

  void start(String networkId, int minutes) {
    _timer?.cancel();

    final endTimeMs = DateTime.now()
        .add(Duration(minutes: minutes))
        .millisecondsSinceEpoch;

    // Écriture directe dans SharedPreferences via le service natif.
    // C'est le seul endroit où KEY_SESSION_END_TIME est écrit — aucune
    // autre partie du code ne touche à cette valeur, ce qui élimine toute
    // race condition avec _syncConfig().
    MonitorService.setSessionEndTime(endTimeMs, networkId);

    state = SessionTimerState(
      status: TimerStatus.running,
      remaining: Duration(minutes: minutes),
      networkId: networkId,
      endTimeMs: endTimeMs,
    );

    // Timer Dart uniquement pour l'affichage du compte à rebours.
    // Le verrouillage réel est déclenché par AppMonitorService qui poll
    // KEY_SESSION_END_TIME toutes les secondes, indépendamment de Flutter.
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      final next = state.remaining - const Duration(seconds: 1);
      if (next.inSeconds <= 0) {
        t.cancel();
        state = state.copyWith(
          status: TimerStatus.expired,
          remaining: Duration.zero,
        );
      } else {
        state = state.copyWith(remaining: next);
      }
    });
  }

  void reset() {
    _timer?.cancel();
    // Efface le timestamp natif pour que le service ne déclenche pas
    // un verrou intempestif après un reset manuel.
    MonitorService.clearSessionEndTime();
    state = const SessionTimerState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final sessionTimerProvider =
    StateNotifierProvider<SessionTimerNotifier, SessionTimerState>(
  (ref) => SessionTimerNotifier(),
);
