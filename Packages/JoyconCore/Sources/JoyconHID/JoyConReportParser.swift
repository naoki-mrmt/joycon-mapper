import Foundation
import JoyconMapping

public enum JoyConReportParser {
    public static func inputs(from bytes: [UInt8], reportID: UInt32, device: JoyconDevice) -> [ControllerInput] {
        let payload: [UInt8]
        if let first = bytes.first, UInt32(first) == reportID {
            payload = bytes
        } else {
            payload = [UInt8(reportID & 0xFF)] + bytes
        }

        guard payload.count >= 6 else { return [] }

        switch payload[0] {
        case 0x30, 0x31, 0x32, 0x33, 0x3F:
            return parseButtonInputs(payload: payload, device: device) + parseLeftStickInputs(payload: payload, device: device)
        default:
            return []
        }
    }

    private static func parseButtonInputs(payload: [UInt8], device: JoyconDevice) -> [ControllerInput] {
        let shared = payload[4]
        let left = payload[5]

        let definitions: [(key: String, name: String, isPressed: Bool)] = [
            ("hat.57.down", "D-pad Down", left & (1 << 0) != 0),
            ("hat.57.up", "D-pad Up", left & (1 << 1) != 0),
            ("hat.57.right", "D-pad Right", left & (1 << 2) != 0),
            ("hat.57.left", "D-pad Left", left & (1 << 3) != 0),
            ("minus", "Minus", shared & (1 << 0) != 0),
            ("leftStick", "Left Stick", shared & (1 << 3) != 0),
            ("capture", "Capture", shared & (1 << 5) != 0),
            ("sr", "SR", left & (1 << 4) != 0),
            ("sl", "SL", left & (1 << 5) != 0),
            ("l", "L", left & (1 << 6) != 0),
            ("zl", "ZL", left & (1 << 7) != 0)
        ]

        return definitions.map { definition in
            let control = ControllerControl(
                id: definition.key.hasPrefix("hat.") ? definition.key : "joycon.\(definition.key)",
                displayName: definition.name,
                kind: .button,
                usagePage: 0xFF01,
                usage: 0
            )
            return ControllerInput(
                deviceID: device.id,
                deviceName: device.name,
                control: control,
                value: definition.isPressed ? 1 : 0,
                normalizedValue: definition.isPressed ? 1 : 0
            )
        }
    }

    private static func parseLeftStickInputs(payload: [UInt8], device: JoyconDevice) -> [ControllerInput] {
        guard payload.count >= 9 else { return [] }

        let rawX = Int(payload[6]) | ((Int(payload[7]) & 0x0F) << 8)
        let rawY = (Int(payload[7]) >> 4) | (Int(payload[8]) << 4)
        let normalizedX = normalizeStick(rawX)
        let normalizedY = normalizeStick(rawY)

        return [
            axisInput(id: "stick.left.x", name: "Left Stick X", rawValue: rawX, normalizedValue: normalizedX, device: device),
            axisInput(id: "stick.left.y", name: "Left Stick Y", rawValue: rawY, normalizedValue: normalizedY, device: device)
        ]
    }

    private static func axisInput(
        id: String,
        name: String,
        rawValue: Int,
        normalizedValue: Double,
        device: JoyconDevice
    ) -> ControllerInput {
        ControllerInput(
            deviceID: device.id,
            deviceName: device.name,
            control: ControllerControl(
                id: id,
                displayName: name,
                kind: .axis,
                usagePage: 0xFF01,
                usage: 0
            ),
            value: rawValue,
            normalizedValue: normalizedValue
        )
    }

    private static func normalizeStick(_ value: Int) -> Double {
        let centered = (Double(value) - 2048.0) / 2048.0
        return min(max(centered, -1), 1)
    }
}
