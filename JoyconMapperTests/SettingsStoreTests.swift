//
//  SettingsStoreTests.swift
//  JoyconMapperTests
//
//  Directly verifies the persistence behavior extracted into SettingsStore:
//  profile/options round-trip, corruption non-overwrite, legacy migration and
//  cleanup, and the settings snapshot codec.
//

import Testing
import Foundation
@testable import JoyconMapper
import JoyconMapping

struct SettingsStoreTests {

    private static let profilesStoreKey = "JoyconMapper.MappingProfiles.v2"
    private static let legacyProfileStoreKey = "JoyconMapper.MappingProfile.v1"
    private static let profileOptionsStoreKey = "JoyconMapper.ProfileOptions.v1"

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "JoyconMapper.Tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    // MARK: - Profiles round-trip

    @Test func savesAndReloadsProfiles() throws {
        let defaults = try makeDefaults()
        let store = SettingsStore(userDefaults: defaults)

        var profile = MappingProfile()
        profile.assign(.mouseClick(.right), toTriggerID: "joycon.l")
        store.saveProfiles(["default": profile])

        let state = store.loadProfileState()
        #expect(state.profiles["default"]?.action(forTriggerID: "joycon.l") == .mouseClick(.right))
        #expect(state.activeProfileID == "default")
    }

    // MARK: - Profile options round-trip and merge

    @Test func savesAndReloadsProfileOptionsWithMerge() throws {
        let defaults = try makeDefaults()
        let store = SettingsStore(userDefaults: defaults)

        let custom = AppModel.ProfileOption(id: "custom-1", name: "Custom", nameKey: nil, isBuiltIn: false)
        store.saveProfileOptions([custom])

        let (options, corrupted) = store.loadProfileOptions()
        #expect(!corrupted)
        // Built-in options are re-inserted alongside the stored custom option.
        #expect(options.contains(where: { $0.id == "custom-1" }))
        #expect(options.contains(where: { $0.id == "default" }))
    }

    @Test func mergedProfileOptionsDropsDuplicateIDsAndFillsBuiltIns() throws {
        let defaults = try makeDefaults()
        let store = SettingsStore(userDefaults: defaults)

        let custom = AppModel.ProfileOption(id: "custom-1", name: "Custom", nameKey: nil, isBuiltIn: false)
        let merged = store.mergedProfileOptions([custom, custom])

        let ids = merged.map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(merged.contains(where: { $0.id == "default" }))
        #expect(merged.contains(where: { $0.id == "browsing" }))
        #expect(merged.contains(where: { $0.id == "meeting" }))
    }

    // MARK: - Corruption resistance

    @Test func corruptProfilesStoreIsNotOverwritten() throws {
        let defaults = try makeDefaults()
        let garbage = Data("garbage".utf8)
        defaults.set(garbage, forKey: Self.profilesStoreKey)

        let store = SettingsStore(userDefaults: defaults)
        let state = store.loadProfileState()

        #expect(state.activeProfileID == "default")
        #expect(state.options.contains(where: { $0.id == "default" }))
        // The corrupt blob is left untouched, preserving recovery room.
        #expect(defaults.data(forKey: Self.profilesStoreKey) == garbage)
    }

    @Test func corruptOptionsStoreIsNotOverwritten() throws {
        let defaults = try makeDefaults()
        let garbage = Data("garbage".utf8)
        defaults.set(garbage, forKey: Self.profileOptionsStoreKey)

        let store = SettingsStore(userDefaults: defaults)
        let (options, corrupted) = store.loadProfileOptions()

        #expect(corrupted)
        #expect(options == AppModel.defaultProfileOptions)

        _ = store.loadProfileState()
        // The corrupt options blob is left untouched.
        #expect(defaults.data(forKey: Self.profileOptionsStoreKey) == garbage)
    }

    // MARK: - Legacy migration

