import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Incoming events (Swift → Flutter) ────────────────────────────────────────

/// Base class for all events dispatched from Swift via MethodChannel.
/// Pattern-match in app.dart:
///   ref.listen(nativeEventProvider, (_, next) {
///     next.whenData((event) {
///       if (event is AppInterceptedEvent) { ... }
///       if (event is SessionCancelledEvent) { ... }
///     });
///   });
sealed class IoNativeEvent {}

/// Swift called onAppIntercepted: user opened a monitored app with no active session.
/// [networkId] is "instagram", "tiktok" or "youtube".
class AppInterceptedEvent extends IoNativeEvent {
  final String networkId;
  AppInterceptedEvent(this.networkId);
}

/// Swift called onSessionCancelled: the pause grace period expired.
/// Flutter should reset the session timer without navigating.
class SessionCancelledEvent extends IoNativeEvent {}

// ── Service ───────────────────────────────────────────────────────────────────

class FamilyControlsService {
  static const _channel = MethodChannel('com.example.spark/familycontrols');

  static final _eventCtrl = StreamController<IoNativeEvent>.broadcast();

  /// Stream of events coming from Swift. Back-pressured via Riverpod's
  /// [nativeEventProvider]. Multiple listeners allowed (broadcast).
  static Stream<IoNativeEvent> get eventStream => _eventCtrl.stream;

  /// Call once from app.dart initState (iOS only).
  /// Registers the Swift → Flutter MethodChannel handler.
  static void init() {
    if (!Platform.isIOS) return;
    _channel.setMethodCallHandler(_onIncoming);
  }

  static Future<dynamic> _onIncoming(MethodCall call) async {
    final args = call.arguments is Map
        ? Map<String, dynamic>.from(call.arguments as Map)
        : <String, dynamic>{};

    switch (call.method) {
      case 'onAppIntercepted':
        final networkId = args['networkId'] as String? ?? '';
        if (networkId.isNotEmpty) {
          _eventCtrl.add(AppInterceptedEvent(networkId));
        }
      case 'onSessionCancelled':
        _eventCtrl.add(SessionCancelledEvent());
    }
  }

  // ── Authorization ───────────────────────────────────────────────────────────

