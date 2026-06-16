import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/monitor_service.dart';

class SessionTimerState {
  final bool isActive;
  final String networkId;
  final int startTimeMs;

  const SessionTimerState({
    this.isActive = false,
    this.networkId = '',
    this.startTimeMs = 0,
  });
}

class SessionTimerNotifier extends StateNotifier<SessionTimerState> {
  SessionTimerNotifier() : super(const SessionTimerState());

  void start(String networkId, int minutes) {
    final endTimeMs = DateTime.now()
        .add(Duration(minutes: minutes))
        .millisecondsSinceEpoch;
    MonitorService.setSessionEndTime(endTimeMs, networkId);
    state = SessionTimerState(
      isActive: true,
      networkId: networkId,
      startTimeMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  void reset() {
    MonitorService.clearSessionEndTime();
    state = const SessionTimerState();
  }
}

final sessionTimerProvider =
    StateNotifierProvider<SessionTimerNotifier, SessionTimerState>(
  (ref) => SessionTimerNotifier(),
);
