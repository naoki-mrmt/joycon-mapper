//
//  JoyConReportParserTests.swift
//  JoyconMapperTests
//

import Testing
import Foundation
import JoyconHID
import JoyconMapping

struct JoyConReportParserTests {

    private static let testDevice = JoyconDevice(
        id: "test",
        name: "Joy-Con (L)",
        vendorID: 0x057E,
        productID: 0x2006,
        transport: "Bluetooth"
    )

    /// Builds a 0x30 report payload:
    /// [0x30, 0x00, 0x00, 0x00, shared, left, stick0, stick1, stick2]
    /// Stick centered = stick0 0x00, stick1 0x08, stick2 0x80.
    private static func report(
        shared: UInt8 = 0x00,
        left: UInt8 = 0x00,
        stick0: UInt8 = 0x00,
        stick1: UInt8 = 0x08,
        stick2: UInt8 = 0x80
    ) -> [UInt8] {
        [0x30, 0x00, 0x00, 0x00, shared, left, stick0, stick1, stick2]
    }

    private static func input(_ inputs: [ControllerInput], triggerID: String) -> ControllerInput? {
        inputs.first { $0.triggerID == triggerID }
    }

    @Test func parsesLButtonPress() async throws {
        let inputs = JoyConReportParser.inputs(from: Self.report(left: 0x40), reportID: 0x30, device: Self.testDevice)

        let l = try #require(Self.input(inputs, triggerID: "joycon.l"))
        #expect(l.value == 1)
        #expect(l.isPressed)

        let zl = try #require(Self.input(inputs, triggerID: "joycon.zl"))
        #expect(zl.value == 0)
    }

    @Test func parsesZLButtonPress() async throws {
        let inputs = JoyConReportParser.inputs(from: Self.report(left: 0x80), reportID: 0x30, device: Self.testDevice)

        let zl = try #require(Self.input(inputs, triggerID: "joycon.zl"))
        #expect(zl.isPressed)
    }

    @Test func parsesDpadUp() async throws {
        let inputs = JoyConReportParser.inputs(from: Self.report(left: 0x02), reportID: 0x30, device: Self.testDevice)

        let up = try #require(Self.input(inputs, triggerID: "hat.57.up"))
        #expect(up.isPressed)
    }

    @Test func parsesSharedButtons() async throws {
        let minusInputs = JoyConReportParser.inputs(from: Self.report(shared: 0x01), reportID: 0x30, device: Self.testDevice)
        #expect(try #require(Self.input(minusInputs, triggerID: "joycon.minus")).isPressed)

        let stickInputs = JoyConReportParser.inputs(from: Self.report(shared: 0x08), reportID: 0x30, device: Self.testDevice)
        #expect(try #require(Self.input(stickInputs, triggerID: "joycon.leftStick")).isPressed)

        let captureInputs = JoyConReportParser.inputs(from: Self.report(shared: 0x20), reportID: 0x30, device: Self.testDevice)
        #expect(try #require(Self.input(captureInputs, triggerID: "joycon.capture")).isPressed)
    }

    @Test func parsesCenteredStickAsZero() async throws {
        let inputs = JoyConReportParser.inputs(from: Self.report(), reportID: 0x30, device: Self.testDevice)

        let x = try #require(Self.input(inputs, triggerID: "stick.left.x.center"))
        let y = try #require(Self.input(inputs, triggerID: "stick.left.y.center"))
        #expect(x.normalizedValue == 0)
        #expect(y.normalizedValue == 0)
    }

    @Test func parsesFullRightStick() async throws {
        let inputs = JoyConReportParser.inputs(
            from: Self.report(stick0: 0xFF, stick1: 0x0F, stick2: 0x80),
            reportID: 0x30,
            device: Self.testDevice
        )

        let x = try #require(inputs.first { $0.control.id == "stick.left.x" })
        #expect(x.normalizedValue > 0.99)
    }

    @Test func ignoresUnknownReportIDs() async throws {
        var bytes = Self.report()
        bytes[0] = 0x21
        let inputs = JoyConReportParser.inputs(from: bytes, reportID: 0x21, device: Self.testDevice)

        #expect(inputs.isEmpty)
    }

    @Test func prependsReportIDWhenMissing() async throws {
        // bytes without the leading report ID: index 3 = shared, 4 = left, 5..7 = stick centered.
        let bytes: [UInt8] = [0x00, 0x00, 0x00, 0x00, 0x40, 0x00, 0x08, 0x80]
        let inputs = JoyConReportParser.inputs(from: bytes, reportID: 0x30, device: Self.testDevice)

        #expect(!inputs.isEmpty)
        let l = try #require(Self.input(inputs, triggerID: "joycon.l"))
        #expect(l.isPressed)
    }
}