  /// Displays the system FamilyControls authorization dialog.
  /// Returns true once the user has approved. Can be called multiple times
  /// safely (iOS shows the dialog only if not already authorized).
  static Future<bool> requestAuthorization() async {
    try {
      return await _channel.invokeMethod<bool>('requestAuthorization') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Returns true if FamilyControls has already been authorized.
  static Future<bool> checkAuthorization() async {
    try {
      return await _channel.invokeMethod<bool>('checkAuthorization') ?? false;
    } on PlatformException {
      return false;
    }
  }

  // ── App monitoring ──────────────────────────────────────────────────────────

  /// Presents a FamilyActivityPicker titled for [network] ("instagram"|"tiktok"|"youtube").
  /// The selected token is stored individually (KEY_TOKEN_X) and the combined shield
  /// is applied immediately. Returns when the picker is dismissed.
  static Future<void> setMonitoredNetwork(String network) async {
    try {
      debugPrint('[Spark] setMonitoredNetwork($network) → invoking channel');
      await _channel.invokeMethod('setMonitoredNetwork', {'network': network});
      debugPrint('[Spark] setMonitoredNetwork($network) → channel returned OK');
    } catch (e) {
      debugPrint('[Spark] setMonitoredNetwork($network) → ERROR: $e');
    }
  }

  /// Returns the list of network IDs that have a stored token
  /// (e.g. ["instagram", "youtube"] if those two were set up).
  static Future<List<String>> getConfiguredNetworks() async {
    try {
      final result = await _channel.invokeMethod<List>('getConfiguredNetworks');
      return result?.cast<String>() ?? [];
    } catch (_) {
      return [];
    }
  }

  // ── App monitoring info ─────────────────────────────────────────────────────

  /// Returns the total number of applicationTokens across all configured networks.
  static Future<int> getMonitoredAppsCount() async {
    try {
      return await _channel.invokeMethod<int>('getMonitoredAppsCount') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Opens iOS Screen Time settings natively via Swift (bypasses url_launcher).
  static Future<void> openScreenTimeSettings() async {
    try {
      await _channel.invokeMethod('openScreenTimeSettings');
    } catch (_) {}
  }

  // ── Liquid Glass ─────────────────────────────────────────────────────────────

  /// Returns true if the device supports the native Liquid Glass material
  /// (iOS 26+). Used to pick between [LiquidGlassBottomNav] and the legacy
  /// Flutter-drawn nav bar.
  static Future<bool> supportsLiquidGlass() async {
    if (!Platform.isIOS) return false;
    try {
      return await _channel.invokeMethod<bool>('checkLiquidGlassSupport') ?? false;
    } on PlatformException {
      return false;
    }
  }

  // ── Session lifecycle ───────────────────────────────────────────────────────

  /// Starts a session: removes the ManagedSettings shield from the monitored
  /// app so the user can enter, and arms the DeviceActivity timer.
  ///
  /// [endTimeMs] — epoch milliseconds, same convention as monitor_service.dart.
  /// Swift converts to Double seconds internally.
  static Future<void> setSessionEndTime(int endTimeMs, String networkId) async {
    try {
      // Swift expects seconds-since-epoch (Double), not milliseconds
      final endTimeSecs   = endTimeMs / 1000.0;
      final startTimeSecs = DateTime.now().millisecondsSinceEpoch / 1000.0;
      await _channel.invokeMethod('setSessionEndTime', {
        'endTime':   endTimeSecs,
        'networkId': networkId,
        'startTime': startTimeSecs,
      });
    } on PlatformException catch (_) {}
  }

  /// Resets the session: re-shields monitored apps and cancels the DeviceActivity
  /// schedule. Called when the user cancels a session from inside Flutter.
  static Future<void> clearSessionEndTime() async {
    try {
      await _channel.invokeMethod('clearSessionEndTime');
    } on PlatformException catch (_) {}
  }

  // ── Focus mode ──────────────────────────────────────────────────────────────

  /// Activates or deactivates Focus mode.
  ///
  /// [goal] is shown as the Shield subtitle. Stored in App Group UserDefaults
  /// under KEY_FOCUS_GOAL so ShieldConfigurationExtension can read it.
  ///
  /// App tokens are NOT passed from Flutter: Swift automatically uses the
  /// FamilyActivitySelection stored in KEY_MONITORED_TOKENS as the block list.
  static Future<void> setFocusMode({
    required bool active,
    String? goal,
  }) async {
    try {
      await _channel.invokeMethod('setFocusMode', {
        'active': active,
        if (active && goal != null && goal.isNotEmpty) 'goal': goal,
      });
    } on PlatformException catch (_) {}
  }

  // ── Session history ─────────────────────────────────────────────────────────

  /// Returns today's session history as a JSON string in the format expected
  /// by [SessionHistoryEntry.fromJson]: {"networkId", "startTime" (ms int),
  /// "durationMinutes" (int)}.
  ///
  /// Swift stores {"networkId", "startTimeMs" (ms), "durationSeconds"} —
  /// this method converts between the two formats transparently.
  static Future<String> getSessionHistory() async {
    try {
      final raw =
          await _channel.invokeMethod<String>('getSessionHistory') ?? '[]';
      return _convertHistoryJson(raw);
    } on PlatformException {
      return '[]';
    }
  }

  /// Converts the iOS JSON format to the Flutter [SessionHistoryEntry] format.
  static String _convertHistoryJson(String rawJson) {
    try {
      final list = jsonDecode(rawJson) as List<dynamic>;
      final converted = list.map((item) {
        final e = Map<String, dynamic>.from(item as Map);
        final durationSecs = (e['durationSeconds'] as num?)?.toInt() ?? 0;
        return <String, dynamic>{
          'networkId':       e['networkId'] as String? ?? '',
          // startTimeMs is already epoch milliseconds
          'startTime':       (e['startTimeMs'] as num?)?.toInt() ?? 0,
          // Round up so a sub-minute session shows "1 min" not "0 min"
          'durationMinutes': (durationSecs / 60).ceil().clamp(1, 9999),
        };
      }).toList();
      return jsonEncode(converted);
    } catch (_) {
      return '[]';
    }
  }
}

// ── Riverpod ──────────────────────────────────────────────────────────────────

/// Exposes the stream of Swift → Flutter events.
///
/// Usage in app.dart:
/// ```dart
/// ref.listen<AsyncValue<IoNativeEvent>>(nativeEventProvider, (_, next) {
///   next.whenData((event) {
///     switch (event) {
///       case AppInterceptedEvent(:final networkId):
///         appRouter.go('/intention', extra: {'networkId': networkId});
///       case SessionCancelledEvent():
///         ref.read(sessionTimerProvider.notifier).reset();
///     }
///   });
/// });
/// ```
final nativeEventProvider = StreamProvider<IoNativeEvent>((ref) {
  return FamilyControlsService.eventStream;
});
