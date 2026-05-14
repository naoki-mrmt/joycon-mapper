//
//  JoyconMapperTests.swift
//  JoyconMapperTests
//
//  Created by Naoki Muramoto on 2026/05/07.
//

import Testing
import Foundation
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
}
