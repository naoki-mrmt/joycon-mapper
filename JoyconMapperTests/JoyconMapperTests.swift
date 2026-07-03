//
//  JoyconMapperTests.swift
//  JoyconMapperTests
//
//  Created by Naoki Muramoto on 2026/05/07.
//

import Testing
import Foundation
@testable import JoyconMapper
import JoyconMapping

struct JoyconMapperTests {

    @Test func defaultProfileIncludesPointerReadyAssignments() async throws {
        let profile = MappingProfile.joyConLeftDefault

        #expect(profile.action(forTriggerID: "joycon.leftStick") == .mouseClick(.left))
        #expect(profile.action(forTriggerID: "joycon.zl") == .mouseClick(.right))
        #expect(profile.action(forTriggerID: "hat.57.up") == .scroll(deltaX: 0, deltaY: 14))
        #expect(profile.action(forTriggerID: "hat.57.down") == .scroll(deltaX: 0, deltaY: -14))
    }

    @Test func assignmentRoundTripsThroughJSON() async throws {
        var profile = MappingProfile.joyConLeftDefault
        profile.assign(.modifierHold([.option, .command]), toTriggerID: "joycon.l")

        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(MappingProfile.self, from: data)

        #expect(decoded == profile)
        #expect(decoded.action(forTriggerID: "joycon.l") == .modifierHold([.option, .command]))
    }

    @Test func assigningNoneClearsExistingAction() async throws {
        var profile = MappingProfile()
        profile.assign(.mouseClick(.right), toTriggerID: "joycon.zl")
        profile.assign(.none, toTriggerID: "joycon.zl")

        #expect(profile.action(forTriggerID: "joycon.zl") == .none)
        #expect(profile.assignments.isEmpty)
    }

    @MainActor
    @Test func clearRecentInputsRemovesInputLogEntries() async throws {
        let model = AppModel(configuration: .testing())
        model.recordTestingInput(.zlButton)

        #expect(model.recentInputs.count == 1)

        model.clearRecentInputs()

        #expect(model.recentInputs.isEmpty)
    }

    @MainActor
    @Test func importingEmptySettingsReportsSpecificError() async throws {
        let model = AppModel(configuration: .testing())

        do {
            try model.importSettingsData(Data())
            Issue.record("Expected empty file import to fail.")
        } catch let error as SettingsImportError {
            #expect(error == .emptyFile)
        }
    }

    @MainActor
    @Test func importingInvalidSettingsReportsSpecificError() async throws {
        let model = AppModel(configuration: .testing())

        do {
            try model.importSettingsData(Data("not json".utf8))
            Issue.record("Expected invalid JSON import to fail.")
        } catch let error as SettingsImportError {
            #expect(error == .invalidFormat)
        }
    }
}

private extension ControllerInput {
    static var zlButton: ControllerInput {
        ControllerInput(
            deviceID: "test-left",
            deviceName: "Joy-Con (L)",
            control: ControllerControl(
                id: "joycon.zl",
                displayName: "ZL",
                kind: .button,
                usagePage: 0x09,
                usage: 0x0E
            ),
            value: 1,
            normalizedValue: 1,
            timestamp: Date(timeIntervalSince1970: 0)
        )
    }
}
