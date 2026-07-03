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
        didSet { userDefaults.set(isStickMouseEnabled, forKey: stickMouseEnabledStoreKey) }
    }
    @Published var mouseSpeed: Double = 4200 {
        didSet { userDefaults.set(mouseSpeed, forKey: mouseSpeedStoreKey) }
    }
    @Published var mouseDeadzone: Double = 0.16 {
        didSet { userDefaults.set(mouseDeadzone, forKey: mouseDeadzoneStoreKey) }
    }
    @Published var mouseAcceleration: Double = 1.45 {
        didSet { userDefaults.set(mouseAcceleration, forKey: mouseAccelerationStoreKey) }
    }
    @Published var isMouseYInverted = false {
        didSet { userDefaults.set(isMouseYInverted, forKey: mouseYInvertedStoreKey) }
    }
    @Published var isOnboardingCompleted = false {
        didSet { userDefaults.set(isOnboardingCompleted, forKey: onboardingCompletedStoreKey) }
    }
    @Published private(set) var profileOptions = AppModel.defaultProfileOptions
    @Published var activeProfileID = "default" {
        didSet {
            guard oldValue != activeProfileID else { return }
            guard !isLoadingProfileState else { return }
            profiles[oldValue] = profile
            userDefaults.set(activeProfileID, forKey: activeProfileStoreKey)
            profile = profiles[activeProfileID] ?? .joyConLeftDefault
            saveProfiles()
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
    @Published var profile = MappingProfile() {
        didSet {
            guard !isLoadingProfileState else { return }
            profiles[activeProfileID] = profile
            saveProfiles()
        }
    }

    private let hidClient = JoyconHIDClient()
    private let inputSender: any InputSending
    private let configuration: Configuration
    private let userDefaults: UserDefaults
    private var activeActionTriggers: Set<String> = []
    private var activeTriggerByControlID: [String: String] = [:]
    private var activeMouseMoves: [String: (deltaX: Double, deltaY: Double)] = [:]
    private var activeScrolls: [String: (deltaX: Double, deltaY: Double)] = [:]
    private var stickX = 0.0
    private var stickY = 0.0
    private var profiles: [String: MappingProfile] = [:]
    private var isLoadingProfileState = false
    private var mouseTimer: Timer?
    private var deviceRefreshTimer: Timer?
    private let legacyProfileStoreKey = "JoyconMapper.MappingProfile.v1"
    private let profilesStoreKey = "JoyconMapper.MappingProfiles.v2"
    private let profileOptionsStoreKey = "JoyconMapper.ProfileOptions.v1"
    private let activeProfileStoreKey = "JoyconMapper.ActiveProfile.v2"
    private let stickMouseEnabledStoreKey = "JoyconMapper.StickMouseEnabled.v1"
    private let mouseSpeedStoreKey = "JoyconMapper.MouseSpeed.v1"
    private let mouseDeadzoneStoreKey = "JoyconMapper.MouseDeadzone.v1"
    private let mouseAccelerationStoreKey = "JoyconMapper.MouseAcceleration.v1"
    private let mouseYInvertedStoreKey = "JoyconMapper.MouseYInverted.v1"
    private let didRequestAccessibilityStoreKey = "JoyconMapper.DidRequestAccessibility.v1"
    private let onboardingCompletedStoreKey = "JoyconMapper.OnboardingCompleted.v1"
    private let settingsExportFormatVersion = 1

    init(configuration: Configuration = .live, inputSender: (any InputSending)? = nil) {
        self.configuration = configuration
        self.userDefaults = configuration.userDefaults
        self.inputSender = inputSender ?? MacInputSender()
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
    }

    var isAccessibilityTrusted: Bool {
        configuration.accessibilityTrustedOverride ?? inputSender.isAccessibilityTrusted
    }

    var shouldShowAccessibilityPrompt: Bool {
        !isAccessibilityTrusted
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
        releaseAllActiveHolds()
        pressedTriggerIDs.removeAll()
        mouseTimer?.invalidate()
        mouseTimer = nil
        deviceRefreshTimer?.invalidate()
        deviceRefreshTimer = nil
        isRunning = false
    }

    func reconnect() {
        stop()
        start()
    }

    func requestAccessibilityPermission() {
        guard configuration.accessibilityTrustedOverride == nil else {
            objectWillChange.send()
            return
        }

        inputSender.requestAccessibilityTrust()
        userDefaults.set(true, forKey: didRequestAccessibilityStoreKey)
        objectWillChange.send()
    }

    func requestAccessibilityPermissionIfNeeded() {
        guard !isAccessibilityTrusted else { return }
        guard !userDefaults.bool(forKey: didRequestAccessibilityStoreKey) else { return }
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
        saveProfileOptions()
        saveProfiles()
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
        saveProfileOptions()
        saveProfiles()
        activeProfileID = id
    }

    func renameActiveProfile(to name: String) {
        let trimmedName = normalizedProfileName(name, fallback: profileDisplayName(for: activeProfileID))
        guard let index = profileOptions.firstIndex(where: { $0.id == activeProfileID }) else { return }
        profileOptions[index].name = trimmedName
        profileOptions[index].nameKey = nil
        saveProfileOptions()
    }

    func deleteActiveProfile() {
        guard let index = profileOptions.firstIndex(where: { $0.id == activeProfileID }) else { return }
        guard !profileOptions[index].isBuiltIn, profileOptions.count > 1 else { return }

        let deletedID = activeProfileID
        let nextProfileID = profileOptions[max(0, index - 1)].id
        isLoadingProfileState = true
        profileOptions.remove(at: index)
        profiles.removeValue(forKey: deletedID)
        activeProfileID = nextProfileID
        profile = profiles[nextProfileID] ?? .joyConLeftDefault
        isLoadingProfileState = false
        userDefaults.set(activeProfileID, forKey: activeProfileStoreKey)
        saveProfileOptions()
        saveProfiles()
    }

    func resetActiveProfileToDefaults() {
        profile = .joyConLeftDefault
    }

    func exportSettingsData() throws -> Data {
        profiles[activeProfileID] = profile
        let snapshot = SettingsSnapshot(
            formatVersion: settingsExportFormatVersion,
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
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(snapshot)
    }

    func importSettingsData(_ data: Data) throws {
        guard !data.isEmpty else {
            throw SettingsImportError.emptyFile
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot: SettingsSnapshot
        do {
            snapshot = try decoder.decode(SettingsSnapshot.self, from: data)
        } catch {
            throw SettingsImportError.invalidFormat
        }

        guard snapshot.formatVersion == settingsExportFormatVersion else {
            throw SettingsImportError.unsupportedVersion(snapshot.formatVersion)
        }

        let merged = mergedProfileOptions(snapshot.profileOptions)
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

        userDefaults.set(activeProfileID, forKey: activeProfileStoreKey)
        saveProfileOptions()
        saveProfiles()
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

        switch profile.action(for: input) {
        case .none:
            return
        case .keyboardShortcut(let shortcut):
            guard !activeActionTriggers.contains(input.triggerID) else { return }
            activeActionTriggers.insert(input.triggerID)
            activeTriggerByControlID[input.control.id] = input.triggerID
            inputSender.post(shortcut: shortcut)
        case .modifierHold(let modifiers):
            guard !activeActionTriggers.contains(input.triggerID) else { return }
            activeActionTriggers.insert(input.triggerID)
            activeTriggerByControlID[input.control.id] = input.triggerID
            inputSender.setModifiers(modifiers, isPressed: true)
        case .pushToTalk(let shortcut):
            guard input.control.kind == .button, !activeActionTriggers.contains(input.triggerID) else { return }
            activeActionTriggers.insert(input.triggerID)
            activeTriggerByControlID[input.control.id] = input.triggerID
            inputSender.setShortcut(shortcut, isPressed: true)
        case .mouseClick(let button):
            guard !activeActionTriggers.contains(input.triggerID) else { return }
            activeActionTriggers.insert(input.triggerID)
            activeTriggerByControlID[input.control.id] = input.triggerID
            inputSender.clickMouse(button)
        case .mouseMove(let deltaX, let deltaY):
            activeMouseMoves[input.triggerID] = (deltaX, deltaY)
            activeActionTriggers.insert(input.triggerID)
            activeTriggerByControlID[input.control.id] = input.triggerID
        case .scroll(let deltaX, let deltaY):
            activeScrolls[input.triggerID] = (deltaX, deltaY)
            activeActionTriggers.insert(input.triggerID)
            activeTriggerByControlID[input.control.id] = input.triggerID
        }
    }

    private func releaseTrigger(_ triggerID: String, controlID: String) {
        switch profile.action(forTriggerID: triggerID) {
        case .pushToTalk(let shortcut):
            inputSender.setShortcut(shortcut, isPressed: false)
        case .modifierHold(let modifiers):
            inputSender.setModifiers(modifiers, isPressed: false)
        default:
            break
        }
        activeMouseMoves.removeValue(forKey: triggerID)
        activeScrolls.removeValue(forKey: triggerID)
        activeActionTriggers.remove(triggerID)
        activeTriggerByControlID.removeValue(forKey: controlID)
    }

    private func releaseAllActiveHolds() {
        for (controlID, triggerID) in activeTriggerByControlID {
            releaseTrigger(triggerID, controlID: controlID)
        }
        activeActionTriggers.removeAll()
        activeTriggerByControlID.removeAll()
        activeMouseMoves.removeAll()
        activeScrolls.removeAll()
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

    private func tickMouseMovement() {
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
        isOnboardingCompleted = userDefaults.bool(forKey: onboardingCompletedStoreKey)

        if userDefaults.object(forKey: stickMouseEnabledStoreKey) != nil {
            isStickMouseEnabled = userDefaults.bool(forKey: stickMouseEnabledStoreKey)
        }

        let storedSpeed = userDefaults.double(forKey: mouseSpeedStoreKey)
        if storedSpeed > 0 {
            mouseSpeed = clamped(storedSpeed, to: Tuning.mouseSpeedRange)
        }

        let storedDeadzone = userDefaults.double(forKey: mouseDeadzoneStoreKey)
        if storedDeadzone > 0 {
            mouseDeadzone = clamped(storedDeadzone, to: Tuning.mouseDeadzoneRange)
        }

        let storedAcceleration = userDefaults.double(forKey: mouseAccelerationStoreKey)
        if storedAcceleration > 0 {
            mouseAcceleration = clamped(storedAcceleration, to: Tuning.mouseAccelerationRange)
        }

        if userDefaults.object(forKey: mouseYInvertedStoreKey) != nil {
            isMouseYInverted = userDefaults.bool(forKey: mouseYInvertedStoreKey)
        }
    }

    private func loadProfile() {
        isLoadingProfileState = true
        defer { isLoadingProfileState = false }

        var loadedProfiles: [String: MappingProfile] = [:]
        let loadedOptions = loadProfileOptions()

        if let data = userDefaults.data(forKey: profilesStoreKey),
           let decoded = try? JSONDecoder().decode([String: MappingProfile].self, from: data) {
            loadedProfiles = decoded
        } else if let data = userDefaults.data(forKey: legacyProfileStoreKey),
                  let decoded = try? JSONDecoder().decode(MappingProfile.self, from: data) {
            loadedProfiles["default"] = decoded
        }

        for option in loadedOptions where loadedProfiles[option.id] == nil {
            loadedProfiles[option.id] = .joyConLeftDefault
        }

        for key in loadedProfiles.keys {
            loadedProfiles[key]?.removeDPadMouseDefaults()
        }

        profiles = loadedProfiles
        profileOptions = loadedOptions
        let storedProfileID = userDefaults.string(forKey: activeProfileStoreKey) ?? "default"
        activeProfileID = loadedOptions.contains(where: { $0.id == storedProfileID }) ? storedProfileID : loadedOptions[0].id
        profile = profiles[activeProfileID] ?? .joyConLeftDefault
        saveProfileOptions()
        saveProfiles()
    }

    private func saveProfiles() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        userDefaults.set(data, forKey: profilesStoreKey)
    }

    private func loadProfileOptions() -> [ProfileOption] {
        if let data = userDefaults.data(forKey: profileOptionsStoreKey),
           let decoded = try? JSONDecoder().decode([ProfileOption].self, from: data),
           !decoded.isEmpty {
            return mergedProfileOptions(decoded)
        }

        return Self.defaultProfileOptions
    }

    private func mergedProfileOptions(_ storedOptions: [ProfileOption]) -> [ProfileOption] {
        var options = storedOptions
        for builtIn in Self.defaultProfileOptions where !options.contains(where: { $0.id == builtIn.id }) {
            options.insert(builtIn, at: min(options.count, Self.defaultProfileOptions.count))
        }
        return options
    }

    private func saveProfileOptions() {
        guard let data = try? JSONEncoder().encode(profileOptions) else { return }
        userDefaults.set(data, forKey: profileOptionsStoreKey)
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
