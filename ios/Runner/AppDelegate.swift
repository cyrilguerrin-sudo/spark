import Flutter
import UIKit
import FamilyControls
import DeviceActivity
import ManagedSettings
import SwiftUI

private let kAppGroup = "group.com.cyrilguerrin.spark"
private let kChannel  = "com.example.spark/familycontrols"

// Shared UserDefaults keys — must stay in sync with all Swift extensions
enum UDKey {
    static let sessionEndTime     = "KEY_SESSION_END_TIME"
    static let sessionNetworkId   = "KEY_SESSION_NETWORK_ID"
    static let sessionStartTime   = "KEY_SESSION_START_TIME"
    static let sessionPausedAt    = "KEY_SESSION_PAUSED_AT"
    static let sessionRemainingMs = "KEY_SESSION_REMAINING_MS"
    static let monitoredTokens    = "KEY_MONITORED_TOKENS"
    static let blockUntil         = "KEY_BLOCK_UNTIL"
    static let blockNetworkId     = "KEY_BLOCK_NETWORK_ID"
    static let focusActive        = "KEY_FOCUS_ACTIVE"
    static let focusTokens        = "KEY_FOCUS_TOKENS"
    static let focusGoal          = "KEY_FOCUS_GOAL"
    static let sessionHistory     = "KEY_SESSION_HISTORY"
    // Written by DeviceActivityMonitor extension, consumed here on next foreground
    static let sessionCancelledPending = "KEY_SESSION_CANCELLED_PENDING"
    // Written by SparkAppIntent (AppIntentsExtension), consumed here on next foreground
    static let pendingNetworkInterception = "KEY_PENDING_NETWORK_INTERCEPTION"
}

@main
@available(iOS 15.0, *)
@objc class AppDelegate: FlutterAppDelegate {

    private var channel: FlutterMethodChannel?
    private let store = ManagedSettingsStore()
    // Kept alive while FamilyActivityPicker is on screen
    private var pickerSession: PickerSession?

    var sharedUD: UserDefaults? { UserDefaults(suiteName: kAppGroup) }

    // MARK: - Application lifecycle

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        guard let controller = window?.rootViewController as? FlutterViewController else {
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }

        channel = FlutterMethodChannel(name: kChannel, binaryMessenger: controller.binaryMessenger)
        channel?.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // Check for events written by extensions while the main app was suspended
    override func applicationDidBecomeActive(_ application: UIApplication) {
        super.applicationDidBecomeActive(application)
        handleSessionResumeIfNeeded()
        dispatchPendingExtensionEvents()
    }

    // Spark is going to background (user returned to their session app or switched away).
    // If a session is active: save the pause timestamp and arm the 45-second watchdog.
    // DeviceActivityMonitorExtension.intervalDidEnd(.pause45) will call silentReset if
    // the user doesn't return in time.
    override func applicationWillResignActive(_ application: UIApplication) {
        super.applicationWillResignActive(application)
        handleSessionPauseIfNeeded()
    }

    // MARK: - URL scheme spark://

