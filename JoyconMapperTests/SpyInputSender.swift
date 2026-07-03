import Foundation
import JoyconMapping
import MacInput

final class SpyInputSender: InputSending {
    struct ShortcutHoldEvent: Equatable {
        let shortcut: KeyboardShortcut
        let isPressed: Bool
    }

    struct ModifierEvent: Equatable {
        let modifiers: KeyboardShortcut.Modifiers
        let isPressed: Bool
    }

    var isAccessibilityTrusted = true
    private(set) var requestAccessibilityTrustCount = 0
    private(set) var postedShortcuts: [KeyboardShortcut] = []
    private(set) var shortcutHoldEvents: [ShortcutHoldEvent] = []
    private(set) var modifierEvents: [ModifierEvent] = []
    private(set) var clickedButtons: [MouseClickButton] = []
    private(set) var mouseMoves: [(deltaX: Double, deltaY: Double)] = []
    private(set) var scrolls: [(deltaX: Double, deltaY: Double)] = []

    var hasRecordedAnything: Bool {
        !postedShortcuts.isEmpty
            || !shortcutHoldEvents.isEmpty
            || !modifierEvents.isEmpty
            || !clickedButtons.isEmpty
            || !mouseMoves.isEmpty
            || !scrolls.isEmpty
    }

    func requestAccessibilityTrust() {
        requestAccessibilityTrustCount += 1
    }

    func post(shortcut: KeyboardShortcut) {
        postedShortcuts.append(shortcut)
    }

    func setShortcut(_ shortcut: KeyboardShortcut, isPressed: Bool) {
        shortcutHoldEvents.append(ShortcutHoldEvent(shortcut: shortcut, isPressed: isPressed))
    }

    func setModifiers(_ modifiers: KeyboardShortcut.Modifiers, isPressed: Bool) {
        modifierEvents.append(ModifierEvent(modifiers: modifiers, isPressed: isPressed))
    }

    func moveMouse(deltaX: Double, deltaY: Double) {
        mouseMoves.append((deltaX, deltaY))
    }

    func clickMouse(_ button: MouseClickButton) {
        clickedButtons.append(button)
    }

    func scroll(deltaX: Double, deltaY: Double) {
        scrolls.append((deltaX, deltaY))
    }
}
