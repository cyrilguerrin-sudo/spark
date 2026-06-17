import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/focus_session.dart';
import '../services/monitor_service.dart';

class FocusNotifier extends StateNotifier<FocusSession?> {
  FocusNotifier() : super(null);

  bool get isActive => state != null;

  Future<void> activate({
    required String objective,
    required List<String> blockedApps,
  }) async {
    await MonitorService.setFocusMode(
      active: true,
      networkIds: blockedApps,
      objective: objective,
    );
    state = FocusSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      objective: objective,
      blockedApps: blockedApps,
      startTime: DateTime.now(),
    );
  }

  /// Lit l'état Focus depuis les SharedPreferences natives et réhydrate le state.
  /// Appelé au démarrage de l'app, avant _syncConfig(), pour éviter que
  /// focusProvider = null n'écrase KEY_FOCUS_ACTIVE = true côté natif.
  Future<void> loadFromNative() async {
    final data      = await MonitorService.getFocusState();
    final active    = data['active']    as bool?         ?? false;
    final objective = data['objective'] as String?       ?? '';
    final networkIds = (data['networkIds'] as List?)?.cast<String>() ?? [];
    if (!active) {
      state = null;
      return;
    }
    state = FocusSession(
      id:          DateTime.now().millisecondsSinceEpoch.toString(),
      objective:   objective,
      blockedApps: networkIds,
      startTime:   DateTime.now(),
    );
  }

  Future<void> deactivate() async {
    await MonitorService.setFocusMode(
      active: false,
      networkIds: [],
      objective: '',
    );
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
