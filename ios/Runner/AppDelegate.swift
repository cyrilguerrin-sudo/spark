import Flutter
import UIKit
import FamilyControls
import DeviceActivity
import ManagedSettings
import SwiftUI
import Combine
import os

private let kChannel = "com.example.spark/familycontrols"
private let logger   = Logger(subsystem: "com.cyrilguerrin.spark", category: "FamilyControls")

// File-based App Group storage — replaces UserDefaults(suiteName:) which triggers
// kCFPreferencesAnyUser in ManagedSettings extension processes, causing cfprefsd
// detachment and silent data loss on iOS 16+.
private enum AppGroupStore {
    static var fileURL: URL? {
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
        var d = read(); if let v = value { d[key] = v } else { d.removeValue(forKey: key) }; write(d)
    }
    static func remove(_ key: String) { set(key, nil) }
}

// Shared storage keys — must stay in sync with all Swift extensions
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
    // Written by SparkAppIntent (legacy, kept for migration of stale data)
    static let pendingNetworkInterception = "KEY_PENDING_NETWORK_INTERCEPTION"
    // Per-network tokens (3-picker setup)
    static let tokenInstagram       = "KEY_TOKEN_INSTAGRAM"
    static let tokenTiktok          = "KEY_TOKEN_TIKTOK"
    static let tokenYoutube         = "KEY_TOKEN_YOUTUBE"
}

@main
@available(iOS 15.0, *)
@objc class AppDelegate: FlutterAppDelegate {

    private var channel: FlutterMethodChannel?
    private let store = ManagedSettingsStore()
    // Kept alive while FamilyActivityPicker is on screen
    private var pickerContainer: PickerContainer?


