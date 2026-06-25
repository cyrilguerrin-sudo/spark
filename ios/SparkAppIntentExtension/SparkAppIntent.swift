import AppIntents
import Foundation

private let kAppGroup = "group.com.cyrilguerrin.spark"

private enum K {
    static let sessionEndTime = "KEY_SESSION_END_TIME"
    static let focusActive    = "KEY_FOCUS_ACTIVE"
    static let blockUntil     = "KEY_BLOCK_UNTIL"
    // Consumed by AppDelegate.dispatchPendingExtensionEvents() on next applicationDidBecomeActive.
    // AppDelegate calls channel.invokeMethod("onAppIntercepted", ["networkId": value]).
    static let pendingNetwork = "KEY_PENDING_NETWORK_INTERCEPTION"
}

/// App Intent exposed to iOS Shortcuts for social-network interception.
///
/// User setup (repeat for each monitored network in Shortcuts.app):
///   Automatisation → "Quand Instagram est ouverte" → Activer Spark → network = "instagram"
///   Exécuter immédiatement, sans confirmation.
///
/// openAppWhenRun = true always — Spark is always brought to foreground.
/// Launch Pass logic (session/focus/block active → do nothing) lives entirely in perform().
struct SparkAppIntent: AppIntent {

    static var title: LocalizedStringResource = "Activer Spark"
    static var description = IntentDescription(
        "Intercepte l'ouverture d'un réseau social. Lance l'écran d'intention Spark si aucune session n'est active."
    )

    static var parameterSummary: some ParameterSummary {
        Summary("Activer Spark pour \(\.$network)")
    }

    // Always open Spark — compile-time constant required by AppIntents.
    static let openAppWhenRun = true

    /// Social network identifier, configured once per Shortcut automation.
    /// Accepted values: "instagram", "tiktok", "youtube".
    @Parameter(title: "Réseau", description: "instagram · tiktok · youtube")
    var network: String

    func perform() async throws -> some IntentResult {
        guard let ud = UserDefaults(suiteName: kAppGroup) else { return .result() }

        let now = Date().timeIntervalSince1970

        // Launch Pass: Shield already handles these cases — don't write the interception flag.
        if ud.bool(forKey: K.focusActive)           { return .result() }
        if ud.double(forKey: K.blockUntil) > now    { return .result() }
        if ud.double(forKey: K.sessionEndTime) > now { return .result() }

        // No active session: write the network so AppDelegate dispatches onAppIntercepted
        // in dispatchPendingExtensionEvents() on the next applicationDidBecomeActive.
        ud.set(network, forKey: K.pendingNetwork)
        return .result()
    }
}
