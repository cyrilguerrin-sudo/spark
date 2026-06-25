import ManagedSettings
import DeviceActivity
import Foundation

private let kAppGroup = "group.com.cyrilguerrin.spark"

private enum K {
    static let sessionEndTime          = "KEY_SESSION_END_TIME"
    static let sessionNetworkId        = "KEY_SESSION_NETWORK_ID"
    static let sessionStartTime        = "KEY_SESSION_START_TIME"
    static let sessionPausedAt         = "KEY_SESSION_PAUSED_AT"
    static let sessionRemainingMs      = "KEY_SESSION_REMAINING_MS"
    static let blockUntil              = "KEY_BLOCK_UNTIL"
    static let blockNetworkId          = "KEY_BLOCK_NETWORK_ID"
    static let focusActive             = "KEY_FOCUS_ACTIVE"
    static let focusTokens             = "KEY_FOCUS_TOKENS"
}

private extension DeviceActivityName {
    static let block5 = DeviceActivityName("spark.block5min")
}

class ShieldActionExtension: ShieldActionDelegate {

    private var ud: UserDefaults? { UserDefaults(suiteName: kAppGroup) }
    private let store = ManagedSettingsStore()

    // MARK: - Application shield actions

    override func handle(action: ShieldAction,
                         for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        guard let ud = ud else { completionHandler(.close); return }

        // Focus mode only has one button ("Fermer") mapped to primary
        if ud.bool(forKey: K.focusActive) {
            completionHandler(.close)
            return
        }

        switch action {
        case .primaryButtonPressed:
            // "Bloquer 5 min" — keep app blocked, start 5-min countdown
            blockFor5Minutes(ud: ud)
            completionHandler(.defer)

        case .secondaryButtonPressed:
            // "Terminer la session" — clear state, lift shield, go home
            terminateSession(ud: ud)
            completionHandler(.close)

        @unknown default:
            completionHandler(.close)
        }
    }

    // MARK: - Web / category (unused by Spark)

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

    // MARK: - "Bloquer 5 min"

    private func blockFor5Minutes(ud: UserDefaults) {
        let blockUntil = Date().timeIntervalSince1970 + 5 * 60
        let networkId  = ud.string(forKey: K.sessionNetworkId) ?? ""

        ud.set(blockUntil, forKey: K.blockUntil)
        ud.set(networkId,  forKey: K.blockNetworkId)

        // The shield in ManagedSettings is NOT removed — it stays until spark.block5min fires.
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

    // MARK: - "Terminer la session"

    private func terminateSession(ud: UserDefaults) {
        // Clear all session keys
        ud.set(0.0, forKey: K.sessionEndTime)
        ud.set(0.0, forKey: K.sessionStartTime)
        ud.set(0.0, forKey: K.sessionPausedAt)
        ud.set(0.0, forKey: K.sessionRemainingMs)
        ud.removeObject(forKey: K.sessionNetworkId)

        // Lift the ManagedSettings shield so the next Shortcut trigger shows the
        // intention screen instead of the shield again.
        store.shield.applications = nil
    }
}
