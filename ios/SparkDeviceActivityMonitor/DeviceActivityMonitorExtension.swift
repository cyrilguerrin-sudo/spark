import DeviceActivity
import FamilyControls
import ManagedSettings
import Foundation

private let kAppGroup = "group.com.cyrilguerrin.spark"

// Schedule names — used by AppDelegate, SparkAppIntent and this extension.
// Centralised here; import this file in other extension targets if needed.
extension DeviceActivityName {
    // Session countdown started by AppDelegate.setSessionEndTime
    static let session = DeviceActivityName("spark.session")
    // 45-second inactivity watchdog started by AppDelegate.applicationWillResignActive
    // when a session is active and the user leaves Spark.
    // Cancelled by AppDelegate.applicationDidBecomeActive if user returns in time.
    static let pause45 = DeviceActivityName("spark.pause45")
    // 5-minute block countdown started by ShieldActionExtension on primaryButtonPressed
    static let block5  = DeviceActivityName("spark.block5min")
}

// Keys must stay byte-for-byte identical to AppDelegate.UDKey.
// Extensions are separate processes — no shared Swift module.
private enum K {
    static let sessionEndTime          = "KEY_SESSION_END_TIME"
    static let sessionNetworkId        = "KEY_SESSION_NETWORK_ID"
    static let sessionStartTime        = "KEY_SESSION_START_TIME"
    static let sessionPausedAt         = "KEY_SESSION_PAUSED_AT"
    static let sessionRemainingMs      = "KEY_SESSION_REMAINING_MS"
    static let monitoredTokens         = "KEY_MONITORED_TOKENS"
    static let blockUntil              = "KEY_BLOCK_UNTIL"
    static let blockNetworkId          = "KEY_BLOCK_NETWORK_ID"
    static let focusActive             = "KEY_FOCUS_ACTIVE"
    static let sessionHistory          = "KEY_SESSION_HISTORY"
    // Consumed by AppDelegate.applicationDidBecomeActive → sent to Flutter as onSessionCancelled
    static let sessionCancelledPending = "KEY_SESSION_CANCELLED_PENDING"
}

class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private var ud: UserDefaults? { UserDefaults(suiteName: kAppGroup) }
    private let store = ManagedSettingsStore()

    // MARK: - DeviceActivityMonitor callbacks

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        switch activity {
        case .session: handleSessionExpiry()
        case .pause45: silentReset()
        case .block5:  handleBlock5Expiry()
        default:       break
        }
    }

    // MARK: - spark.session expired → reblock the monitored app

    private func handleSessionExpiry() {
        guard let ud = ud else { return }

        let endTime = ud.double(forKey: K.sessionEndTime)
        // Guard: session already cleared (user terminated manually before timer fired)
        guard endTime > 0 else { return }
        // Guard: stale callback — timestamp should be at most a few seconds in the past
        guard Date().timeIntervalSince1970 >= endTime - 5 else { return }

        // Persist the completed session in history before blocking
        saveSessionToHistory(ud: ud)

        // Reblock → iOS overlays the Shield on top of the open app
        // Session keys are NOT cleared here: ShieldActionExtension clears them
        // when the user taps "Terminer la session".
        applyMonitoredShield()
    }

    // MARK: - spark.pause45 expired → user stayed away for 45 s → silent reset

    // Called when the 45-second watchdog schedule (started by AppDelegate) fires.
    // The user never returned to the session app — discard the session silently.
    private func silentReset() {
        guard let ud = ud else { return }

        // Wipe all session state
        ud.set(0.0, forKey: K.sessionEndTime)
        ud.set(0.0, forKey: K.sessionStartTime)
        ud.set(0.0, forKey: K.sessionPausedAt)
        ud.set(0.0, forKey: K.sessionRemainingMs)
        ud.removeObject(forKey: K.sessionNetworkId)

        // Cancel the main session timer (it might still be ticking)
        DeviceActivityCenter().stopMonitoring([.session])

        // Lift any active shield so the app doesn't stay stuck
        store.shield.applications = nil

        // Signal the main app to reset the Flutter timer on next foreground
        ud.set(true, forKey: K.sessionCancelledPending)
    }

    // MARK: - spark.block5min expired → user chose "Bloquer 5 min" on the Shield

    private func handleBlock5Expiry() {
        guard let ud = ud else { return }

        ud.set(0.0, forKey: K.blockUntil)
        ud.removeObject(forKey: K.blockNetworkId)

        // Remove block shield — the Shortcut will intercept the next open
        // and show the intention screen for a new session.
        store.shield.applications = nil
    }

    // MARK: - ManagedSettings

    private func applyMonitoredShield() {
        guard let data = ud?.data(forKey: K.monitoredTokens),
              let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data),
              !selection.applicationTokens.isEmpty
        else { return }

        store.shield.applications = selection.applicationTokens
    }

    // MARK: - Session history

    private func saveSessionToHistory(ud: UserDefaults) {
        let endTime   = ud.double(forKey: K.sessionEndTime)
        let startTime = ud.double(forKey: K.sessionStartTime)
        let networkId = ud.string(forKey: K.sessionNetworkId) ?? ""

        guard startTime > 0, endTime > startTime else { return }

        let entry: [String: Any] = [
            "networkId":       networkId,
            "startTimeMs":     Int64(startTime * 1000),
            "durationSeconds": Int(endTime - startTime)
        ]

        var history: [[String: Any]] = []
        if let jsonStr = ud.string(forKey: K.sessionHistory),
           let data    = jsonStr.data(using: .utf8),
           let parsed  = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            history = parsed
        }
        history.append(entry)

        guard let encoded = try? JSONSerialization.data(withJSONObject: history),
              let jsonStr = String(data: encoded, encoding: .utf8)
        else { return }

        ud.set(jsonStr, forKey: K.sessionHistory)
    }
}