    override func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        guard url.scheme == "spark" else { return false }

        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)

        switch url.host {
        case "app-intercepted":
            let networkId = comps?.queryItems?.first(where: { $0.name == "network" })?.value ?? ""
            channel?.invokeMethod("onAppIntercepted", arguments: ["networkId": networkId])
        case "session-cancelled":
            channel?.invokeMethod("onSessionCancelled", arguments: nil)
        default:
            break
        }
        return true
    }

    // MARK: - MethodChannel dispatch

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "requestAuthorization":  requestAuthorization(result: result)
        case "checkAuthorization":    checkAuthorization(result: result)
        case "setMonitoredNetworks":  setMonitoredNetworks(call: call, result: result)
        case "setSessionEndTime":     setSessionEndTime(call: call, result: result)
        case "clearSessionEndTime":   clearSessionEndTime(result: result)
        case "setFocusMode":          setFocusMode(call: call, result: result)
        case "getSessionHistory":     getSessionHistory(result: result)
        default:                      result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - requestAuthorization

    private func requestAuthorization(result: @escaping FlutterResult) {
        guard #available(iOS 16.0, *) else {
            result(false)
            return
        }
        Task {
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                await MainActor.run { result(true) }
            } catch {
                await MainActor.run {
                    result(FlutterError(code: "AUTH_FAILED",
                                        message: error.localizedDescription,
                                        details: nil))
                }
            }
        }
    }

    // MARK: - checkAuthorization

    private func checkAuthorization(result: FlutterResult) {
        result(AuthorizationCenter.shared.authorizationStatus == .approved)
    }

    // MARK: - setMonitoredNetworks
    // If Flutter sends pre-encoded FamilyActivitySelection bytes, persist them directly.
    // Otherwise present the native FamilyActivityPicker so the user can select apps.
    private func setMonitoredNetworks(call: FlutterMethodCall, result: @escaping FlutterResult) {
        if let args = call.arguments as? [String: Any],
           let bytes = (args["tokensData"] as? FlutterStandardTypedData)?.data {
            sharedUD?.set(bytes, forKey: UDKey.monitoredTokens)
            result(true)
            return
        }

        guard let rootVC = window?.rootViewController else {
            result(FlutterError(code: "NO_ROOT_VC", message: "No root view controller", details: nil))
            return
        }

        let session = PickerSession()
        self.pickerSession = session

        var dismissAction: (() -> Void)?
        let model = session.model

        let pickerView = FamilyPickerView(model: model) {
            dismissAction?()
        }

        let vc = UIHostingController(rootView: pickerView)
        vc.modalPresentationStyle = .formSheet
        session.hostingVC = vc

        dismissAction = { [weak vc, weak self] in
            if let data = try? PropertyListEncoder().encode(model.selection) {
                self?.sharedUD?.set(data, forKey: UDKey.monitoredTokens)
            }
            vc?.dismiss(animated: true) {
                self?.pickerSession = nil
                result(true)
            }
        }

        rootVC.present(vc, animated: true)
    }

    // MARK: - setSessionEndTime

    private func setSessionEndTime(call: FlutterMethodCall, result: FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let endTime   = args["endTime"]   as? Double,
              let networkId = args["networkId"] as? String,
              let startTime = args["startTime"] as? Double
        else {
            result(FlutterError(code: "INVALID_ARGS",
                                message: "Requires endTime (Double), networkId (String), startTime (Double)",
                                details: nil))
            return
        }

        let ud = sharedUD
        ud?.set(endTime,   forKey: UDKey.sessionEndTime)
        ud?.set(networkId, forKey: UDKey.sessionNetworkId)
        ud?.set(startTime, forKey: UDKey.sessionStartTime)
        ud?.set(0.0,       forKey: UDKey.sessionPausedAt)
        ud?.set(0.0,       forKey: UDKey.sessionRemainingMs)

        // Unshield so the user can enter the app
        store.shield.applications = nil

        // Arm the DeviceActivity schedule so the monitor extension fires when time is up
        scheduleSessionTimer(endTime: endTime)

        result(true)
    }

    // MARK: - clearSessionEndTime

    private func clearSessionEndTime(result: FlutterResult) {
        let ud = sharedUD
        ud?.set(0.0, forKey: UDKey.sessionEndTime)
        ud?.set(0.0, forKey: UDKey.sessionStartTime)
        ud?.set(0.0, forKey: UDKey.sessionPausedAt)
        ud?.set(0.0, forKey: UDKey.sessionRemainingMs)
        ud?.removeObject(forKey: UDKey.sessionNetworkId)

        DeviceActivityCenter().stopMonitoring([DeviceActivityName("spark.session")])
        applyMonitoredShield()

        result(true)
    }

    // MARK: - setFocusMode

    private func setFocusMode(call: FlutterMethodCall, result: FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let active = args["active"] as? Bool
        else {
            result(FlutterError(code: "INVALID_ARGS", message: "Requires active (Bool)", details: nil))
            return
        }

        let ud = sharedUD
        ud?.set(active, forKey: UDKey.focusActive)

        if active {
            // Store the user's focus goal for the Shield subtitle
            if let goal = args["goal"] as? String {
                ud?.set(goal, forKey: UDKey.focusGoal)
            }
            // Prefer explicitly provided tokens, fall back to monitored tokens
            let tokenBytes = (args["tokensData"] as? FlutterStandardTypedData)?.data
                ?? ud?.data(forKey: UDKey.monitoredTokens)
            if let data = tokenBytes {
                ud?.set(data, forKey: UDKey.focusTokens)
                shieldApps(from: data)
            }
        } else {
            ud?.removeObject(forKey: UDKey.focusTokens)
            ud?.removeObject(forKey: UDKey.focusGoal)
            store.shield.applications = nil
        }

        result(true)
    }

    // MARK: - getSessionHistory

    private func getSessionHistory(result: FlutterResult) {
        result(sharedUD?.string(forKey: UDKey.sessionHistory) ?? "[]")
    }

    // MARK: - Pause / resume helpers

    // Called from applicationWillResignActive.
    // Writes KEY_SESSION_PAUSED_AT and KEY_SESSION_REMAINING_MS, then starts spark.pause45.
    private func handleSessionPauseIfNeeded() {
        guard let ud = sharedUD else { return }
        let endTime = ud.double(forKey: UDKey.sessionEndTime)
        let now = Date().timeIntervalSince1970
        // Only act if there's an active, unexpired session
        guard endTime > 0, now < endTime else { return }
        // Don't double-pause
        guard ud.double(forKey: UDKey.sessionPausedAt) == 0 else { return }

        let remainingMs = (endTime - now) * 1000
        ud.set(now,         forKey: UDKey.sessionPausedAt)
        ud.set(remainingMs, forKey: UDKey.sessionRemainingMs)

        schedulePause45()
    }

    // Called from applicationDidBecomeActive.
    // If the user returned within 45s, cancels the watchdog and reschedules the session
    // timer with the remaining time. If 45s already elapsed silentReset will have fired.
    private func handleSessionResumeIfNeeded() {
        guard let ud = sharedUD else { return }
        let pausedAt     = ud.double(forKey: UDKey.sessionPausedAt)
        let remainingMs  = ud.double(forKey: UDKey.sessionRemainingMs)
        let now          = Date().timeIntervalSince1970

        guard pausedAt > 0, remainingMs > 0 else { return }

        let elapsed = now - pausedAt

        if elapsed < 45 {
            // User is back in time — resume session with remaining duration
            DeviceActivityCenter().stopMonitoring([DeviceActivityName("spark.pause45")])
            ud.set(0.0, forKey: UDKey.sessionPausedAt)
            let newEndTime = now + (remainingMs / 1000)
            ud.set(newEndTime, forKey: UDKey.sessionEndTime)
            scheduleSessionTimer(endTime: newEndTime)
        }
        // If elapsed >= 45s the DeviceActivityMonitorExtension silentReset has already
        // fired or is about to — don't interfere.
    }

    private func schedulePause45() {
        let center = DeviceActivityCenter()
        let name   = DeviceActivityName("spark.pause45")
        center.stopMonitoring([name])

        let cal        = Calendar.current
        let startComps = cal.dateComponents([.era, .year, .month, .day, .hour, .minute, .second],
                                            from: Date().addingTimeInterval(1))
        let endComps   = cal.dateComponents([.era, .year, .month, .day, .hour, .minute, .second],
                                            from: Date().addingTimeInterval(46)) // 1s buffer + 45s

        let schedule = DeviceActivitySchedule(intervalStart: startComps, intervalEnd: endComps, repeats: false)
        try? center.startMonitoring(name, during: schedule)
    }

    // MARK: - Pending extension event dispatch

    private func dispatchPendingExtensionEvents() {
        guard let ud = sharedUD else { return }
        if ud.bool(forKey: UDKey.sessionCancelledPending) {
            ud.removeObject(forKey: UDKey.sessionCancelledPending)
            channel?.invokeMethod("onSessionCancelled", arguments: nil)
        }
        if let networkId = ud.string(forKey: UDKey.pendingNetworkInterception) {
            ud.removeObject(forKey: UDKey.pendingNetworkInterception)
            channel?.invokeMethod("onAppIntercepted", arguments: ["networkId": networkId])
        }
    }

    // MARK: - DeviceActivity helpers

    private func scheduleSessionTimer(endTime: Double) {
        let center = DeviceActivityCenter()
        let name   = DeviceActivityName("spark.session")
        center.stopMonitoring([name])

        let end = Date(timeIntervalSince1970: endTime)
        guard end > Date() else { return }

        let cal        = Calendar.current
        let startComps = cal.dateComponents([.era, .year, .month, .day, .hour, .minute, .second],
                                            from: Date().addingTimeInterval(1))
        let endComps   = cal.dateComponents([.era, .year, .month, .day, .hour, .minute, .second],
                                            from: end)

        let schedule = DeviceActivitySchedule(
            intervalStart: startComps,
            intervalEnd:   endComps,
            repeats:       false
        )

        do {
            try center.startMonitoring(name, during: schedule)
        } catch {
            // Non-fatal — the DeviceActivityMonitor extension polls KEY_SESSION_END_TIME
            // independently and will still reblock when the time comes.
        }
    }

    private func applyMonitoredShield() {
        guard let data = sharedUD?.data(forKey: UDKey.monitoredTokens) else { return }
        shieldApps(from: data)
    }

    func shieldApps(from data: Data) {
        guard let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return }
        let tokens = selection.applicationTokens
        store.shield.applications = tokens.isEmpty ? nil : tokens
    }
}

// MARK: - FamilyActivityPicker helpers

// Keeps the picker model alive while the UIHostingController is on screen
@available(iOS 15.0, *)
private class PickerSession {
    let model = FamilyPickerModel()
    weak var hostingVC: UIViewController?
}

@available(iOS 15.0, *)
private class FamilyPickerModel: ObservableObject {
    @Published var selection = FamilyActivitySelection()
}

@available(iOS 15.0, *)
private struct FamilyPickerView: View {
    @ObservedObject var model: FamilyPickerModel
    let onDone: () -> Void

    var body: some View {
        NavigationView {
            FamilyActivityPicker(selection: $model.selection)
                .navigationTitle("Apps à surveiller")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("OK", action: onDone)
                    }
                }
        }
        .navigationViewStyle(.stack)
    }
}
