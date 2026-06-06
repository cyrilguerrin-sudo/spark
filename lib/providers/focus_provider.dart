import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/focus_session.dart';

class FocusNotifier extends StateNotifier<FocusSession?> {
  FocusNotifier() : super(null);

  bool get isActive => state != null;

  void startSession({
    required String objective,
    required List<String> blockedApps,
  }) {
    state = FocusSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      objective: objective,
      blockedApps: blockedApps,
      startTime: DateTime.now(),
    );
  }

  void checkObjective() {
    if (state != null) {
      state = state!.copyWith(isObjectiveChecked: true);
    }
  }

  void endSession() {
    state = null;
  }

  bool isAppBlocked(String networkId) {
    if (state == null) return false;
    return state!.blockedApps.contains(networkId);
  }
}

final focusProvider = StateNotifierProvider<FocusNotifier, FocusSession?>(
  (ref) => FocusNotifier(),
);
