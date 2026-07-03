//
//  CharacterizationTests.swift
//  JoyconMapperTests
//
//  Characterization tests that pin down current behavior before refactoring.
//  These exercise only the current public API and change no product code.
//

import Testing
import Foundation
@testable import JoyconMapper
import JoyconMapping

struct CharacterizationTests {

    // MARK: - ControllerInput derivations

    @Test func axisTriggerIDUsesPointFiveFiveThreshold() async throws {
        let positive = ControllerInput.axisInput(normalizedValue: 0.56)
        let negative = ControllerInput.axisInput(normalizedValue: -0.56)
        let center = ControllerInput.axisInput(normalizedValue: 0.55)

        #expect(positive.triggerID == "stick.left.x.positive")
        #expect(negative.triggerID == "stick.left.x.negative")
        #expect(center.triggerID == "stick.left.x.center")
    }

    @Test func hatTriggerIDMapsEightDirections() async throws {
        #expect(ControllerInput.hatInput(value: 0).triggerID == "hat.57.up")
        #expect(ControllerInput.hatInput(value: 2).triggerID == "hat.57.right")
        #expect(ControllerInput.hatInput(value: 4).triggerID == "hat.57.down")
        #expect(ControllerInput.hatInput(value: 6).triggerID == "hat.57.left")
        #expect(ControllerInput.hatInput(value: 8).triggerID == "hat.57.center")
    }

    @Test func buttonIsPressedFollowsValue() async throws {
        #expect(ControllerInput.buttonInput(value: 1).isPressed == true)
        #expect(ControllerInput.buttonInput(value: 0).isPressed == false)
    }

    @Test func axisInputsAreNeverLoggable() async throws {
        #expect(ControllerInput.axisInput(normalizedValue: 0.9).isLoggable == false)
    }

    // MARK: - Settings import/export

    @MainActor
    @Test func settingsRoundTripThroughExportAndImport() async throws {
        let source = AppModel(configuration: .testing())
        source.profile.assign(.mouseClick(.right), toTriggerID: "joycon.l")
        let data = try source.exportSettingsData()

        let destination = AppModel(configuration: .testing())
        try destination.importSettingsData(data)

        #expect(destination.profile.action(forTriggerID: "joycon.l") == .mouseClick(.right))
        #expect(destination.activeProfileID == source.activeProfileID)
    }

    @MainActor
    @Test func importClampsMouseSettingsToUIRanges() async throws {
        let source = AppModel(configuration: .testing())
        let data = try source.exportSettingsData()

        var object = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        object["mouseSpeed"] = 99999
        object["mouseDeadzone"] = 0.001
        let mutated = try JSONSerialization.data(withJSONObject: object)

        let destination = AppModel(configuration: .testing())
        try destination.importSettingsData(mutated)

        #expect(destination.mouseSpeed == 7200)
        #expect(destination.mouseDeadzone == 0.05)
    }

    @MainActor
    @Test func importFallsBackWhenActiveProfileIDUnknown() async throws {
        let source = AppModel(configuration: .testing())
        let data = try source.exportSettingsData()

        var object = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        object["activeProfileID"] = "no-such-id"
        let mutated = try JSONSerialization.data(withJSONObject: object)

        let destination = AppModel(configuration: .testing())
        try destination.importSettingsData(mutated)

        #expect(destination.activeProfileID == "default")
    }

    @MainActor
    @Test func loadClampsOutOfRangeMouseSettings() async throws {
        let suiteName = "JoyconMapper.Tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(50.0, forKey: "JoyconMapper.MouseSpeed.v1")

        let configuration = AppModel.Configuration(
            userDefaults: defaults,
            isHardwareEnabled: false,
            accessibilityTrustedOverride: true
        )
        let model = AppModel(configuration: configuration)

        #expect(model.mouseSpeed == 800)
    }

    // MARK: - Profile CRUD

