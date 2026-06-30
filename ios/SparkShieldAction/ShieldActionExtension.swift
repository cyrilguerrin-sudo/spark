import ManagedSettings
import ManagedSettingsUI
import FamilyControls
import DeviceActivity
import Foundation

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
}

private enum K {
    static let sessionEndTime       = "KEY_SESSION_END_TIME"
    static let sessionNetworkId     = "KEY_SESSION_NETWORK_ID"
    static let sessionStartTime     = "KEY_SESSION_START_TIME"
    static let sessionPausedAt      = "KEY_SESSION_PAUSED_AT"
    static let sessionRemainingMs   = "KEY_SESSION_REMAINING_MS"
    static let monitoredTokens      = "KEY_MONITORED_TOKENS"
    static let blockUntil           = "KEY_BLOCK_UNTIL"
    static let blockNetworkId       = "KEY_BLOCK_NETWORK_ID"
    static let focusActive          = "KEY_FOCUS_ACTIVE"
    static let focusTokens          = "KEY_FOCUS_TOKENS"
}

private extension DeviceActivityName {
    static let block5 = DeviceActivityName("spark.block5min")
}

class ShieldActionExtension: ShieldActionDelegate {

    private let store = ManagedSettingsStore()

    // MARK: - Application shield actions

    override func handle(action: ShieldAction,
                         for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        let s   = AppGroupStore.read()
        let now = Date().timeIntervalSince1970

        // Focus mode: always close immediately
        if s[K.focusActive] as? Bool == true {
            completionHandler(.close)
            return
        }

        // 5-min block is active: only "Fermer" visible → .close
        if (s[K.blockUntil] as? Double ?? 0.0) > now {
            completionHandler(.close)
            return
        }

        let sessionEnd = s[K.sessionEndTime] as? Double ?? 0.0

        if sessionEnd > 0 && sessionEnd < now {
            // Session just ended: primary = "Bloquer 5 min", secondary = "Terminer la session"
            switch action {
            case .primaryButtonPressed:
                blockFor5Minutes(store: s)
                completionHandler(.defer)
            case .secondaryButtonPressed:
                terminateSession(store: s)
                completionHandler(.close)
            default:
                completionHandler(.close)
            }
            return
        }

        // Default state (no active session, permanent shield):
        // Both buttons just close — user opens Spark manually.
        completionHandler(.close)
    }

    // MARK: - Web / category (unchanged)

    override func handle(action: ShieldAction,
                         for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(.close)
    }

    override func handle(action: ShieldAction,
                         for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(.close)
    }

    // MARK: - Session end state actions

    private func blockFor5Minutes(store s: [String: Any]) {
        let blockUntil = Date().timeIntervalSince1970 + 5 * 60
        let networkId  = s[K.sessionNetworkId] as? String ?? ""

        var d = s
        d[K.blockUntil]     = blockUntil
        d[K.blockNetworkId] = networkId
        AppGroupStore.write(d)

        scheduleBlock5Min()
    }

    private func scheduleBlock5Min() {
        let center = DeviceActivityCenter()
        center.stopMonitoring([.block5])

        let cal        = Calendar.current
        let startComps = cal.dateComponents([.era, .year, .month, .day, .hour, .minute, .second],
                                            from: Date().addingTimeInterval(1))
        let endComps   = cal.dateComponents([.era, .year, .month, .day, .hour, .minute, .second],
                                            from: Date().addingTimeInterval(5 * 60 + 1))

        let schedule = DeviceActivitySchedule(
            intervalStart: startComps,
            intervalEnd:   endComps,
            repeats:       false
        )
        try? center.startMonitoring(.block5, during: schedule)
    }

    // Clears session data and re-shields all monitored apps (permanent shield architecture).
    private func terminateSession(store s: [String: Any]) {
        var d = s
        d[K.sessionEndTime]     = 0.0
        d[K.sessionStartTime]   = 0.0
        d[K.sessionPausedAt]    = 0.0
        d[K.sessionRemainingMs] = 0.0
        d.removeValue(forKey: K.sessionNetworkId)
        AppGroupStore.write(d)

        if let data = d[K.monitoredTokens] as? Data,
           let sel  = decodeSelection(from: data),
           !sel.applicationTokens.isEmpty {
            store.shield.applications = sel.applicationTokens
        } else {
            store.shield.applications = nil
        }
    }

    // MARK: - FamilyActivitySelection decode helper

    private func decodeSelection(from data: Data) -> FamilyActivitySelection? {
        if let sel = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data) {
            return sel
        }
        guard let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        unarchiver.requiresSecureCoding = false
        let obj = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey)
        unarchiver.finishDecoding()
        return obj as? FamilyActivitySelection
    }
}