    // MARK: - Application lifecycle

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        // Diagnose App Group file container accessibility.
        if AppGroupStore.fileURL == nil {
            logger.error("[AppDelegate] CRITICAL — App Group container URL nil. group.com.cyrilguerrin.spark not accessible.")
        } else {
            logger.debug("[AppDelegate] App Group file container OK: \(AppGroupStore.fileURL!.path, privacy: .public)")
        }

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
        logSharedUDState()
        handleSessionResumeIfNeeded()
        dispatchPendingExtensionEvents()
    }

    private func logSharedUDState() {
        let s       = AppGroupStore.read()
        let tokens  = s[UDKey.monitoredTokens] as? Data
        let sessEnd = s[UDKey.sessionEndTime]  as? Double ?? 0.0
        let focus   = s[UDKey.focusActive]     as? Bool   ?? false
        let tokenDesc = tokens.map { "\($0.count)B" } ?? "nil"
        logger.debug("[AppDelegate] AppGroup state — monitoredTokens:\(tokenDesc, privacy: .public) sessionEnd:\(sessEnd) focusActive:\(focus)")
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
        case "setMonitoredNetwork":   setMonitoredNetwork(call: call, result: result)
        case "getConfiguredNetworks": getConfiguredNetworks(result: result)
        case "setSessionEndTime":       setSessionEndTime(call: call, result: result)
        case "clearSessionEndTime":     clearSessionEndTime(result: result)
        case "setFocusMode":            setFocusMode(call: call, result: result)
        case "getSessionHistory":       getSessionHistory(result: result)
        case "getMonitoredAppsCount":   getMonitoredAppsCount(result: result)
        case "openScreenTimeSettings":  openScreenTimeSettings(result: result)
        default:                        result(FlutterMethodNotImplemented)
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

    // MARK: - setMonitoredNetwork
    // Presents FamilyActivityPicker for one specific network (instagram|tiktok|youtube)
    // using the official .familyActivityPicker modifier + Combine sink pattern.
    // The system updates the selection binding while XPC is still alive, so
    // PropertyListEncoder (which requires valid Codable state) works reliably.
    private func setMonitoredNetwork(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard #available(iOS 16.0, *) else { result(false); return }

        guard let args    = call.arguments as? [String: Any],
              let network = args["network"] as? String,
              ["instagram", "tiktok", "youtube"].contains(network)
        else {
            result(FlutterError(code: "INVALID_ARGS",
                                message: "Requires network: instagram|tiktok|youtube",
                                details: nil))
            return
        }

        guard let rootVC = window?.rootViewController else {
            result(FlutterError(code: "NO_ROOT_VC", message: "No root view controller", details: nil))
            return
        }

        let tokenKey: String
        switch network {
        case "instagram": tokenKey = UDKey.tokenInstagram
        case "tiktok":    tokenKey = UDKey.tokenTiktok
        default:          tokenKey = UDKey.tokenYoutube
        }

        let model     = PickerModel()
        let container = PickerContainer(model: model)
        self.pickerContainer = container

        // Combine sink: fires when the system writes to the binding — XPC still alive.
        // dropFirst() skips the initial empty FamilyActivitySelection().
        model.$activitySelection
            .dropFirst()
            .sink { selection in
                logger.debug("[Spark] Combine sink: \(selection.applicationTokens.count) tokens for \(network, privacy: .public)")
                if let data = try? PropertyListEncoder().encode(selection) {
                    AppGroupStore.set(tokenKey, data)
                    logger.debug("[Spark] AppGroupStore write OK — key=\(tokenKey, privacy: .public) \(data.count)B")
                } else {
                    logger.error("[Spark] PropertyListEncoder FAILED for \(network, privacy: .public)")
                }
            }
            .store(in: &model.cancellables)

        let containerView = PickerContainerView(model: model) { [weak self, weak rootVC] in
            logger.debug("[Spark] picker dismissed for \(network, privacy: .public)")
            self?.rebuildAndApplyMonitoredTokens()
            result(true)
            self?.pickerContainer = nil
            rootVC?.presentedViewController?.dismiss(animated: false)
        }

        let vc = UIHostingController(rootView: containerView)
        vc.view.backgroundColor = .clear
        vc.modalPresentationStyle = .overFullScreen
        container.hostingVC = vc
        rootVC.present(vc, animated: false)
    }

    // Unions all per-network tokens, writes KEY_MONITORED_TOKENS for extensions,
    // and immediately applies the shield.
    private func rebuildAndApplyMonitoredTokens() {
        guard #available(iOS 16.0, *) else { return }
        let d = AppGroupStore.read()
        var allTokens = Set<ApplicationToken>()

        for key in [UDKey.tokenInstagram, UDKey.tokenTiktok, UDKey.tokenYoutube] {
            guard let data = d[key] as? Data,
                  let sel  = decodePerNetworkSelection(from: data)
            else { continue }
            allTokens.formUnion(sel.applicationTokens)
        }

        guard !allTokens.isEmpty else {
            store.shield.applications = nil
            AppGroupStore.remove(UDKey.monitoredTokens)
            logger.debug("[AppDelegate] rebuildAndApplyMonitoredTokens: no tokens configured")
            return
        }

        var combined = FamilyActivitySelection()
        combined.applicationTokens = allTokens
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: combined,
                                                        requiringSecureCoding: true) {
            AppGroupStore.set(UDKey.monitoredTokens, data)
        }

        store.shield.applications = allTokens
        logger.debug("[AppDelegate] rebuildAndApplyMonitoredTokens: shielding \(allTokens.count) apps")
    }

    // MARK: - getConfiguredNetworks

    private func getConfiguredNetworks(result: FlutterResult) {
        let d = AppGroupStore.read()
        var networks: [String] = []
        if d[UDKey.tokenInstagram] != nil { networks.append("instagram") }
        if d[UDKey.tokenTiktok]    != nil { networks.append("tiktok") }
        if d[UDKey.tokenYoutube]   != nil { networks.append("youtube") }
        result(networks)
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

        var d = AppGroupStore.read()
        d[UDKey.sessionEndTime]     = endTime
        d[UDKey.sessionNetworkId]   = networkId
        d[UDKey.sessionStartTime]   = startTime
        d[UDKey.sessionPausedAt]    = 0.0
        d[UDKey.sessionRemainingMs] = 0.0
        AppGroupStore.write(d)

        // Lift shield selectively for the session's network only
        liftShieldForNetwork(networkId: networkId)

        // Arm the DeviceActivity schedule so the monitor extension fires when time is up
        scheduleSessionTimer(endTime: endTime)

        result(true)
    }

    // Removes the shield on the session's network token while keeping other monitored
    // apps shielded. Falls back to lifting all shields if tokens can't be resolved.
    private func liftShieldForNetwork(networkId: String) {
        let d = AppGroupStore.read()
        let tokenKey: String
        switch networkId {
        case "instagram": tokenKey = UDKey.tokenInstagram
        case "tiktok":    tokenKey = UDKey.tokenTiktok
        case "youtube":   tokenKey = UDKey.tokenYoutube
        default:          store.shield.applications = nil; return
        }

        guard let sessionData = d[tokenKey] as? Data,
              let sessionSel  = decodePerNetworkSelection(from: sessionData)
        else { store.shield.applications = nil; return }

        let sessionTokens = sessionSel.applicationTokens

        guard let allData = d[UDKey.monitoredTokens] as? Data,
              let allSel  = decodeSelection(from: allData),
              !allSel.applicationTokens.isEmpty
        else { store.shield.applications = nil; return }

        let remaining = allSel.applicationTokens.subtracting(sessionTokens)
        store.shield.applications = remaining.isEmpty ? nil : remaining
        logger.debug("[AppDelegate] liftShieldForNetwork: \(networkId, privacy: .public) session started, \(remaining.count) apps still shielded")
    }

    // MARK: - clearSessionEndTime

    private func clearSessionEndTime(result: FlutterResult) {
        var d = AppGroupStore.read()
        d[UDKey.sessionEndTime]     = 0.0
        d[UDKey.sessionStartTime]   = 0.0
        d[UDKey.sessionPausedAt]    = 0.0
        d[UDKey.sessionRemainingMs] = 0.0
        d.removeValue(forKey: UDKey.sessionNetworkId)
        AppGroupStore.write(d)

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

        var d = AppGroupStore.read()
        d[UDKey.focusActive] = active

        if active {
            if let goal = args["goal"] as? String {
                d[UDKey.focusGoal] = goal
            }
            let tokenBytes = (args["tokensData"] as? FlutterStandardTypedData)?.data
                ?? d[UDKey.monitoredTokens] as? Data
            if let data = tokenBytes {
                d[UDKey.focusTokens] = data
                AppGroupStore.write(d)
                shieldApps(from: data)
            } else {
                AppGroupStore.write(d)
            }
        } else {
            d.removeValue(forKey: UDKey.focusTokens)
            d.removeValue(forKey: UDKey.focusGoal)
            AppGroupStore.write(d)
            store.shield.applications = nil
        }

        result(true)
    }

    // MARK: - getSessionHistory

    private func getSessionHistory(result: FlutterResult) {
        result(AppGroupStore.read()[UDKey.sessionHistory] as? String ?? "[]")
    }

    // MARK: - FamilyActivitySelection decode helpers

    // Per-network tokens are encoded with PropertyListEncoder (new path).
    // Falls back to NSKeyedUnarchiver for any legacy data from the old encoding.
    private func decodePerNetworkSelection(from data: Data) -> FamilyActivitySelection? {
        if let sel = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data) {
            return sel
        }
        return decodeSelection(from: data)
    }

    // NSKeyedUnarchiver decoder — used for KEY_MONITORED_TOKENS (combined set read by extensions)
    // and as fallback for legacy per-network tokens.
    private func decodeSelection(from data: Data) -> FamilyActivitySelection? {
        guard let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        unarchiver.requiresSecureCoding = false
        let obj = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey)
        unarchiver.finishDecoding()
        return obj as? FamilyActivitySelection
    }

    // MARK: - getMonitoredAppsCount

    private func getMonitoredAppsCount(result: FlutterResult) {
        guard let data = AppGroupStore.read()[UDKey.monitoredTokens] as? Data,
              let selection = decodeSelection(from: data)
        else { result(0); return }
        result(selection.applicationTokens.count)
    }

    // MARK: - openScreenTimeSettings

    private func openScreenTimeSettings(result: @escaping FlutterResult) {
        // Try the Screen Time deep link first; fall back to the app's own Settings page.
        if let url = URL(string: "App-Prefs:SCREENTIME"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url) { _ in result(true) }
        } else if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url) { _ in result(true) }
        } else {
            result(true)
        }
    }

    // MARK: - Pause / resume helpers

    // Called from applicationWillResignActive.
    // Writes KEY_SESSION_PAUSED_AT and KEY_SESSION_REMAINING_MS, then starts spark.pause45.
    private func handleSessionPauseIfNeeded() {
        var d = AppGroupStore.read()
        let endTime = d[UDKey.sessionEndTime] as? Double ?? 0.0
        let now = Date().timeIntervalSince1970
        guard endTime > 0, now < endTime else { return }
        guard (d[UDKey.sessionPausedAt] as? Double ?? 0.0) == 0 else { return }

        let remainingMs = (endTime - now) * 1000
        d[UDKey.sessionPausedAt]    = now
        d[UDKey.sessionRemainingMs] = remainingMs
        AppGroupStore.write(d)

        schedulePause45()
    }

    // Called from applicationDidBecomeActive.
    // If the user returned within 45s, cancels the watchdog and reschedules the session
    // timer with the remaining time. If 45s already elapsed silentReset will have fired.
    private func handleSessionResumeIfNeeded() {
        var d = AppGroupStore.read()
        let pausedAt    = d[UDKey.sessionPausedAt]    as? Double ?? 0.0
        let remainingMs = d[UDKey.sessionRemainingMs] as? Double ?? 0.0
        let now         = Date().timeIntervalSince1970

        guard pausedAt > 0, remainingMs > 0 else { return }

        let elapsed = now - pausedAt

        if elapsed < 45 {
            DeviceActivityCenter().stopMonitoring([DeviceActivityName("spark.pause45")])
            let newEndTime = now + (remainingMs / 1000)
            d[UDKey.sessionPausedAt]  = 0.0
            d[UDKey.sessionEndTime]   = newEndTime
            AppGroupStore.write(d)
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
        var d = AppGroupStore.read()
        var dirty = false

        if d[UDKey.sessionCancelledPending] as? Bool == true {
            d.removeValue(forKey: UDKey.sessionCancelledPending)
            dirty = true
            channel?.invokeMethod("onSessionCancelled", arguments: nil)
        }

        // Legacy SparkAppIntent path — consume any stale data from before this update
        if let networkId = d[UDKey.pendingNetworkInterception] as? String {
            d.removeValue(forKey: UDKey.pendingNetworkInterception)
            dirty = true
            channel?.invokeMethod("onAppIntercepted", arguments: ["networkId": networkId])
        }

        if dirty { AppGroupStore.write(d) }
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
        guard let data = AppGroupStore.read()[UDKey.monitoredTokens] as? Data else { return }
        shieldApps(from: data)
    }

    func shieldApps(from data: Data) {
        guard let selection = decodeSelection(from: data) else {
            logger.error("[AppDelegate] ERROR — FamilyActivitySelection decode failed (\(data.count) bytes)")
            return
        }
        let tokens = selection.applicationTokens
        logger.debug("[AppDelegate] shieldApps: \(tokens.count) app tokens")
        store.shield.applications = tokens.isEmpty ? nil : tokens
    }
}

// MARK: - FamilyActivityPicker helpers (official binding pattern)

@available(iOS 16.0, *)
private class PickerModel: ObservableObject {
    @Published var activitySelection = FamilyActivitySelection()
    var cancellables = Set<AnyCancellable>()
}

@available(iOS 16.0, *)
private class PickerContainer {
    let model: PickerModel
    weak var hostingVC: UIViewController?
    init(model: PickerModel) { self.model = model }
}

// Transparent host view that presents the system picker via .familyActivityPicker modifier.
// Using the modifier (not FamilyActivityPicker as a child view) lets the system manage
// the XPC lifecycle: the selection binding is updated while XPC is still alive, so
// PropertyListEncoder succeeds in the Combine sink.
@available(iOS 16.0, *)
private struct PickerContainerView: View {
    @ObservedObject var model: PickerModel
    @State private var isPresented = false
    let onDismiss: () -> Void

    var body: some View {
        Color.clear
            .familyActivityPicker(isPresented: $isPresented, selection: $model.activitySelection)
            .onAppear {
                DispatchQueue.main.async { isPresented = true }
            }
            .onChange(of: isPresented) { presented in
                if !presented { onDismiss() }
            }
    }
}
