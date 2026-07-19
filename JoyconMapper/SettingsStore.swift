import Foundation
import JoyconMapping

/// Owns all persistence for `AppModel`: UserDefaults key names, profile and
/// profile-option load/save with corruption guards, legacy (v1) migration, the
/// settings snapshot codec, and scalar settings read/write. Extracted from
/// `AppModel` without changing any key names, value types, timing, clamp ranges,
/// corruption-preservation behavior, the format version, or the JSON formatting.
final class SettingsStore {
    typealias ProfileOption = AppModel.ProfileOption
    typealias SettingsSnapshot = AppModel.SettingsSnapshot

    /// Result of loading persisted profile state, mirroring what `AppModel`
    /// assigns to its `@Published` properties. Any needed save-backs (options,
    /// profiles, legacy cleanup) are performed inside `loadProfileState()`.
    struct ProfileState {
        var profiles: [String: MappingProfile]
        var options: [ProfileOption]
        var activeProfileID: String
        var profile: MappingProfile
    }

    private let userDefaults: UserDefaults
    private let legacyProfileStoreKey = "JoyconMapper.MappingProfile.v1"
    private let profilesStoreKey = "JoyconMapper.MappingProfiles.v2"
    private let profileOptionsStoreKey = "JoyconMapper.ProfileOptions.v1"
    private let activeProfileStoreKey = "JoyconMapper.ActiveProfile.v2"
    private let stickMouseEnabledStoreKey = "JoyconMapper.StickMouseEnabled.v1"
    private let mouseSpeedStoreKey = "JoyconMapper.MouseSpeed.v1"
    private let mouseDeadzoneStoreKey = "JoyconMapper.MouseDeadzone.v1"
    private let mouseAccelerationStoreKey = "JoyconMapper.MouseAcceleration.v1"
    private let mouseYInvertedStoreKey = "JoyconMapper.MouseYInverted.v1"
    private let didRequestAccessibilityStoreKey = "JoyconMapper.DidRequestAccessibility.v1"
    private let onboardingCompletedStoreKey = "JoyconMapper.OnboardingCompleted.v1"

    let settingsExportFormatVersion = 1

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    // MARK: - Profiles

    /// Loads persisted profile state, migrating from the legacy (v1) key when
    /// present, and persists back any non-corrupt data. Detects corruption so we
    /// never overwrite recoverable stored data with a silent default reset: when
    /// a stored blob exists but fails to decode we keep the raw data in place and
    /// skip the trailing save for that key.
    func loadProfileState() -> ProfileState {
        var loadedProfiles: [String: MappingProfile] = [:]
        let (loadedOptions, optionsStoreCorrupted) = loadProfileOptions()

        var profilesStoreCorrupted = false
        var loadedFromProfilesStore = false
        var didMigrateLegacy = false

        if let data = userDefaults.data(forKey: profilesStoreKey) {
            if let decoded = try? JSONDecoder().decode([String: MappingProfile].self, from: data) {
                loadedProfiles = decoded
                loadedFromProfilesStore = true
            } else {
                profilesStoreCorrupted = true
            }
        }

        if !loadedFromProfilesStore, !profilesStoreCorrupted,
           let data = userDefaults.data(forKey: legacyProfileStoreKey),
           let decoded = try? JSONDecoder().decode(MappingProfile.self, from: data) {
            loadedProfiles["default"] = decoded
            didMigrateLegacy = true
        }

        for option in loadedOptions where loadedProfiles[option.id] == nil {
            loadedProfiles[option.id] = .joyConLeftDefault
        }

        for key in loadedProfiles.keys {
            loadedProfiles[key]?.removeDPadMouseDefaults()
        }

        let storedProfileID = userDefaults.string(forKey: activeProfileStoreKey) ?? "default"
        let activeProfileID = loadedOptions.contains(where: { $0.id == storedProfileID })
            ? storedProfileID
            : loadedOptions[0].id
        let profile = loadedProfiles[activeProfileID] ?? .joyConLeftDefault

        if !optionsStoreCorrupted {
            saveProfileOptions(loadedOptions)
        }
        if !profilesStoreCorrupted {
            saveProfiles(loadedProfiles)
            // Migration succeeded and was persisted to v2; drop the legacy key so a
            // future corruption can't resurrect stale settings.
            if didMigrateLegacy {
                userDefaults.removeObject(forKey: legacyProfileStoreKey)
            }
        }

        return ProfileState(
            profiles: loadedProfiles,
            options: loadedOptions,
            activeProfileID: activeProfileID,
            profile: profile
        )
    }

    func saveProfiles(_ profiles: [String: MappingProfile]) {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        userDefaults.set(data, forKey: profilesStoreKey)
    }

