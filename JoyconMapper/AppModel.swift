import Combine
import Foundation
import JoyconHID
import JoyconMapping
import MacInput

@MainActor
final class AppModel: ObservableObject {
    struct ProfileOption: Identifiable, Hashable {
        let id: String
        let nameKey: String
    }

    static let profileOptions: [ProfileOption] = [
        ProfileOption(id: "default", nameKey: "profile.default"),
        ProfileOption(id: "browsing", nameKey: "profile.browsing"),
        ProfileOption(id: "meeting", nameKey: "profile.meeting")
    ]

    @Published var isMapperEnabled = true
    @Published var isStickMouseEnabled = true {
        didSet { UserDefaults.standard.set(isStickMouseEnabled, forKey: stickMouseEnabledStoreKey) }
    }
    @Published var mouseSpeed: Double = 4200 {
        didSet { UserDefaults.standard.set(mouseSpeed, forKey: mouseSpeedStoreKey) }
    }
    @Published var mouseDeadzone: Double = 0.16 {
        didSet { UserDefaults.standard.set(mouseDeadzone, forKey: mouseDeadzoneStoreKey) }
    }
    @Published var mouseAcceleration: Double = 1.45 {
        didSet { UserDefaults.standard.set(mouseAcceleration, forKey: mouseAccelerationStoreKey) }
    }
    @Published var isMouseYInverted = false {
        didSet { UserDefaults.standard.set(isMouseYInverted, forKey: mouseYInvertedStoreKey) }
    }
    @Published var activeProfileID = "default" {
        didSet {
            guard oldValue != activeProfileID else { return }
            profiles[oldValue] = profile
            UserDefaults.standard.set(activeProfileID, forKey: activeProfileStoreKey)
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
    @Published var profile = MappingProfile() {
        didSet {
            profiles[activeProfileID] = profile
            saveProfiles()
        }
    }

    private let hidClient = JoyconHIDClient()
    private let inputSender = MacInputSender()
    private var activeActionTriggers: Set<String> = []
    private var activeTriggerByControlID: [String: String] = [:]
    private var activeMouseMoves: [String: (deltaX: Double, deltaY: Double)] = [:]
    private var stickX = 0.0
    private var stickY = 0.0
    private var profiles: [String: MappingProfile] = [:]
    private var mouseTimer: Timer?
    private let legacyProfileStoreKey = "JoyconMapper.MappingProfile.v1"
    private let profilesStoreKey = "JoyconMapper.MappingProfiles.v2"
    private let activeProfileStoreKey = "JoyconMapper.ActiveProfile.v2"
    private let stickMouseEnabledStoreKey = "JoyconMapper.StickMouseEnabled.v1"
    private let mouseSpeedStoreKey = "JoyconMapper.MouseSpeed.v1"
    private let mouseDeadzoneStoreKey = "JoyconMapper.MouseDeadzone.v1"
    private let mouseAccelerationStoreKey = "JoyconMapper.MouseAcceleration.v1"
    private let mouseYInvertedStoreKey = "JoyconMapper.MouseYInverted.v1"
    private let didRequestAccessibilityStoreKey = "JoyconMapper.DidRequestAccessibility.v1"

    init() {
        loadMouseSettings()
        loadProfile()
        hidClient.onDevicesChanged = { [weak self] devices in
            Task { @MainActor in
                self?.devices = devices
            }
        }
        hidClient.onInput = { [weak self] input in
            Task { @MainActor in
                self?.handle(input)
            }
        }
    }

    var isAccessibilityTrusted: Bool {
        inputSender.isAccessibilityTrusted
    }

    var shouldShowAccessibilityPrompt: Bool {
        !isAccessibilityTrusted
    }

    func start() {
        do {
            try hidClient.start()
            isRunning = true
            lastError = nil
            startMouseTimer()
            requestAccessibilityPermissionIfNeeded()
        } catch {
            lastError = error.localizedDescription
            isRunning = false
        }
    }

    func stop() {
        hidClient.stop()
        activeMouseMoves.removeAll()
        pressedTriggerIDs.removeAll()
        mouseTimer?.invalidate()
        mouseTimer = nil
        isRunning = false
    }

    func refreshPermissions() {
        objectWillChange.send()
    }

    func requestAccessibilityPermission() {
        inputSender.requestAccessibilityTrust()
        UserDefaults.standard.set(true, forKey: didRequestAccessibilityStoreKey)
        objectWillChange.send()
    }

    func requestAccessibilityPermissionIfNeeded() {
        guard !isAccessibilityTrusted else { return }
        guard !UserDefaults.standard.bool(forKey: didRequestAccessibilityStoreKey) else { return }
        requestAccessibilityPermission()
    }

    func assignLastInput(_ action: MappingAction) {
        guard let input = recentInputs.first, input.isPressed else { return }
        profile.assign(action, toTriggerID: input.triggerID)
    }

    func assign(_ action: MappingAction, to triggerID: String) {
        profile.assign(action, toTriggerID: triggerID)
    }

    func clearAssignment(for triggerID: String) {
        profile.assignments.removeValue(forKey: triggerID)
    }

    func installJoyConLeftMouseDefaults() {
        profile.removeDPadMouseDefaults()
    }

    func action(for input: ControllerInput) -> MappingAction {
        profile.action(for: input)
    }

    private func handle(_ input: ControllerInput) {
        updateStickMouseState(with: input)
        updatePressedState(with: input)
        executeMappedAction(for: input)

        guard input.isLoggable else { return }

        if recentInputs.first?.triggerID != input.triggerID || recentInputs.first?.value != input.value {
            recentInputs.insert(input, at: 0)
            recentInputs = Array(recentInputs.prefix(80))
        }
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
            switch profile.action(forTriggerID: previousTrigger) {
            case .pushToTalk(let shortcut):
                inputSender.setShortcut(shortcut, isPressed: false)
            case .modifierHold(let modifiers):
                inputSender.setModifiers(modifiers, isPressed: false)
            default:
                break
            }
            activeMouseMoves.removeValue(forKey: previousTrigger)
            activeActionTriggers.remove(previousTrigger)
            activeTriggerByControlID.removeValue(forKey: input.control.id)
        }

        guard input.isPressed else {
            switch profile.action(for: input) {
            case .pushToTalk(let shortcut):
                inputSender.setShortcut(shortcut, isPressed: false)
            case .modifierHold(let modifiers):
                inputSender.setModifiers(modifiers, isPressed: false)
            default:
                break
            }
            activeMouseMoves.removeValue(forKey: input.triggerID)
            activeActionTriggers.remove(input.triggerID)
            activeTriggerByControlID.removeValue(forKey: input.control.id)
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
        }
    }

    private func startMouseTimer() {
        guard mouseTimer == nil else { return }
        mouseTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tickMouseMovement()
            }
        }
    }

    private func tickMouseMovement() {
        guard isMapperEnabled else { return }

        let stickMove = stickMouseDelta()
        if isStickMouseEnabled, stickMove.deltaX != 0 || stickMove.deltaY != 0 {
            inputSender.moveMouse(deltaX: stickMove.deltaX, deltaY: stickMove.deltaY)
            return
        }

        guard !activeMouseMoves.isEmpty else { return }
        let combined = activeMouseMoves.values.reduce((deltaX: 0.0, deltaY: 0.0)) { partial, move in
            (partial.deltaX + move.deltaX, partial.deltaY + move.deltaY)
        }
        inputSender.moveMouse(deltaX: combined.deltaX, deltaY: combined.deltaY)
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

        let pixelsPerTick = mouseSpeed / 120.0
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
        if UserDefaults.standard.object(forKey: stickMouseEnabledStoreKey) != nil {
            isStickMouseEnabled = UserDefaults.standard.bool(forKey: stickMouseEnabledStoreKey)
        }

        let storedSpeed = UserDefaults.standard.double(forKey: mouseSpeedStoreKey)
        if storedSpeed > 0 {
            mouseSpeed = storedSpeed
        }

        let storedDeadzone = UserDefaults.standard.double(forKey: mouseDeadzoneStoreKey)
        if storedDeadzone > 0 {
            mouseDeadzone = storedDeadzone
        }

        let storedAcceleration = UserDefaults.standard.double(forKey: mouseAccelerationStoreKey)
        if storedAcceleration > 0 {
            mouseAcceleration = storedAcceleration
        }

        if UserDefaults.standard.object(forKey: mouseYInvertedStoreKey) != nil {
            isMouseYInverted = UserDefaults.standard.bool(forKey: mouseYInvertedStoreKey)
        }
    }

    private func loadProfile() {
        var loadedProfiles: [String: MappingProfile] = [:]

        if let data = UserDefaults.standard.data(forKey: profilesStoreKey),
           let decoded = try? JSONDecoder().decode([String: MappingProfile].self, from: data) {
            loadedProfiles = decoded
        } else if let data = UserDefaults.standard.data(forKey: legacyProfileStoreKey),
                  let decoded = try? JSONDecoder().decode(MappingProfile.self, from: data) {
            loadedProfiles["default"] = decoded
        }

        for option in Self.profileOptions where loadedProfiles[option.id] == nil {
            loadedProfiles[option.id] = .joyConLeftDefault
        }

        for key in loadedProfiles.keys {
            loadedProfiles[key]?.removeDPadMouseDefaults()
        }

        profiles = loadedProfiles
        activeProfileID = UserDefaults.standard.string(forKey: activeProfileStoreKey) ?? "default"
        profile = profiles[activeProfileID] ?? .joyConLeftDefault
    }

    private func saveProfiles() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        UserDefaults.standard.set(data, forKey: profilesStoreKey)
    }
}
