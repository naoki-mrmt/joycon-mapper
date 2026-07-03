import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import JoyconMapping

public final class MacInputSender {
    private var pressedMouseButtons: Set<MouseClickButton> = []

    public init() {}

    public var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    public func requestAccessibilityTrust() {
        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    public static func resolvedKeyCode(for shortcut: KeyboardShortcut) -> CGKeyCode? {
        shortcut.keyCode.map(CGKeyCode.init) ?? KeyCodeMap.code(for: shortcut.key)
    }

    public func post(shortcut: KeyboardShortcut) {
        guard let keyCode = Self.resolvedKeyCode(for: shortcut) else { return }

        postKey(keyCode, isDown: true, modifiers: shortcut.modifiers)
        postKey(keyCode, isDown: false, modifiers: shortcut.modifiers)
    }

    public func setShortcut(_ shortcut: KeyboardShortcut, isPressed: Bool) {
        guard let keyCode = Self.resolvedKeyCode(for: shortcut) else { return }
        postKey(keyCode, isDown: isPressed, modifiers: shortcut.modifiers)
    }

    public func setModifiers(_ modifiers: KeyboardShortcut.Modifiers, isPressed: Bool) {
        let keys = ModifierKey.keys(for: modifiers)
        if isPressed {
            var activeFlags: CGEventFlags = []
            for key in keys {
                activeFlags.insert(key.flag)
                postRawKey(key.keyCode, isDown: true, flags: activeFlags)
            }
        } else {
            var activeFlags = modifiers.cgFlags
            for key in keys.reversed() {
                activeFlags.remove(key.flag)
                postRawKey(key.keyCode, isDown: false, flags: activeFlags)
            }
        }
    }

    public func moveMouse(deltaX: Double, deltaY: Double) {
        let current = CGEvent(source: nil)?.location ?? .zero
        let target = Self.clampedToDisplays(
            CGPoint(x: current.x + deltaX, y: current.y - deltaY),
            displays: Self.activeDisplayBounds()
        )

        let eventType: CGEventType
        let eventButton: CGMouseButton
        if pressedMouseButtons.contains(.left) {
            eventType = .leftMouseDragged
            eventButton = .left
        } else if pressedMouseButtons.contains(.right) {
            eventType = .rightMouseDragged
            eventButton = .right
        } else {
            eventType = .mouseMoved
            eventButton = .left
        }

        CGEvent(mouseEventSource: nil, mouseType: eventType, mouseCursorPosition: target, mouseButton: eventButton)?
            .post(tap: .cghidEventTap)
    }

    public func setMouseButton(_ button: MouseClickButton, isPressed: Bool) {
        let location = CGEvent(source: nil)?.location ?? .zero
        let cgButton: CGMouseButton
        let eventType: CGEventType

        switch button {
        case .left:
            cgButton = .left
            eventType = isPressed ? .leftMouseDown : .leftMouseUp
        case .right:
            cgButton = .right
            eventType = isPressed ? .rightMouseDown : .rightMouseUp
        }

        if isPressed {
            pressedMouseButtons.insert(button)
        } else {
            pressedMouseButtons.remove(button)
        }

        CGEvent(mouseEventSource: nil, mouseType: eventType, mouseCursorPosition: location, mouseButton: cgButton)?
            .post(tap: .cghidEventTap)
    }

    public static func clampedToDisplays(_ point: CGPoint, displays: [CGRect]) -> CGPoint {
        guard !displays.isEmpty else { return point }
        guard !displays.contains(where: { $0.contains(point) }) else { return point }

        var best = point
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for rect in displays {
            let clamped = CGPoint(
                x: min(max(point.x, rect.minX), rect.maxX - 1),
                y: min(max(point.y, rect.minY), rect.maxY - 1)
            )
            let dx = clamped.x - point.x
            let dy = clamped.y - point.y
            let distance = dx * dx + dy * dy
            if distance < bestDistance {
                bestDistance = distance
                best = clamped
            }
        }
        return best
    }

    private static func activeDisplayBounds() -> [CGRect] {
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &displayCount)
        guard displayCount > 0 else { return [] }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        CGGetActiveDisplayList(displayCount, &displays, &displayCount)
        return displays.map(CGDisplayBounds)
    }

    public func clickMouse(_ button: MouseClickButton) {
        let location = CGEvent(source: nil)?.location ?? .zero
        let cgButton: CGMouseButton
        let eventTypeDown: CGEventType
        let eventTypeUp: CGEventType

        switch button {
        case .left:
            cgButton = .left
            eventTypeDown = .leftMouseDown
            eventTypeUp = .leftMouseUp
        case .right:
            cgButton = .right
            eventTypeDown = .rightMouseDown
            eventTypeUp = .rightMouseUp
        }

        CGEvent(mouseEventSource: nil, mouseType: eventTypeDown, mouseCursorPosition: location, mouseButton: cgButton)?
            .post(tap: .cghidEventTap)
        CGEvent(mouseEventSource: nil, mouseType: eventTypeUp, mouseCursorPosition: location, mouseButton: cgButton)?
            .post(tap: .cghidEventTap)
    }

    public func scroll(deltaX: Double, deltaY: Double) {
        guard deltaX != 0 || deltaY != 0 else { return }
        let horizontal = Int32(deltaX.rounded())
        let vertical = Int32(deltaY.rounded())
        CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: vertical,
            wheel2: horizontal,
            wheel3: 0
        )?.post(tap: .cghidEventTap)
    }

    private func postKey(_ keyCode: CGKeyCode, isDown: Bool, modifiers: KeyboardShortcut.Modifiers) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: isDown) else {
            return
        }
        event.flags = modifiers.cgFlags
        event.post(tap: .cghidEventTap)
    }

    private func postRawKey(_ keyCode: CGKeyCode, isDown: Bool, flags: CGEventFlags) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: isDown) else {
            return
        }
        event.flags = flags
        event.post(tap: .cghidEventTap)
    }
}

private extension KeyboardShortcut.Modifiers {
    var cgFlags: CGEventFlags {
        var flags: CGEventFlags = []
        if contains(.command) { flags.insert(.maskCommand) }
        if contains(.shift) { flags.insert(.maskShift) }
        if contains(.option) { flags.insert(.maskAlternate) }
        if contains(.control) { flags.insert(.maskControl) }
        return flags
    }
}

private struct ModifierKey {
    let modifier: KeyboardShortcut.Modifiers
    let keyCode: CGKeyCode
    let flag: CGEventFlags

    static func keys(for modifiers: KeyboardShortcut.Modifiers) -> [ModifierKey] {
        all.filter { modifiers.contains($0.modifier) }
    }

    private static let all: [ModifierKey] = [
        ModifierKey(modifier: .control, keyCode: 59, flag: .maskControl),
        ModifierKey(modifier: .option, keyCode: 58, flag: .maskAlternate),
        ModifierKey(modifier: .shift, keyCode: 56, flag: .maskShift),
        ModifierKey(modifier: .command, keyCode: 55, flag: .maskCommand)
    ]
}

private enum KeyCodeMap {
    static func code(for key: String) -> CGKeyCode? {
        codes[key.lowercased()]
    }

    private static let codes: [String: CGKeyCode] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
        "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
        "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
        "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29,
        "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "return": 36,
        "l": 37, "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43,
        "/": 44, "n": 45, "m": 46, ".": 47, "tab": 48, "space": 49,
        "`": 50, "delete": 51, "escape": 53, "left": 123, "right": 124,
        "down": 125, "up": 126
    ]
}
