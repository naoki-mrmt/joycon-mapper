import Testing
import Foundation
@testable import JoyconMapper
import JoyconMapping

@MainActor
struct ActionExecutionTests {

    @Test func keyboardShortcutFiresOncePerPress() async throws {
        let (model, spy) = makeModel()
        model.profile.assign(.keyboardShortcut(.escape), toTriggerID: "joycon.l")

        model.handleTestingInput(.lButton(value: 1))
        model.handleTestingInput(.lButton(value: 1))
        model.handleTestingInput(.lButton(value: 0))

        #expect(spy.postedShortcuts == [.escape])
    }

    @Test func modifierHoldPressAndRelease() async throws {
        let (model, spy) = makeModel()
        model.profile.assign(.modifierHold(.command), toTriggerID: "joycon.l")

        model.handleTestingInput(.lButton(value: 1))
        model.handleTestingInput(.lButton(value: 0))

        #expect(spy.modifierEvents == [
            SpyInputSender.ModifierEvent(modifiers: .command, isPressed: true),
            SpyInputSender.ModifierEvent(modifiers: .command, isPressed: false)
        ])
    }

    @Test func pushToTalkHoldsWhilePressed() async throws {
        let (model, spy) = makeModel()
        model.profile.assign(.pushToTalk(.space), toTriggerID: "joycon.l")

        model.handleTestingInput(.lButton(value: 1))
        model.handleTestingInput(.lButton(value: 0))

        #expect(spy.shortcutHoldEvents == [
            SpyInputSender.ShortcutHoldEvent(shortcut: .space, isPressed: true),
            SpyInputSender.ShortcutHoldEvent(shortcut: .space, isPressed: false)
        ])
    }

    @Test func mouseClickFiresOnPress() async throws {
        let (model, spy) = makeModel()
        model.profile.assign(.mouseClick(.left), toTriggerID: "joycon.l")

        model.handleTestingInput(.lButton(value: 1))
        model.handleTestingInput(.lButton(value: 0))

        #expect(spy.clickedButtons == [.left])
    }

    @Test func disabledMapperExecutesNothing() async throws {
        let (model, spy) = makeModel()
        model.profile.assign(.keyboardShortcut(.escape), toTriggerID: "joycon.l")
        model.isMapperEnabled = false

        model.handleTestingInput(.lButton(value: 1))

        #expect(spy.hasRecordedAnything == false)
    }

    @Test func disablingMapperReleasesHeldModifiers() async throws {
        let (model, spy) = makeModel()
        model.profile.assign(.modifierHold(.command), toTriggerID: "joycon.l")
        model.handleTestingInput(.lButton(value: 1))

        model.isMapperEnabled = false

        #expect(spy.modifierEvents.last == SpyInputSender.ModifierEvent(modifiers: .command, isPressed: false))
    }

    @Test func deviceDisconnectionReleasesHeldModifiers() async throws {
        let (model, spy) = makeModel()
        model.profile.assign(.modifierHold(.command), toTriggerID: "joycon.l")
        model.handleTestingInput(.lButton(value: 1))

        model.setTestingDevices([])

        #expect(spy.modifierEvents.last == SpyInputSender.ModifierEvent(modifiers: .command, isPressed: false))
    }

    @Test func mouseHoldPressAndRelease() async throws {
        let (model, spy) = makeModel()
        model.profile.assign(.mouseHold(.left), toTriggerID: "joycon.l")

        model.handleTestingInput(.lButton(value: 1))
        model.handleTestingInput(.lButton(value: 0))

        #expect(spy.mouseButtonEvents == [
            SpyInputSender.MouseButtonEvent(button: .left, isPressed: true),
            SpyInputSender.MouseButtonEvent(button: .left, isPressed: false)
        ])
    }

    @Test func disablingMapperReleasesHeldMouseButton() async throws {
        let (model, spy) = makeModel()
        model.profile.assign(.mouseHold(.left), toTriggerID: "joycon.l")
        model.handleTestingInput(.lButton(value: 1))

        model.isMapperEnabled = false

        #expect(spy.mouseButtonEvents.last == SpyInputSender.MouseButtonEvent(button: .left, isPressed: false))
    }

    @Test func deviceDisconnectionReleasesHeldMouseButton() async throws {
        let (model, spy) = makeModel()
        model.profile.assign(.mouseHold(.left), toTriggerID: "joycon.l")
        model.handleTestingInput(.lButton(value: 1))

        model.setTestingDevices([])

        #expect(spy.mouseButtonEvents.last == SpyInputSender.MouseButtonEvent(button: .left, isPressed: false))
    }

    @Test func stopReleasesHeldPushToTalk() async throws {
        let (model, spy) = makeModel()
        model.profile.assign(.pushToTalk(.space), toTriggerID: "joycon.l")
        model.handleTestingInput(.lButton(value: 1))

        model.stop()

        #expect(spy.shortcutHoldEvents.last == SpyInputSender.ShortcutHoldEvent(shortcut: .space, isPressed: false))
    }

    @Test func appWillTerminateReleasesHeldMouseButton() async throws {
        let (model, spy) = makeModel()
        model.profile.assign(.mouseHold(.left), toTriggerID: "joycon.l")
        model.handleTestingInput(.lButton(value: 1))

        model.handleAppWillTerminate()

        #expect(spy.mouseButtonEvents.last == SpyInputSender.MouseButtonEvent(button: .left, isPressed: false))
    }

    @Test func switchingProfileReleasesHeldModifier() async throws {
        let (model, spy) = makeModel()
        model.profile.assign(.modifierHold(.command), toTriggerID: "joycon.l")
        model.handleTestingInput(.lButton(value: 1))

        // Switch to a profile where joycon.l is unmapped while the button is held.
        model.createProfile(named: "Empty")

        #expect(spy.modifierEvents.last == SpyInputSender.ModifierEvent(modifiers: .command, isPressed: false))
    }

    @Test func reassigningHeldTriggerReleasesTheOriginalHold() async throws {
        let (model, spy) = makeModel()
        model.profile.assign(.modifierHold(.command), toTriggerID: "joycon.l")
        model.handleTestingInput(.lButton(value: 1))

        // Reassign the same trigger to a different action while it is held.
        model.assign(.mouseClick(.left), to: "joycon.l")

        #expect(spy.modifierEvents.last == SpyInputSender.ModifierEvent(modifiers: .command, isPressed: false))
    }

    @Test func releaseAfterProfileSwitchDoesNotSendStaleActionForNewProfile() async throws {
        let (model, spy) = makeModel()
        model.profile.assign(.modifierHold(.command), toTriggerID: "joycon.l")
        model.handleTestingInput(.lButton(value: 1))
        model.createProfile(named: "Empty")   // releases the command hold once

        // Releasing the physical button now must not emit any further modifier event.
        model.handleTestingInput(.lButton(value: 0))

        #expect(spy.modifierEvents == [
            SpyInputSender.ModifierEvent(modifiers: .command, isPressed: true),
            SpyInputSender.ModifierEvent(modifiers: .command, isPressed: false)
        ])
    }

    @Test func panicDisableStopsMapperAndReleasesHolds() async throws {
        let (model, spy) = makeModel()
        model.profile.assign(.modifierHold(.command), toTriggerID: "joycon.l")
        model.handleTestingInput(.lButton(value: 1))

        model.panicDisable()

        #expect(model.isMapperEnabled == false)
        #expect(spy.modifierEvents.last == SpyInputSender.ModifierEvent(modifiers: .command, isPressed: false))
    }

    @Test func handleSystemDidWakeKeepsRunning() async throws {
        let (model, _) = makeModel()
        model.start()
        #expect(model.isRunning == true)

        model.handleSystemDidWake()

        #expect(model.isRunning == true)
    }

    private func makeModel() -> (AppModel, SpyInputSender) {
        let spy = SpyInputSender()
        let model = AppModel(configuration: .testing(), inputSender: spy)
        return (model, spy)
    }
}

private extension ControllerInput {
    static func lButton(value: Int) -> ControllerInput {
        ControllerInput(
            deviceID: "test-left",
            deviceName: "Joy-Con (L)",
            control: ControllerControl(
                id: "joycon.l",
                displayName: "L",
                kind: .button,
                usagePage: 0xFF01,
                usage: 0
            ),
            value: value,
            normalizedValue: Double(value),
            timestamp: Date(timeIntervalSince1970: 0)
        )
    }
}