    /// Returns the stored profile options along with a flag indicating that a
    /// stored blob was present but failed to decode. Callers use the flag to
    /// avoid overwriting corrupt-but-recoverable data with defaults.
    func loadProfileOptions() -> (options: [ProfileOption], storeCorrupted: Bool) {
        guard let data = userDefaults.data(forKey: profileOptionsStoreKey) else {
            return (AppModel.defaultProfileOptions, false)
        }
        guard let decoded = try? JSONDecoder().decode([ProfileOption].self, from: data) else {
            return (AppModel.defaultProfileOptions, true)
        }
        guard !decoded.isEmpty else {
            return (AppModel.defaultProfileOptions, false)
        }
        return (mergedProfileOptions(decoded), false)
    }

    func mergedProfileOptions(_ storedOptions: [ProfileOption]) -> [ProfileOption] {
        // Drop duplicate ids first-wins so imported/loaded data can't produce a
        // Picker with duplicate entries or ambiguous CRUD targets.
        var seenIDs = Set<String>()
        var options = storedOptions.filter { seenIDs.insert($0.id).inserted }
        for builtIn in AppModel.defaultProfileOptions where !options.contains(where: { $0.id == builtIn.id }) {
            options.insert(builtIn, at: min(options.count, AppModel.defaultProfileOptions.count))
        }
        return options
    }

    func saveProfileOptions(_ profileOptions: [ProfileOption]) {
        guard let data = try? JSONEncoder().encode(profileOptions) else { return }
        userDefaults.set(data, forKey: profileOptionsStoreKey)
    }

    // MARK: - Settings snapshot codec

    func encodeSnapshot(_ snapshot: SettingsSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(snapshot)
    }

    func decodeSnapshot(from data: Data) throws -> SettingsSnapshot {
        guard !data.isEmpty else {
            throw SettingsImportError.emptyFile
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot: SettingsSnapshot
        do {
            snapshot = try decoder.decode(SettingsSnapshot.self, from: data)
        } catch {
            throw SettingsImportError.invalidFormat
        }

        guard snapshot.formatVersion == settingsExportFormatVersion else {
            throw SettingsImportError.unsupportedVersion(snapshot.formatVersion)
        }

        return snapshot
    }

    // MARK: - Active profile

    func setActiveProfileID(_ id: String) {
        userDefaults.set(id, forKey: activeProfileStoreKey)
    }

    // MARK: - Scalar settings

    var storedMouseSpeed: Double {
        userDefaults.double(forKey: mouseSpeedStoreKey)
    }

    var storedMouseDeadzone: Double {
        userDefaults.double(forKey: mouseDeadzoneStoreKey)
    }

    var storedMouseAcceleration: Double {
        userDefaults.double(forKey: mouseAccelerationStoreKey)
    }

    var isOnboardingCompleted: Bool {
        userDefaults.bool(forKey: onboardingCompletedStoreKey)
    }

    var didRequestAccessibility: Bool {
        userDefaults.bool(forKey: didRequestAccessibilityStoreKey)
    }

    func storedStickMouseEnabled() -> Bool? {
        guard userDefaults.object(forKey: stickMouseEnabledStoreKey) != nil else { return nil }
        return userDefaults.bool(forKey: stickMouseEnabledStoreKey)
    }

    func storedMouseYInverted() -> Bool? {
        guard userDefaults.object(forKey: mouseYInvertedStoreKey) != nil else { return nil }
        return userDefaults.bool(forKey: mouseYInvertedStoreKey)
    }

    func setStickMouseEnabled(_ isEnabled: Bool) {
        userDefaults.set(isEnabled, forKey: stickMouseEnabledStoreKey)
    }

    func setMouseSpeed(_ speed: Double) {
        userDefaults.set(speed, forKey: mouseSpeedStoreKey)
    }

    func setMouseDeadzone(_ deadzone: Double) {
        userDefaults.set(deadzone, forKey: mouseDeadzoneStoreKey)
    }

    func setMouseAcceleration(_ acceleration: Double) {
        userDefaults.set(acceleration, forKey: mouseAccelerationStoreKey)
    }

    func setMouseYInverted(_ isInverted: Bool) {
        userDefaults.set(isInverted, forKey: mouseYInvertedStoreKey)
    }

    func setOnboardingCompleted(_ isCompleted: Bool) {
        userDefaults.set(isCompleted, forKey: onboardingCompletedStoreKey)
    }

    func setDidRequestAccessibility(_ didRequest: Bool) {
        userDefaults.set(didRequest, forKey: didRequestAccessibilityStoreKey)
    }
}
