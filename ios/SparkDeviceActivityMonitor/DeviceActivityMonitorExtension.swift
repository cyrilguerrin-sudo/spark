import DeviceActivity
import FamilyControls
import ManagedSettings
import Foundation
import os

private let logger = Logger(subsystem: "com.cyrilguerrin.spark", category: "DeviceActivityMonitor")

private enum AppGroupStore {
    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.cyrilguerrin.spark")?
            .appendingPathComponent("spark_prefs.plist")
    }
    static func read() -> [String: Any] {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let obj  = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dict = obj as? [String: Any] else { return [:] }
        return dict
    }
    static func write(_ dict: [String: Any]) {
        guard let url = fileURL,
              let data = try? PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0)
        else { return }
        try? data.write(to: url, options: .atomic)
    }
    static func set(_ key: String, _ value: Any?) {
        var d = read()
        if let v = value { d[key] = v } else { d.removeValue(forKey: key) }
        write(d)
    }
}

extension DeviceActivityName {
    static let session = DeviceActivityName("spark.session")
    static let pause45 = DeviceActivityName("spark.pause45")
    static let block5  = DeviceActivityName("spark.block5min")
}

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
    static let sessionCancelledPending = "KEY_SESSION_CANCELLED_PENDING"
}

class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let managedStore = ManagedSettingsStore()

    // MARK: - DeviceActivityMonitor callbacks

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        logger.debug("[DeviceActivityMonitor] intervalDidEnd: \(activity.rawValue, privacy: .public)")

        switch activity {
        case .session: handleSessionExpiry()
        case .pause45: silentReset()
        case .block5:  handleBlock5Expiry()
        default:       break
        }
    }

    // Fires when the user has spent `threshold` minutes inside the monitored app.
    // activity = "spark.session.<networkId>", event = "spark.unlock.<networkId>"
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        logger.debug("[DeviceActivityMonitor] eventDidReachThreshold: activity=\(activity.rawValue, privacy: .public) event=\(event.rawValue, privacy: .public)")

        DeviceActivityCenter().stopMonitoring([activity])

        var d = AppGroupStore.read()
        let now = Date().timeIntervalSince1970

        // Stamp accurate end time (usage-based, may differ slightly from wall-clock endTime)
        let startTime = d[K.sessionStartTime] as? Double ?? 0.0
        if startTime > 0 {
            d[K.sessionEndTime] = now
            AppGroupStore.write(d)
            saveSessionToHistory(d)
        }

        // Clear all session state (including paused keys — otherwise handleSessionResumeIfNeeded
        // in AppDelegate will resurrect the session when Spark next becomes active)
        d[K.sessionEndTime]   = 0.0
        d[K.sessionStartTime] = 0.0
        d[K.sessionPausedAt]  = 0.0
        d[K.sessionRemainingMs] = 0.0
        d.removeValue(forKey: K.sessionNetworkId)
        AppGroupStore.write(d)

        applyMonitoredShield(d)
        logger.debug("[DeviceActivityMonitor] eventDidReachThreshold: session closed, shield re-applied")
    }

    // MARK: - spark.session expired → reblock the monitored app

    private func handleSessionExpiry() {
        let s = AppGroupStore.read()
        let endTime = s[K.sessionEndTime] as? Double ?? 0.0
        let now = Date().timeIntervalSince1970
        logger.debug("[DeviceActivityMonitor] handleSessionExpiry: endTime=\(endTime) now=\(now)")

        guard endTime > 0 else {
            logger.debug("[DeviceActivityMonitor] handleSessionExpiry: no active session (endTime=0), skipping")
            return
        }
        guard now >= endTime - 5 else {
            logger.debug("[DeviceActivityMonitor] handleSessionExpiry: fired too early (delta=\(endTime - now)s), skipping")
            return
        }

        saveSessionToHistory(s)
        applyMonitoredShield(s)
    }

    // MARK: - spark.pause45 expired → silent reset

    private func silentReset() {
        var d = AppGroupStore.read()
        let networkId = d[K.sessionNetworkId] as? String ?? ""
        d[K.sessionEndTime]          = 0.0
        d[K.sessionStartTime]        = 0.0
        d[K.sessionPausedAt]         = 0.0
        d[K.sessionRemainingMs]      = 0.0
        d[K.sessionCancelledPending] = true
        d.removeValue(forKey: K.sessionNetworkId)
        AppGroupStore.write(d)

        let center = DeviceActivityCenter()
        // Stop both old (.session) and new-style ("spark.session.<networkId>") activity if present
        center.stopMonitoring([.session])
        if !networkId.isEmpty {
            center.stopMonitoring([DeviceActivityName("spark.session.\(networkId)")])
        }
        applyMonitoredShield(d)
        logger.debug("[DeviceActivityMonitor] silentReset complete, sessionCancelledPending written")
    }

    // MARK: - spark.block5min expired

    private func handleBlock5Expiry() {
        var d = AppGroupStore.read()
        d[K.blockUntil] = 0.0
        d.removeValue(forKey: K.blockNetworkId)
        AppGroupStore.write(d)

        // Re-apply the default shield on all monitored apps
        applyMonitoredShield(d)
    }

    // MARK: - ManagedSettings

    private func applyMonitoredShield(_ store: [String: Any]) {
        guard let data = store[K.monitoredTokens] as? Data else {
            logger.error("[DeviceActivityMonitor] applyMonitoredShield: KEY_MONITORED_TOKENS missing from store")
            return
        }
        guard let selection = decodeSelection(from: data) else {
            logger.error("[DeviceActivityMonitor] applyMonitoredShield: decode failed (\(data.count)B)")
            return
        }
        guard !selection.applicationTokens.isEmpty else {
            logger.debug("[DeviceActivityMonitor] applyMonitoredShield: selection is empty, nothing to shield")
            return
        }

        managedStore.shield.applications = selection.applicationTokens
        let readBack = managedStore.shield.applications?.count ?? 0
        logger.debug("[DeviceActivityMonitor] applyMonitoredShield: wrote \(selection.applicationTokens.count) tokens → store read-back: \(readBack) tokens")
    }

    private func decodeSelection(from data: Data) -> FamilyActivitySelection? {
        // PropertyListDecoder first — KEY_MONITORED_TOKENS is now Codable-encoded.
        if let sel = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data) {
            return sel
        }
        // Fallback for any legacy NSKeyedArchiver-encoded data on device.
        guard let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        unarchiver.requiresSecureCoding = false
        let obj = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey)
        unarchiver.finishDecoding()
        return obj as? FamilyActivitySelection
    }

    // MARK: - Session history

    private func saveSessionToHistory(_ s: [String: Any]) {
        let endTime   = s[K.sessionEndTime]   as? Double ?? 0.0
        let startTime = s[K.sessionStartTime] as? Double ?? 0.0
        let networkId = s[K.sessionNetworkId] as? String ?? ""

        guard startTime > 0, endTime > startTime else { return }

        let entry: [String: Any] = [
            "networkId":       networkId,
            "startTimeMs":     Int64(startTime * 1000),
            "durationSeconds": Int(endTime - startTime)
        ]

        var history: [[String: Any]] = []
        if let jsonStr = s[K.sessionHistory] as? String,
           let data    = jsonStr.data(using: .utf8),
           let parsed  = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            history = parsed
        }
        history.append(entry)

        guard let encoded = try? JSONSerialization.data(withJSONObject: history),
              let jsonStr = String(data: encoded, encoding: .utf8)
        else { return }

        AppGroupStore.set(K.sessionHistory, jsonStr)
    }
}
