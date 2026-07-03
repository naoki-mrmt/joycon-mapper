import Testing
import Foundation
@testable import JoyconMapper
import JoyconMapping

@MainActor
struct AccessibilityTrustTests {

    @Test func refreshAccessibilityTrustPublishesChange() async throws {
        let spy = SpyInputSender()
        spy.isAccessibilityTrusted = false
        let configuration = AppModel.Configuration(
            userDefaults: UserDefaults(suiteName: "JoyconMapper.Tests.\(UUID().uuidString)")!,
            isHardwareEnabled: false,
            accessibilityTrustedOverride: nil
        )
        let model = AppModel(configuration: configuration, inputSender: spy)

        #expect(model.isAccessibilityTrusted == false)

        spy.isAccessibilityTrusted = true
        model.refreshAccessibilityTrust()

        #expect(model.isAccessibilityTrusted == true)
    }
}
