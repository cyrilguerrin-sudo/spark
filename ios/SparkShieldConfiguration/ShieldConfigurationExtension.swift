import ManagedSettings
import ManagedSettingsUI
import UIKit

private let kAppGroup = "group.com.cyrilguerrin.spark"

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

    private var ud: UserDefaults? { UserDefaults(suiteName: kAppGroup) }

    // Shielded apps (session end or Focus block)
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        buildConfiguration()
    }

    override func configuration(shielding application: Application,
                                in category: ActivityCategory) -> ShieldConfiguration {
        buildConfiguration()
    }

    // Web domains: not used by Spark
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        ShieldConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain,
                                in category: ActivityCategory) -> ShieldConfiguration {
        ShieldConfiguration()
    }

    // MARK: - Build

    private func buildConfiguration() -> ShieldConfiguration {
        guard let ud = ud else { return ShieldConfiguration() }

        if ud.bool(forKey: K.focusActive) {
            return buildFocusShield(ud: ud)
        }

        if ud.double(forKey: K.blockUntil) > Date().timeIntervalSince1970 {
            return buildBlockShield()
        }

        return buildSessionEndShield(ud: ud)
    }

    // MARK: - Session end shield

    private func buildSessionEndShield(ud: UserDefaults) -> ShieldConfiguration {
        let endTime   = ud.double(forKey: K.sessionEndTime)
        let startTime = ud.double(forKey: K.sessionStartTime)
        let subtitle  = sessionSubtitle(startTime: startTime, endTime: endTime)

        return ShieldConfiguration(
            backgroundColor: .sparkBg,
            title:    .init(text: "Session terminée 🔥",     color: .white),
            subtitle: .init(text: subtitle,                   color: .sparkMuted),
            primaryButtonLabel:           .init(text: "Bloquer 5 min",        color: .white),
            primaryButtonBackgroundColor: .sparkOrange,
            secondaryButtonLabel:         .init(text: "Terminer la session",   color: .sparkMuted)
        )
    }

    // MARK: - 5-minute block shield (user already chose "Bloquer 5 min")

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

    private func buildFocusShield(ud: UserDefaults) -> ShieldConfiguration {
        let goal = ud.string(forKey: K.focusGoal) ?? ""
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
