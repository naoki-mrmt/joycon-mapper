import SnapshotTesting
import Testing
import JoyconMapping

struct MappingProfileSnapshotTests {
    @Test func joyConLeftDefaultAssignments() {
        let summary = MappingProfile.joyConLeftDefault.assignments
            .map { triggerID, action in
                "\(triggerID): \(action.displayName)"
            }
            .sorted()
            .joined(separator: "\n")

        assertSnapshot(
            of: summary,
            as: .lines,
            named: "joycon-left-default-assignments"
        )
    }
}
