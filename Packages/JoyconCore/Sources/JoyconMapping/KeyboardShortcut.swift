import Foundation

public struct KeyboardShortcut: Codable, Equatable, Hashable, Sendable {
    public struct Modifiers: OptionSet, Codable, Hashable, Sendable {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let command = Modifiers(rawValue: 1 << 0)
        public static let shift = Modifiers(rawValue: 1 << 1)
        public static let option = Modifiers(rawValue: 1 << 2)
        public static let control = Modifiers(rawValue: 1 << 3)
    }

    public let key: String
    public let modifiers: Modifiers
    public let keyCode: Int?

    public init(key: String, modifiers: Modifiers = [], keyCode: Int? = nil) {
        self.key = key
        self.modifiers = modifiers
        self.keyCode = keyCode
    }

    public var displayName: String {
        var parts: [String] = []
        if !modifiers.isEmpty {
            parts.append(modifiers.displayName)
        }
        parts.append(key.uppercased())
        return parts.joined(separator: " + ")
    }

    public static let space = KeyboardShortcut(key: "space")
    public static let escape = KeyboardShortcut(key: "escape")
    public static let `return` = KeyboardShortcut(key: "return")
    public static let tab = KeyboardShortcut(key: "tab")
    public static let shiftTab = KeyboardShortcut(key: "tab", modifiers: [.shift])
    public static let delete = KeyboardShortcut(key: "delete")
}

public extension KeyboardShortcut.Modifiers {
    var displayName: String {
        var parts: [String] = []
        if contains(.control) { parts.append("Control") }
        if contains(.option) { parts.append("Option") }
        if contains(.shift) { parts.append("Shift") }
        if contains(.command) { parts.append("Command") }
        return parts.joined(separator: " + ")
    }
}