    @MainActor
    @Test func createProfileNormalizesName() async throws {
        let model = AppModel(configuration: .testing())

        model.createProfile(named: "   ")
        let blankID = model.activeProfileID
        #expect(model.profileDisplayName(for: blankID) == "Profile")

        let longName = String(repeating: "あ", count: 40)
        model.createProfile(named: longName)
        let longID = model.activeProfileID
        #expect(model.profileDisplayName(for: longID).count == 32)
    }

    @MainActor
    @Test func builtInProfileCannotBeDeleted() async throws {
        let model = AppModel(configuration: .testing())
        #expect(model.activeProfileID == "default")

        model.deleteActiveProfile()

        #expect(model.profileOptions.count == 3)
    }

    @MainActor
    @Test func deleteActiveProfileSelectsPreviousOption() async throws {
        let model = AppModel(configuration: .testing())
        model.createProfile(named: "X")

        model.deleteActiveProfile()

        #expect(model.activeProfileID == "meeting")
    }

    @MainActor
    @Test func duplicateActiveProfileCopiesAssignments() async throws {
        let model = AppModel(configuration: .testing())
        model.profile.assign(.mouseClick(.right), toTriggerID: "joycon.l")

        model.duplicateActiveProfile()

        #expect(model.activeProfileID != "default")
        #expect(model.profile.action(forTriggerID: "joycon.l") == .mouseClick(.right))
        #expect(model.profileDisplayName(for: model.activeProfileID) == "Default Copy")
    }

    @MainActor
    @Test func renameActiveProfileClearsNameKey() async throws {
        let model = AppModel(configuration: .testing())
        #expect(model.activeProfileID == "default")

        model.renameActiveProfile(to: "Renamed")

        let option = try #require(model.profileOptions.first(where: { $0.id == "default" }))
        #expect(option.name == "Renamed")
        #expect(option.nameKey == nil)
    }

    // MARK: - Mapping profile helper

    @Test func removeDPadMouseDefaultsKeepsScrollAssignments() async throws {
        var profile = MappingProfile()
        profile.assign(.mouseMove(deltaX: 0, deltaY: 14), toTriggerID: "hat.57.up")
        profile.assign(.scroll(deltaX: 0, deltaY: -14), toTriggerID: "hat.57.down")

        profile.removeDPadMouseDefaults()

        #expect(profile.action(forTriggerID: "hat.57.up") == .none)
        #expect(profile.action(forTriggerID: "hat.57.down") == .scroll(deltaX: 0, deltaY: -14))
    }
}

private extension ControllerInput {
    static func axisInput(normalizedValue: Double) -> ControllerInput {
        ControllerInput(
            deviceID: "test-left",
            deviceName: "Joy-Con (L)",
            control: ControllerControl(
                id: "stick.left.x",
                displayName: "Stick X",
                kind: .axis,
                usagePage: 0x01,
                usage: 0x30
            ),
            value: 0,
            normalizedValue: normalizedValue,
            timestamp: Date(timeIntervalSince1970: 0)
        )
    }

    static func hatInput(value: Int) -> ControllerInput {
        ControllerInput(
            deviceID: "test-left",
            deviceName: "Joy-Con (L)",
            control: ControllerControl(
                id: "hat.57",
                displayName: "Hat Switch",
                kind: .hatSwitch,
                usagePage: 0x01,
                usage: 0x39
            ),
            value: value,
            normalizedValue: 0,
            timestamp: Date(timeIntervalSince1970: 0)
        )
    }

    static func buttonInput(value: Int) -> ControllerInput {
        ControllerInput(
            deviceID: "test-left",
            deviceName: "Joy-Con (L)",
            control: ControllerControl(
                id: "joycon.l",
                displayName: "L",
                kind: .button,
                usagePage: 0x09,
                usage: 0x0E
            ),
            value: value,
            normalizedValue: Double(value),
            timestamp: Date(timeIntervalSince1970: 0)
        )
    }
}
