import Testing
import CoreGraphics
import MacInput

struct PointerClampTests {
    private let mainDisplay = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    private let sideDisplay = CGRect(x: 1920, y: 0, width: 1440, height: 900)

    @Test func pointInsideDisplayIsUnchanged() {
        let point = CGPoint(x: 100, y: 100)
        #expect(MacInputSender.clampedToDisplays(point, displays: [mainDisplay, sideDisplay]) == point)
    }

    @Test func pointBeyondRightEdgeClampsToNearestDisplay() {
        let point = CGPoint(x: 5000, y: 100)
        let clamped = MacInputSender.clampedToDisplays(point, displays: [mainDisplay, sideDisplay])
        #expect(clamped == CGPoint(x: 3359, y: 100))
    }

    @Test func pointAboveScreenClampsVertically() {
        let point = CGPoint(x: 100, y: -50)
        let clamped = MacInputSender.clampedToDisplays(point, displays: [mainDisplay])
        #expect(clamped == CGPoint(x: 100, y: 0))
    }

    @Test func emptyDisplayListLeavesPointUntouched() {
        let point = CGPoint(x: -999, y: -999)
        #expect(MacInputSender.clampedToDisplays(point, displays: []) == point)
    }
}
