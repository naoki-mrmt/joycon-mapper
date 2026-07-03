import Foundation

public enum MappingAction: Codable, Equatable, Sendable {
    case none
    case keyboardShortcut(KeyboardShortcut)
    case modifierHold(KeyboardShortcut.Modifiers)
    case pushToTalk(KeyboardShortcut)
    case mouseClick(MouseClickButton)
    case mouseHold(MouseClickButton)
    case mouseMove(deltaX: Double, deltaY: Double)
    case scroll(deltaX: Double, deltaY: Double)

    public var displayName: String {
        switch self {
        case .none:
            "No Action"
        case .keyboardShortcut(let shortcut):
            shortcut.displayName
        case .modifierHold(let modifiers):
            "Hold: \(modifiers.displayName)"
        case .pushToTalk(let shortcut):
            "Hold: \(shortcut.displayName)"
        case .mouseClick(let button):
            "\(button.displayName) Click"
        case .mouseHold(let button):
            "Hold: \(button.displayName) Click"
        case .mouseMove(let deltaX, let deltaY):
            if deltaX == 0, deltaY > 0 { "Mouse Up" }
            else if deltaX == 0, deltaY < 0 { "Mouse Down" }
            else if deltaX < 0, deltaY == 0 { "Mouse Left" }
            else if deltaX > 0, deltaY == 0 { "Mouse Right" }
            else { "Mouse Move" }
        case .scroll(let deltaX, let deltaY):
            if deltaX == 0, deltaY > 0 { "Scroll Up" }
            else if deltaX == 0, deltaY < 0 { "Scroll Down" }
            else if deltaX < 0, deltaY == 0 { "Scroll Left" }
            else if deltaX > 0, deltaY == 0 { "Scroll Right" }
            else { "Scroll" }
        }
    }
}

public enum MouseClickButton: String, Codable, Equatable, Sendable {
    case left
    case right

    public var displayName: String {
        switch self {
        case .left: "Left"
        case .right: "Right"
        }
    }
}

public struct MappingProfile: Codable, Equatable, Sendable {
    public var assignments: [String: MappingAction]

    public init(assignments: [String: MappingAction] = [:]) {
        self.assignments = assignments
    }

    public static var joyConLeftDefault: MappingProfile {
        MappingProfile(assignments: [
            "joycon.leftStick": .mouseClick(.left),
            "joycon.zl": .mouseClick(.right),
            "hat.57.up": .scroll(deltaX: 0, deltaY: MappingDefaults.scrollStep),
            "hat.57.down": .scroll(deltaX: 0, deltaY: -MappingDefaults.scrollStep),
            "hat.57.left": .scroll(deltaX: -MappingDefaults.scrollStep, deltaY: 0),
            "hat.57.right": .scroll(deltaX: MappingDefaults.scrollStep, deltaY: 0)
        ])
    }

    public func action(for input: ControllerInput) -> MappingAction {
        assignments[input.triggerID] ?? .none
    }

    public func action(forTriggerID triggerID: String) -> MappingAction {
        assignments[triggerID] ?? .none
    }

    public mutating func assign(_ action: MappingAction, toTriggerID triggerID: String) {
        switch action {
        case .none:
            assignments.removeValue(forKey: triggerID)
        default:
            assignments[triggerID] = action
        }
    }

    public mutating func removeDPadMouseDefaults() {
        for triggerID in [
            "hat.57.up",
            "hat.57.upRight",
            "hat.57.right",
            "hat.57.downRight",
            "hat.57.down",
            "hat.57.downLeft",
            "hat.57.left",
            "hat.57.upLeft"
        ] {
            if case .mouseMove = assignments[triggerID] {
                assignments.removeValue(forKey: triggerID)
            }
        }
    }
}