    @Test func legacyProfileMigratesAndClearsLegacyKey() throws {
        let defaults = try makeDefaults()
        var legacyProfile = MappingProfile()
        legacyProfile.assign(.mouseClick(.right), toTriggerID: "joycon.l")
        let legacyData = try JSONEncoder().encode(legacyProfile)
        defaults.set(legacyData, forKey: Self.legacyProfileStoreKey)

        let store = SettingsStore(userDefaults: defaults)
        let state = store.loadProfileState()

        #expect(state.profiles["default"]?.action(forTriggerID: "joycon.l") == .mouseClick(.right))
        #expect(defaults.data(forKey: Self.legacyProfileStoreKey) == nil)
        // Migration was persisted to the v2 key.
        #expect(defaults.data(forKey: Self.profilesStoreKey) != nil)
    }

    // MARK: - Snapshot codec

    private func makeSnapshot(formatVersion: Int) -> AppModel.SettingsSnapshot {
        var profile = MappingProfile()
        profile.assign(.mouseClick(.right), toTriggerID: "joycon.l")
        return AppModel.SettingsSnapshot(
            formatVersion: formatVersion,
            exportedAt: Date(timeIntervalSince1970: 1_000_000),
            activeProfileID: "default",
            profileOptions: AppModel.defaultProfileOptions,
            profiles: ["default": profile],
            isStickMouseEnabled: false,
            mouseSpeed: 4200,
            mouseDeadzone: 0.16,
            mouseAcceleration: 1.45,
            isMouseYInverted: true
        )
    }

    @Test func snapshotEncodeDecodeRoundTrips() throws {
        let defaults = try makeDefaults()
        let store = SettingsStore(userDefaults: defaults)

        let snapshot = makeSnapshot(formatVersion: store.settingsExportFormatVersion)
        let data = try store.encodeSnapshot(snapshot)
        let decoded = try store.decodeSnapshot(from: data)

        #expect(decoded == snapshot)
    }

    @Test func decodeEmptyDataThrowsEmptyFile() throws {
        let defaults = try makeDefaults()
        let store = SettingsStore(userDefaults: defaults)

        #expect(throws: SettingsImportError.emptyFile) {
            _ = try store.decodeSnapshot(from: Data())
        }
    }

    @Test func decodeInvalidDataThrowsInvalidFormat() throws {
        let defaults = try makeDefaults()
        let store = SettingsStore(userDefaults: defaults)

        #expect(throws: SettingsImportError.invalidFormat) {
            _ = try store.decodeSnapshot(from: Data("garbage".utf8))
        }
    }

    @Test func decodeUnsupportedVersionThrows() throws {
        let defaults = try makeDefaults()
        let store = SettingsStore(userDefaults: defaults)

        let snapshot = makeSnapshot(formatVersion: 999)
        let data = try store.encodeSnapshot(snapshot)

        #expect(throws: SettingsImportError.unsupportedVersion(999)) {
            _ = try store.decodeSnapshot(from: data)
        }
    }

    // MARK: - Scalar settings

    @Test func scalarSettersAndGettersRoundTrip() throws {
        let defaults = try makeDefaults()
        let store = SettingsStore(userDefaults: defaults)

        #expect(store.storedStickMouseEnabled() == nil)
        #expect(store.storedMouseYInverted() == nil)

        store.setStickMouseEnabled(false)
        store.setMouseSpeed(1234)
        store.setMouseDeadzone(0.2)
        store.setMouseAcceleration(1.8)
        store.setMouseYInverted(true)
        store.setOnboardingCompleted(true)
        store.setDidRequestAccessibility(true)

        #expect(store.storedStickMouseEnabled() == false)
        #expect(store.storedMouseSpeed == 1234)
        #expect(store.storedMouseDeadzone == 0.2)
        #expect(store.storedMouseAcceleration == 1.8)
        #expect(store.storedMouseYInverted() == true)
        #expect(store.isOnboardingCompleted == true)
        #expect(store.didRequestAccessibility == true)
    }
}
