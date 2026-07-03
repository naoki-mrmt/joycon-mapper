import Testing
import Foundation
import JoyconMapping
import MacInput

struct KeyCodeShortcutTests {
    @Test func shortcutKeyCodeRoundTripsThroughJSON() throws {
        var profile = MappingProfile()
        profile.assign(
            .keyboardShortcut(KeyboardShortcut(key: "a", modifiers: [.command], keyCode: 99)),
            toTriggerID: "joycon.l"
        )

        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(MappingProfile.self, from: data)

        #expect(decoded == profile)
        guard case .keyboardShortcut(let shortcut) = decoded.action(forTriggerID: "joycon.l") else {
            Issue.record("Expected a keyboard shortcut action.")
            return
        }
        #expect(shortcut.keyCode == 99)
        #expect(shortcut.key == "a")
        #expect(shortcut.modifiers == [.command])
    }

    @Test func legacyShortcutJSONDecodesWithNilKeyCode() throws {
        let json = #"{"assignments":{"joycon.l":{"keyboardShortcut":{"_0":{"key":"a","modifiers":1}}}}}"#
        let data = Data(json.utf8)

        let decoded = try JSONDecoder().decode(MappingProfile.self, from: data)

        guard case .keyboardShortcut(let shortcut) = decoded.action(forTriggerID: "joycon.l") else {
            Issue.record("Expected a keyboard shortcut action.")
            return
        }
        #expect(shortcut.keyCode == nil)
        #expect(shortcut.key == "a")
        #expect(shortcut.modifiers == [.command])
    }

    @Test func resolvedKeyCodePrefersStoredCode() {
        let stored = KeyboardShortcut(key: "a", modifiers: [], keyCode: 99)
        #expect(MacInputSender.resolvedKeyCode(for: stored) == 99)

        let fallback = KeyboardShortcut(key: "a")
        #expect(MacInputSender.resolvedKeyCode(for: fallback) == 0)
    }
}
