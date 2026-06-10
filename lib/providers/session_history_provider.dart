import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session_history_entry.dart';
import '../services/monitor_service.dart';

class SessionHistoryNotifier
    extends StateNotifier<AsyncValue<List<SessionHistoryEntry>>> {
  SessionHistoryNotifier() : super(const AsyncLoading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      final json = await MonitorService.getSessionHistory();
      final entries = SessionHistoryEntry.parseList(json);
      entries.sort((a, b) => b.startTime.compareTo(a.startTime));
      state = AsyncData(entries);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final sessionHistoryProvider = StateNotifierProvider<SessionHistoryNotifier,
    AsyncValue<List<SessionHistoryEntry>>>(
  (ref) => SessionHistoryNotifier(),
);

/// Baseline "sans Spark" en minutes/jour — calculée une seule fois au premier
/// lancement, puis lue depuis SharedPreferences.
final baselineProvider = FutureProvider<int>((ref) async {
  return MonitorService.getOrComputeBaseline();
});
