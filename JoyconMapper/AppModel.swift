import AppKit
import Combine
import Foundation
import JoyconHID
import JoyconMapping
import MacInput
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {
    struct Configuration {
        var userDefaults: UserDefaults
        var isHardwareEnabled: Bool
        var accessibilityTrustedOverride: Bool?

        nonisolated static var live: Configuration {
            Configuration(
                userDefaults: .standard,
                isHardwareEnabled: true,
                accessibilityTrustedOverride: nil
            )
        }

        nonisolated static func testing(
            suiteName: String = "JoyconMapper.Tests.\(UUID().uuidString)",
            accessibilityTrusted: Bool = true
        ) -> Configuration {
            let defaults = UserDefaults(suiteName: suiteName) ?? .standard
            defaults.removePersistentDomain(forName: suiteName)
            return Configuration(
                userDefaults: defaults,
                isHardwareEnabled: false,
                accessibilityTrustedOverride: accessibilityTrusted
            )
        }
    }

    struct ProfileOption: Identifiable, Hashable, Codable {
        let id: String
        var name: String
        var nameKey: String?
        var isBuiltIn: Bool
    }

    struct SettingsSnapshot: Codable, Equatable {
        var formatVersion: Int
        var exportedAt: Date
        var activeProfileID: String
        var profileOptions: [ProfileOption]
        var profiles: [String: MappingProfile]
        var isStickMouseEnabled: Bool
        var mouseSpeed: Double
        var mouseDeadzone: Double
        var mouseAcceleration: Double
        var isMouseYInverted: Bool
    }

    static let defaultProfileOptions: [ProfileOption] = [
        ProfileOption(id: "default", name: "Default", nameKey: "profile.default", isBuiltIn: true),
        ProfileOption(id: "browsing", name: "Browsing", nameKey: "profile.browsing", isBuiltIn: true),
        ProfileOption(id: "meeting", name: "Meeting", nameKey: "profile.meeting", isBuiltIn: true)
    ]

    @Published var isMapperEnabled = true {
        didSet {
            guard oldValue != isMapperEnabled, !isMapperEnabled else { return }
            releaseAllActiveHolds()
        }
    }
    @Published var isStickMouseEnabled = true {
        didSet { settingsStore.setStickMouseEnabled(isStickMouseEnabled) }
    }
    @Published var mouseSpeed: Double = 4200 {
        didSet { settingsStore.setMouseSpeed(mouseSpeed) }
    }
    @Published var mouseDeadzone: Double = 0.16 {
        didSet { settingsStore.setMouseDeadzone(mouseDeadzone) }
    }
    @Published var mouseAcceleration: Double = 1.45 {
        didSet { settingsStore.setMouseAcceleration(mouseAcceleration) }
    }
    @Published var isMouseYInverted = false {
        didSet { settingsStore.setMouseYInverted(isMouseYInverted) }
    }
    @Published var isOnboardingCompleted = false {
        didSet { settingsStore.setOnboardingCompleted(isOnboardingCompleted) }
    }
    @Published private(set) var profileOptions = AppModel.defaultProfileOptions
    @Published var activeProfileID = "default" {
        didSet {
            guard oldValue != activeProfileID else { return }
            guard !isLoadingProfileState else { return }
            releaseAllActiveHolds()
            profiles[oldValue] = profile
            settingsStore.setActiveProfileID(activeProfileID)
            profile = profiles[activeProfileID] ?? .joyConLeftDefault
            settingsStore.saveProfiles(profiles)
        }
    }
    @Published private(set) var devices: [JoyconDevice] = []
    @Published private(set) var recentInputs: [ControllerInput] = []
    @Published private(set) var pressedTriggerIDs: Set<String> = []
    @Published private(set) var visibleStickX = 0.0
    @Published private(set) var visibleStickY = 0.0
    @Published private(set) var lastError: String?
    @Published private(set) var isRunning = false
    @Published var isShowingAbout = false
    @Published private(set) var isLaunchAtLoginEnabled = false
    @Published private(set) var launchAtLoginError: String?
    @Published private(set) var isAccessibilityTrusted = false
    @Published var profile = MappingProfile() {
        didSet {
            guard !isLoadingProfileState else { return }
            releaseAllActiveHolds()
            profiles[activeProfileID] = profile
            settingsStore.saveProfiles(profiles)
        }
    }

    private let hidClient = JoyconHIDClient()
    private let inputSender: any InputSending
    private let configuration: Configuration
    private var activeActionTriggers: Set<String> = []
    private var activeTriggerByControlID: [String: String] = [:]
    private var activeActionByTrigger: [String: MappingAction] = [:]
    private var activeMouseMoves: [String: (deltaX: Double, deltaY: Double)] = [:]
    private var activeScrolls: [String: (deltaX: Double, deltaY: Double)] = [:]
    private var stickX = 0.0
    private var stickY = 0.0
    private var profiles: [String: MappingProfile] = [:]
    private var isLoadingProfileState = false
    private var mouseTimer: Timer?
    private var deviceRefreshTimer: Timer?
    private var accessibilityRefreshTimer: Timer?
    private var panicKeyMonitors: [Any] = []
    private let settingsStore: SettingsStore

    init(configuration: Configuration = .live, inputSender: (any InputSending)? = nil) {
        self.configuration = configuration
        self.settingsStore = SettingsStore(userDefaults: configuration.userDefaults)
        self.inputSender = inputSender ?? MacInputSender()
        self.isAccessibilityTrusted = configuration.accessibilityTrustedOverride ?? self.inputSender.isAccessibilityTrusted
        loadMouseSettings()
        loadProfile()
        refreshLaunchAtLoginStatus()
        hidClient.onDevicesChanged = { [weak self] devices in
            Task { @MainActor in
                self?.handleDevicesChanged(devices)
            }
        }
        hidClient.onInput = { [weak self] input in
            Task { @MainActor in
                self?.handle(input)
            }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleSystemDidWake()
            }
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleAppWillTerminate()
            }
        }
    }

    var shouldShowAccessibilityPrompt: Bool {
        !isAccessibilityTrusted
    }

    func refreshAccessibilityTrust() {
        let trusted = configuration.accessibilityTrustedOverride ?? inputSender.isAccessibilityTrusted
        if trusted != isAccessibilityTrusted {
            isAccessibilityTrusted = trusted
        }
    }

    func start() {
        guard configuration.isHardwareEnabled else {
            isRunning = true
            lastError = nil
            return
        }

        do {
            try hidClient.start()
            isRunning = true
            lastError = nil
            startMouseTimer()
            startDeviceRefreshTimer()
            startAccessibilityRefreshTimer()
            startPanicHotkeyMonitor()
            requestAccessibilityPermissionIfNeeded()
        } catch {
            lastError = error.localizedDescription
            isRunning = false
        }
    }

    func stop() {
        guard configuration.isHardwareEnabled else {
            releaseAllActiveHolds()
            pressedTriggerIDs.removeAll()
            isRunning = false
            return
        }

        hidClient.stop()
        stopPanicHotkeyMonitor()
        releaseAllActiveHolds()
        pressedTriggerIDs.removeAll()
        mouseTimer?.invalidate()
        mouseTimer = nil
        deviceRefreshTimer?.invalidate()
        deviceRefreshTimer = nil
        accessibilityRefreshTimer?.invalidate()
        accessibilityRefreshTimer = nil
        isRunning = false
    }

    func reconnect() {
        stop()
        start()
    }

    /// Re-establishes the HID connection after the machine wakes from sleep,
    /// where the underlying device handles are frequently invalidated.
    func handleSystemDidWake() {
        guard isRunning else { return }
        reconnect()
    }

    /// Ensures any held keys/modifiers/mouse buttons are released before the app
    /// exits. Menu Quit and Cmd-Q call `NSApplication.terminate` directly, which
    /// would otherwise leave a held mouseHold/modifierHold/pushToTalk stuck
    /// system-wide (notably a left-button drag).
    func handleAppWillTerminate() {
        stop()
    }

    /// Emergency "panic" disable that turns the mapper off and, via the
    /// `isMapperEnabled` didSet, releases every held key/modifier/mouse button.
    func panicDisable() {
        isMapperEnabled = false
    }

    func requestAccessibilityPermission() {
        guard configuration.accessibilityTrustedOverride == nil else {
            refreshAccessibilityTrust()
            return
        }

        inputSender.requestAccessibilityTrust()
        settingsStore.setDidRequestAccessibility(true)
        refreshAccessibilityTrust()
    }

    func requestAccessibilityPermissionIfNeeded() {
        guard !isAccessibilityTrusted else { return }
        guard !settingsStore.didRequestAccessibility else { return }
        requestAccessibilityPermission()
    }

    func refreshLaunchAtLoginStatus() {
        isLaunchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLoginEnabled(_ isEnabled: Bool) {
        do {
            if isEnabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginError = nil
            refreshLaunchAtLoginStatus()
        } catch {
            launchAtLoginError = error.localizedDescription
            refreshLaunchAtLoginStatus()
        }
    }

    func assign(_ action: MappingAction, to triggerID: String) {
        profile.assign(action, toTriggerID: triggerID)
    }

    func clearAssignment(for triggerID: String) {
        profile.assignments.removeValue(forKey: triggerID)
    }

    func clearRecentInputs() {
        recentInputs.removeAll()
    }

    func createProfile(named name: String) {
        let trimmedName = normalizedProfileName(name, fallback: "Profile")
        let id = uniqueProfileID()
        profileOptions.append(ProfileOption(id: id, name: trimmedName, nameKey: nil, isBuiltIn: false))
        profiles[id] = .joyConLeftDefault
        settingsStore.saveProfileOptions(profileOptions)
        settingsStore.saveProfiles(profiles)
        activeProfileID = id
    }

    func duplicateActiveProfile() {
        let sourceName = profileDisplayName(for: activeProfileID)
        let id = uniqueProfileID()
        profileOptions.append(ProfileOption(
            id: id,
            name: "\(sourceName) Copy",
            nameKey: nil,
            isBuiltIn: false
        ))
        profiles[id] = profile
        settingsStore.saveProfileOptions(profileOptions)
        settingsStore.saveProfiles(profiles)
        activeProfileID = id
    }

    func renameActiveProfile(to name: String) {
        let trimmedName = normalizedProfileName(name, fallback: profileDisplayName(for: activeProfileID))
        guard let index = profileOptions.firstIndex(where: { $0.id == activeProfileID }) else { return }
        profileOptions[index].name = trimmedName
        profileOptions[index].nameKey = nil
        settingsStore.saveProfileOptions(profileOptions)
    }

    func deleteActiveProfile() {
        guard let index = profileOptions.firstIndex(where: { $0.id == activeProfileID }) else { return }
        guard !profileOptions[index].isBuiltIn, profileOptions.count > 1 else { return }

        let deletedID = activeProfileID
        profileOptions.remove(at: index)
        profiles.removeValue(forKey: deletedID)
        // Pick the next selection from the post-deletion array so we never land
        // back on the just-deleted profile (which happened when index == 0).
        let nextProfileID = profileOptions[min(index, profileOptions.count - 1)].id
        isLoadingProfileState = true
        activeProfileID = nextProfileID
        profile = profiles[nextProfileID] ?? .joyConLeftDefault
        isLoadingProfileState = false
        settingsStore.setActiveProfileID(activeProfileID)
        settingsStore.saveProfileOptions(profileOptions)
        settingsStore.saveProfiles(profiles)
    }

    func resetActiveProfileToDefaults() {
        profile = .joyConLeftDefault
    }

    func exportSettingsData() throws -> Data {
        profiles[activeProfileID] = profile
        let snapshot = SettingsSnapshot(
            formatVersion: settingsStore.settingsExportFormatVersion,
            exportedAt: Date(),
            activeProfileID: activeProfileID,
            profileOptions: profileOptions,
            profiles: profiles,
            isStickMouseEnabled: isStickMouseEnabled,
            mouseSpeed: mouseSpeed,
            mouseDeadzone: mouseDeadzone,
            mouseAcceleration: mouseAcceleration,
            isMouseYInverted: isMouseYInverted
        )
        return try settingsStore.encodeSnapshot(snapshot)
    }

    func importSettingsData(_ data: Data) throws {
        let snapshot = try settingsStore.decodeSnapshot(from: data)

        let merged = settingsStore.mergedProfileOptions(snapshot.profileOptions)
        let options = merged.isEmpty ? Self.defaultProfileOptions : merged

        var importedProfiles = snapshot.profiles
        for option in options where importedProfiles[option.id] == nil {
            importedProfiles[option.id] = .joyConLeftDefault
        }

        isLoadingProfileState = true
        profileOptions = options
        profiles = importedProfiles
        activeProfileID = options.contains(where: { $0.id == snapshot.activeProfileID })
            ? snapshot.activeProfileID
            : options[0].id
        profile = importedProfiles[activeProfileID] ?? .joyConLeftDefault
        isLoadingProfileState = false

        isStickMouseEnabled = snapshot.isStickMouseEnabled
        mouseSpeed = clamped(snapshot.mouseSpeed, to: Tuning.mouseSpeedRange)
        mouseDeadzone = clamped(snapshot.mouseDeadzone, to: Tuning.mouseDeadzoneRange)
        mouseAcceleration = clamped(snapshot.mouseAcceleration, to: Tuning.mouseAccelerationRange)
        isMouseYInverted = snapshot.isMouseYInverted

        settingsStore.setActiveProfileID(activeProfileID)
        settingsStore.saveProfileOptions(profileOptions)
        settingsStore.saveProfiles(profiles)
    }

    func profileDisplayName(for id: String) -> String {
        profileOptions.first(where: { $0.id == id })?.name ?? Self.defaultProfileOptions.first?.name ?? "Default"
    }

    func action(for input: ControllerInput) -> MappingAction {
        profile.action(for: input)
    }

#if DEBUG
    func setTestingDevices(_ devices: [JoyconDevice]) {
        handleDevicesChanged(devices)
    }

    func recordTestingInput(_ input: ControllerInput) {
        recentInputs.insert(input, at: 0)
        recentInputs = Array(recentInputs.prefix(Tuning.inputLogLimit))
    }

    func handleTestingInput(_ input: ControllerInput) {
        handle(input)
    }
#endif

    private func handle(_ input: ControllerInput) {
        updateStickMouseState(with: input)
        updatePressedState(with: input)
        executeMappedAction(for: input)

        guard input.isLoggable else { return }

        if recentInputs.first?.triggerID != input.triggerID || recentInputs.first?.value != input.value {
            recentInputs.insert(input, at: 0)
            recentInputs = Array(recentInputs.prefix(Tuning.inputLogLimit))
        }
    }

    private func handleDevicesChanged(_ devices: [JoyconDevice]) {
        self.devices = devices
        guard devices.isEmpty else { return }
        releaseAllActiveHolds()
        pressedTriggerIDs.removeAll()
        stickX = 0
        stickY = 0
        visibleStickX = 0
        visibleStickY = 0
    }

    private func updatePressedState(with input: ControllerInput) {
        guard input.control.kind == .button || input.control.kind == .hatSwitch else { return }
        if input.isPressed {
            pressedTriggerIDs.insert(input.triggerID)
        } else {
            pressedTriggerIDs.remove(input.triggerID)
        }
    }

    private func executeMappedAction(for input: ControllerInput) {
        guard isMapperEnabled else { return }

        let previousTrigger = activeTriggerByControlID[input.control.id]
        if previousTrigger != input.triggerID, let previousTrigger {
            releaseTrigger(previousTrigger, controlID: input.control.id)
        }

        guard input.isPressed else {
            releaseTrigger(input.triggerID, controlID: input.control.id)
            return
        }

        let action = profile.action(for: input)
        switch action {
        case .none:
            return
        case .keyboardShortcut(let shortcut):
            guard !activeActionTriggers.contains(input.triggerID) else { return }
            engage(action, trigger: input.triggerID, controlID: input.control.id)
            inputSender.post(shortcut: shortcut)
        case .modifierHold(let modifiers):
            guard !activeActionTriggers.contains(input.triggerID) else { return }
            engage(action, trigger: input.triggerID, controlID: input.control.id)
            inputSender.setModifiers(modifiers, isPressed: true)
        case .pushToTalk(let shortcut):
            guard input.control.kind == .button, !activeActionTriggers.contains(input.triggerID) else { return }
            engage(action, trigger: input.triggerID, controlID: input.control.id)
            inputSender.setShortcut(shortcut, isPressed: true)
        case .mouseClick(let button):
            guard !activeActionTriggers.contains(input.triggerID) else { return }
            engage(action, trigger: input.triggerID, controlID: input.control.id)
            inputSender.clickMouse(button)
        case .mouseHold(let button):
            guard input.control.kind == .button, !activeActionTriggers.contains(input.triggerID) else { return }
            engage(action, trigger: input.triggerID, controlID: input.control.id)
            inputSender.setMouseButton(button, isPressed: true)
        case .mouseMove(let deltaX, let deltaY):
            engage(action, trigger: input.triggerID, controlID: input.control.id)
            activeMouseMoves[input.triggerID] = (deltaX, deltaY)
        case .scroll(let deltaX, let deltaY):
            engage(action, trigger: input.triggerID, controlID: input.control.id)
            activeScrolls[input.triggerID] = (deltaX, deltaY)
        }
    }

    /// Records that `action` is now engaged for `triggerID`. The action is stored so
    /// that release can reverse the exact action that fired, even if the active
    /// profile or its assignments change while the control is still held.
    private func engage(_ action: MappingAction, trigger triggerID: String, controlID: String) {
        activeActionTriggers.insert(triggerID)
        activeTriggerByControlID[controlID] = triggerID
        activeActionByTrigger[triggerID] = action
    }

    private func releaseHold(for action: MappingAction) {
        switch action {
        case .pushToTalk(let shortcut):
            inputSender.setShortcut(shortcut, isPressed: false)
        case .modifierHold(let modifiers):
            inputSender.setModifiers(modifiers, isPressed: false)
        case .mouseHold(let button):
            inputSender.setMouseButton(button, isPressed: false)
        default:
            break
        }
    }

    private func releaseTrigger(_ triggerID: String, controlID: String) {
        if let action = activeActionByTrigger[triggerID] {
            releaseHold(for: action)
        }
        activeMouseMoves.removeValue(forKey: triggerID)
        activeScrolls.removeValue(forKey: triggerID)
        activeActionTriggers.remove(triggerID)
        activeActionByTrigger.removeValue(forKey: triggerID)
        activeTriggerByControlID.removeValue(forKey: controlID)
    }

    private func releaseAllActiveHolds() {
        for action in activeActionByTrigger.values {
            releaseHold(for: action)
        }
        activeActionTriggers.removeAll()
        activeTriggerByControlID.removeAll()
        activeActionByTrigger.removeAll()
        activeMouseMoves.removeAll()
        activeScrolls.removeAll()
    }

    /// Installs a global + local keyboard shortcut (Control-Option-Command-Escape)
    /// that immediately disables the mapper. This is a safety valve for when the
    /// pointer or clicks are running away and the menu bar is unusable.
    private func startPanicHotkeyMonitor() {
        guard panicKeyMonitors.isEmpty else { return }

        let handler: (NSEvent) -> Void = { [weak self] event in
            guard event.keyCode == 53,
                  event.modifierFlags.isSuperset(of: [.control, .option, .command]) else { return }
            self?.panicDisable()
        }

        if let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: handler) {
            panicKeyMonitors.append(globalMonitor)
        }
        if let localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { event in
            handler(event)
            return event
        }) {
            panicKeyMonitors.append(localMonitor)
        }
    }

    private func stopPanicHotkeyMonitor() {
        for monitor in panicKeyMonitors {
            NSEvent.removeMonitor(monitor)
        }
        panicKeyMonitors.removeAll()
    }

    private func startMouseTimer() {
        guard mouseTimer == nil else { return }
        mouseTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / Tuning.mouseTicksPerSecond, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tickMouseMovement()
            }
        }
    }

    private func startDeviceRefreshTimer() {
        guard deviceRefreshTimer == nil else { return }
        deviceRefreshTimer = Timer.scheduledTimer(withTimeInterval: Tuning.deviceRefreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isRunning, self.devices.isEmpty else { return }
                self.hidClient.refreshDevices()
            }
        }
    }

    private func startAccessibilityRefreshTimer() {
        guard accessibilityRefreshTimer == nil else { return }
        accessibilityRefreshTimer = Timer.scheduledTimer(withTimeInterval: Tuning.accessibilityRefreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshAccessibilityTrust()
            }
        }
    }

    private func tickMouseMovement() {
        guard isRunning else { return }
        guard isMapperEnabled else { return }

        let stickMove = stickMouseDelta()
        if isStickMouseEnabled, stickMove.deltaX != 0 || stickMove.deltaY != 0 {
            inputSender.moveMouse(deltaX: stickMove.deltaX, deltaY: stickMove.deltaY)
        } else if !activeMouseMoves.isEmpty {
            let combined = activeMouseMoves.values.reduce((deltaX: 0.0, deltaY: 0.0)) { partial, move in
                (partial.deltaX + move.deltaX, partial.deltaY + move.deltaY)
            }
            inputSender.moveMouse(deltaX: combined.deltaX, deltaY: combined.deltaY)
        }

        if !activeScrolls.isEmpty {
            let combined = activeScrolls.values.reduce((deltaX: 0.0, deltaY: 0.0)) { partial, scroll in
                (partial.deltaX + scroll.deltaX, partial.deltaY + scroll.deltaY)
            }
            inputSender.scroll(deltaX: combined.deltaX, deltaY: combined.deltaY)
        }
    }

    private func updateStickMouseState(with input: ControllerInput) {
        switch input.control.id {
        case "stick.left.x":
            stickX = applyDeadzone(input.normalizedValue)
            visibleStickX = stickX
        case "stick.left.y":
            stickY = applyDeadzone(input.normalizedValue)
            visibleStickY = stickY
        default:
            return
        }
    }

    private func stickMouseDelta() -> (deltaX: Double, deltaY: Double) {
        let x = accelerated(stickX)
        let y = accelerated(isMouseYInverted ? -stickY : stickY)
        guard x != 0 || y != 0 else { return (0, 0) }

        let pixelsPerTick = mouseSpeed / Tuning.mouseTicksPerSecond
        return (x * pixelsPerTick, y * pixelsPerTick)
    }

    private func applyDeadzone(_ value: Double) -> Double {
        let deadzone = mouseDeadzone
        let magnitude = abs(value)
        guard magnitude > deadzone else { return 0 }
        let scaled = (magnitude - deadzone) / (1 - deadzone)
        return (value < 0 ? -1 : 1) * scaled
    }

    private func accelerated(_ value: Double) -> Double {
        guard value != 0 else { return 0 }
        return (value < 0 ? -1 : 1) * pow(abs(value), mouseAcceleration)
    }

    private func loadMouseSettings() {
        isOnboardingCompleted = settingsStore.isOnboardingCompleted

        if let storedStickMouseEnabled = settingsStore.storedStickMouseEnabled() {
            isStickMouseEnabled = storedStickMouseEnabled
        }

        let storedSpeed = settingsStore.storedMouseSpeed
        if storedSpeed > 0 {
            mouseSpeed = clamped(storedSpeed, to: Tuning.mouseSpeedRange)
        }

        let storedDeadzone = settingsStore.storedMouseDeadzone
        if storedDeadzone > 0 {
            mouseDeadzone = clamped(storedDeadzone, to: Tuning.mouseDeadzoneRange)
        }

        let storedAcceleration = settingsStore.storedMouseAcceleration
        if storedAcceleration > 0 {
            mouseAcceleration = clamped(storedAcceleration, to: Tuning.mouseAccelerationRange)
        }

        if let storedMouseYInverted = settingsStore.storedMouseYInverted() {
            isMouseYInverted = storedMouseYInverted
        }
    }

    private func loadProfile() {
        isLoadingProfileState = true
        defer { isLoadingProfileState = false }

        let state = settingsStore.loadProfileState()
        profiles = state.profiles
        profileOptions = state.options
        activeProfileID = state.activeProfileID
        profile = state.profile
    }

    private func normalizedProfileName(_ name: String, fallback: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : String(trimmed.prefix(32))
    }

    private func clamped(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private func uniqueProfileID() -> String {
        var id = "custom-\(UUID().uuidString.lowercased())"
        while profiles[id] != nil || profileOptions.contains(where: { $0.id == id }) {
            id = "custom-\(UUID().uuidString.lowercased())"
        }
        return id
    }
}

enum SettingsImportError: LocalizedError, Equatable {
    case emptyFile
    case invalidFormat
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case .emptyFile:
            String(localized: "settings.import.emptyFile")
        case .invalidFormat:
            String(localized: "settings.import.invalidFormat")
        case .unsupportedVersion(let version):
            String(format: String(localized: "settings.import.unsupportedVersion"), version)
        }
    }
}
