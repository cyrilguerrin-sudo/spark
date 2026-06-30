import ManagedSettings
import ManagedSettingsUI
import UIKit

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
}

private enum K {
    static let sessionEndTime   = "KEY_SESSION_END_TIME"
    static let sessionStartTime = "KEY_SESSION_START_TIME"
    static let focusActive      = "KEY_FOCUS_ACTIVE"
    static let focusGoal        = "KEY_FOCUS_GOAL"
    static let blockUntil       = "KEY_BLOCK_UNTIL"
}

private extension UIColor {
    static let sparkBg     = UIColor(red: 0x0A/255, green: 0x0A/255, blue: 0x0A/255, alpha: 1)
    static let sparkOrange = UIColor(red: 0xE0/255, green: 0x5A/255, blue: 0x3A/255, alpha: 1)
    static let sparkMuted  = UIColor(red: 0xBB/255, green: 0xBB/255, blue: 0xBB/255, alpha: 1)
}

class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        buildConfiguration()
    }

    override func configuration(shielding application: Application,
                                in category: ActivityCategory) -> ShieldConfiguration {
        buildConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        ShieldConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain,
                                in category: ActivityCategory) -> ShieldConfiguration {
        ShieldConfiguration()
    }

    // MARK: - Build

    private func buildConfiguration() -> ShieldConfiguration {
        let store = AppGroupStore.read()
        let now   = Date().timeIntervalSince1970

        if store[K.focusActive] as? Bool == true {
            return buildFocusShield(store: store)
        }

        if (store[K.blockUntil] as? Double ?? 0.0) > now {
            return buildBlockShield()
        }

        let sessionEnd = store[K.sessionEndTime] as? Double ?? 0.0
        if sessionEnd > 0 && sessionEnd < now {
            return buildSessionEndShield(store: store)
        }

        return buildDefaultShield()
    }

    // MARK: - Default shield (permanent, no active session)

    private func buildDefaultShield() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundColor: .sparkBg,
            title:    .init(text: "Accès limité 🔒",    color: .white),
            subtitle: .init(text: "Ouvre l'app Spark manuellement pour démarrer une session.", color: .sparkMuted),
            primaryButtonLabel:           .init(text: "Ouvrir Spark", color: .white),
            primaryButtonBackgroundColor: .sparkOrange,
            secondaryButtonLabel:         .init(text: "Fermer",       color: .sparkMuted)
        )
    }

    // MARK: - Session end shield (shown after a session expired)

    private func buildSessionEndShield(store: [String: Any]) -> ShieldConfiguration {
        let endTime   = store[K.sessionEndTime]   as? Double ?? 0.0
        let startTime = store[K.sessionStartTime] as? Double ?? 0.0
        let subtitle  = sessionSubtitle(startTime: startTime, endTime: endTime)

        return ShieldConfiguration(
            backgroundColor: .sparkBg,
            title:    .init(text: "Session terminée 🔥",    color: .white),
            subtitle: .init(text: subtitle,                  color: .sparkMuted),
            primaryButtonLabel:           .init(text: "Bloquer 5 min",      color: .white),
            primaryButtonBackgroundColor: .sparkOrange,
            secondaryButtonLabel:         .init(text: "Terminer la session", color: .sparkMuted)
        )
    }

    // MARK: - 5-minute block shield

    private func buildBlockShield() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundColor: .sparkBg,
            title:    .init(text: "Bloqué 5 min 🔒",        color: .white),
            subtitle: .init(text: "Reviens dans un moment.", color: .sparkMuted),
            primaryButtonLabel:           .init(text: "Fermer", color: .white),
            primaryButtonBackgroundColor: .sparkOrange,
            secondaryButtonLabel: nil
        )
    }

    // MARK: - Focus mode shield

    private func buildFocusShield(store: [String: Any]) -> ShieldConfiguration {
        let goal     = store[K.focusGoal] as? String ?? ""
        let subtitle = goal.isEmpty ? "Reste concentré." : goal

        return ShieldConfiguration(
            backgroundColor: .sparkBg,
            title:    .init(text: "Tu es en mode Focus 🔥", color: .white),
            subtitle: .init(text: subtitle,                  color: .sparkMuted),
            primaryButtonLabel:           .init(text: "Fermer", color: .white),
            primaryButtonBackgroundColor: .sparkOrange,
            secondaryButtonLabel: nil
        )
    }

    // MARK: - Duration formatting

    private func sessionSubtitle(startTime: Double, endTime: Double) -> String {
        guard startTime > 0, endTime > startTime else {
            return "Que veux-tu faire ?"
        }
        let secs = Int(endTime - startTime)
        return "Tu as tenu \(formatDuration(secs)). Que veux-tu faire ?"
    }

    private func formatDuration(_ totalSeconds: Int) -> String {
        if totalSeconds < 60 { return "\(totalSeconds)s" }
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        if mins < 60 {
            return secs > 0 ? "\(mins) min \(secs)s" : "\(mins) min"
        }
        let hours = mins / 60
        let rem   = mins % 60
        return rem > 0 ? "\(hours)h \(rem) min" : "\(hours)h"
    }
}
