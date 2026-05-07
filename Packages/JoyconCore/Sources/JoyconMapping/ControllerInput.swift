import Foundation

public struct ControllerInput: Identifiable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case button
        case axis
        case hatSwitch
        case vendorDefined
        case unknown
    }

    public var id: String { "\(deviceID)|\(control.id)|\(timestamp.timeIntervalSince1970)" }
    public let deviceID: String
    public let deviceName: String
    public let control: ControllerControl
    public let value: Int
    public let normalizedValue: Double
    public let timestamp: Date

    public var triggerID: String {
        switch control.kind {
        case .hatSwitch:
            "\(control.id).\(hatDirectionKey(value))"
        case .axis:
            if normalizedValue > 0.55 {
                "\(control.id).positive"
            } else if normalizedValue < -0.55 {
                "\(control.id).negative"
            } else {
                "\(control.id).center"
            }
        default:
            control.id
        }
    }

    public var triggerDisplayName: String {
        switch control.kind {
        case .hatSwitch:
            "Hat \(hatDirectionName(value))"
        case .axis:
            if normalizedValue > 0.55 {
                "\(control.displayName) +"
            } else if normalizedValue < -0.55 {
                "\(control.displayName) -"
            } else {
                "\(control.displayName) Center"
            }
        default:
            control.displayName
        }
    }

    public var isPressed: Bool {
        switch control.kind {
        case .button:
            value != 0
        case .hatSwitch:
            value >= 0 && value <= 7
        case .axis:
            abs(normalizedValue) > 0.55
        case .vendorDefined, .unknown:
            value != 0
        }
    }

    public var isLoggable: Bool {
        switch control.kind {
        case .button:
            isPressed
        case .hatSwitch, .axis:
            control.kind == .hatSwitch && isPressed
        case .vendorDefined, .unknown:
            false
        }
    }

    public init(
        deviceID: String,
        deviceName: String,
        control: ControllerControl,
        value: Int,
        normalizedValue: Double,
        timestamp: Date = Date()
    ) {
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.control = control
        self.value = value
        self.normalizedValue = normalizedValue
        self.timestamp = timestamp
    }
}

public struct ControllerControl: Codable, Hashable, Sendable {
    public let id: String
    public let displayName: String
    public let kind: ControllerInput.Kind
    public let usagePage: Int
    public let usage: Int

    public init(
        id: String,
        displayName: String,
        kind: ControllerInput.Kind,
        usagePage: Int,
        usage: Int
    ) {
        self.id = id
        self.displayName = displayName
        self.kind = kind
        self.usagePage = usagePage
        self.usage = usage
    }

    public static func fromHID(usagePage: Int, usage: Int) -> ControllerControl {
        let kind: ControllerInput.Kind
        let prefix: String
        let name: String

        switch usagePage {
        case 0x01:
            kind = usage == 0x39 ? .hatSwitch : .axis
            prefix = usage == 0x39 ? "hat" : "axis"
            name = genericDesktopUsageName(usage)
        case 0x09:
            kind = .button
            prefix = "button"
            name = "Button \(usage)"
        case 0xFF00...0xFFFF:
            kind = .vendorDefined
            prefix = "vendor"
            name = "Vendor \(String(format: "%04X:%04X", usagePage, usage))"
        default:
            kind = .unknown
            prefix = "usage"
            name = "Usage \(String(format: "%04X:%04X", usagePage, usage))"
        }

        return ControllerControl(
            id: "\(prefix).\(usage)",
            displayName: name,
            kind: kind,
            usagePage: usagePage,
            usage: usage
        )
    }
}

private func genericDesktopUsageName(_ usage: Int) -> String {
    switch usage {
    case 0x30: "Stick X"
    case 0x31: "Stick Y"
    case 0x32: "Stick Z"
    case 0x33: "Rx"
    case 0x34: "Ry"
    case 0x35: "Rz"
    case 0x39: "Hat Switch"
    default: "Axis \(usage)"
    }
}

private func hatDirectionKey(_ value: Int) -> String {
    switch value {
    case 0: "up"
    case 1: "upRight"
    case 2: "right"
    case 3: "downRight"
    case 4: "down"
    case 5: "downLeft"
    case 6: "left"
    case 7: "upLeft"
    default: "center"
    }
}

private func hatDirectionName(_ value: Int) -> String {
    switch value {
    case 0: "Up"
    case 1: "Up Right"
    case 2: "Right"
    case 3: "Down Right"
    case 4: "Down"
    case 5: "Down Left"
    case 6: "Left"
    case 7: "Up Left"
    default: "Center"
    }
}
