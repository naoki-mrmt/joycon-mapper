//
//  ContentView.swift
//  JoyconMapper
//
//  Created by Naoki Muramoto on 2026/05/07.
//

import SwiftUI
import AppKit
import JoyconHID
import JoyconMapping
import UniformTypeIdentifiers

struct MappingTarget: Identifiable, Hashable {
    let triggerID: String
    let displayName: String
    let systemImage: String

    var id: String { triggerID }

    init(triggerID: String, displayNameKey: String, systemImage: String) {
        self.init(
            triggerID: triggerID,
            displayName: String(localized: String.LocalizationValue(displayNameKey)),
            systemImage: systemImage
        )
    }

    init(triggerID: String, displayName: String, systemImage: String) {
        self.triggerID = triggerID
        self.displayName = displayName
        self.systemImage = systemImage
    }
}

private let joyConLeftTargets: [MappingTarget] = [
    MappingTarget(triggerID: "joycon.zl", displayNameKey: "target.zl", systemImage: "button.horizontal.top.press"),
    MappingTarget(triggerID: "joycon.l", displayNameKey: "target.l", systemImage: "button.horizontal.top.press"),
    MappingTarget(triggerID: "joycon.sl", displayNameKey: "target.sl", systemImage: "rectangle.leftthird.inset.filled"),
    MappingTarget(triggerID: "joycon.sr", displayNameKey: "target.sr", systemImage: "rectangle.rightthird.inset.filled"),
    MappingTarget(triggerID: "joycon.minus", displayNameKey: "target.minus", systemImage: "minus"),
    MappingTarget(triggerID: "joycon.capture", displayNameKey: "target.capture", systemImage: "camera"),
    MappingTarget(triggerID: "joycon.leftStick", displayNameKey: "target.leftStickPress", systemImage: "circle.dotted.circle"),
    MappingTarget(triggerID: "hat.57.up", displayNameKey: "target.dpadUp", systemImage: "arrow.up"),
    MappingTarget(triggerID: "hat.57.down", displayNameKey: "target.dpadDown", systemImage: "arrow.down"),
    MappingTarget(triggerID: "hat.57.left", displayNameKey: "target.dpadLeft", systemImage: "arrow.left"),
    MappingTarget(triggerID: "hat.57.right", displayNameKey: "target.dpadRight", systemImage: "arrow.right")
]

struct ContentView: View {
    @ObservedObject var model: AppModel
    @State private var isShowingAccessibilityAlert = false
    @State private var selectedInputID: ControllerInput.ID?
    @State private var recordingTarget: MappingTarget?
    @State private var isShowingInputLog = false
    @State private var isShowingNewProfileDialog = false
    @State private var isShowingRenameProfileDialog = false
    @State private var isShowingDeleteProfileConfirmation = false
    @State private var isShowingResetProfileConfirmation = false
    @State private var isShowingSettingsImporter = false
    @State private var isShowingSettingsExporter = false
    @State private var settingsExportDocument = SettingsExportDocument(data: Data())
    @State private var settingsAlertMessage: String?
    @State private var profileNameDraft = ""

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .onAppear {
            isShowingAccessibilityAlert = model.shouldShowAccessibilityPrompt
            model.refreshLaunchAtLoginStatus()
        }
        .alert("accessibility.alert.title", isPresented: $isShowingAccessibilityAlert) {
            Button("accessibility.alert.openSettings") {
                model.requestAccessibilityPermission()
            }
            Button("accessibility.alert.later", role: .cancel) {}
        } message: {
            Text("accessibility.alert.message")
        }
        .sheet(item: $recordingTarget) { target in
            ShortcutRecorderSheet(target: target) { action in
                model.assign(action, to: target.triggerID)
                recordingTarget = nil
            }
        }
        .sheet(isPresented: $isShowingInputLog) {
            inputLogSheet
        }
        .sheet(isPresented: $model.isShowingAbout) {
            AboutView()
        }
        .fileImporter(
            isPresented: $isShowingSettingsImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            importSettings(from: result)
        }
        .fileExporter(
            isPresented: $isShowingSettingsExporter,
            document: settingsExportDocument,
            contentType: .json,
            defaultFilename: "JoyconMapper-Settings"
        ) { result in
            if case .failure(let error) = result {
                settingsAlertMessage = error.localizedDescription
            }
        }
        .alert("profile.new.title", isPresented: $isShowingNewProfileDialog) {
            TextField("profile.name.placeholder", text: $profileNameDraft)
            Button("profile.create") {
                model.createProfile(named: profileNameDraft)
                profileNameDraft = ""
            }
            Button("profile.cancel", role: .cancel) {
                profileNameDraft = ""
            }
        } message: {
            Text("profile.new.message")
        }
        .alert("profile.rename.title", isPresented: $isShowingRenameProfileDialog) {
            TextField("profile.name.placeholder", text: $profileNameDraft)
            Button("profile.rename") {
                model.renameActiveProfile(to: profileNameDraft)
                profileNameDraft = ""
            }
            Button("profile.cancel", role: .cancel) {
                profileNameDraft = ""
            }
        } message: {
            Text("profile.rename.message")
        }
        .alert("profile.delete.title", isPresented: $isShowingDeleteProfileConfirmation) {
            Button("profile.delete", role: .destructive) {
                model.deleteActiveProfile()
            }
            Button("profile.cancel", role: .cancel) {}
        } message: {
            Text(String(format: String(localized: "profile.delete.message"), activeProfileName))
        }
        .alert("profile.reset.title", isPresented: $isShowingResetProfileConfirmation) {
            Button("profile.reset", role: .destructive) {
                model.resetActiveProfileToDefaults()
            }
            Button("profile.cancel", role: .cancel) {}
        } message: {
            Text(String(format: String(localized: "profile.reset.message"), activeProfileName))
        }
        .alert("settings.alert.title", isPresented: Binding(
            get: { settingsAlertMessage != nil },
            set: { if !$0 { settingsAlertMessage = nil } }
        )) {
            Button("settings.alert.ok", role: .cancel) {
                settingsAlertMessage = nil
            }
        } message: {
            Text(settingsAlertMessage ?? "")
        }
        .accessibilityIdentifier("contentView")
    }

    private var sidebar: some View {
        List {
            Section("section.status") {
                statusRow(
                    title: String(localized: "status.mapper"),
                    value: model.isMapperEnabled ? String(localized: "status.enabled") : String(localized: "status.paused"),
                    systemImage: model.isMapperEnabled ? "play.circle.fill" : "pause.circle"
                )
                statusRow(
                    title: String(localized: "status.joycon"),
                    value: model.devices.isEmpty ? String(localized: "status.notConnected") : String(format: String(localized: "status.connected.count"), model.devices.count),
                    systemImage: model.devices.isEmpty ? "gamecontroller" : "gamecontroller.fill"
                )
                statusRow(
                    title: String(localized: "status.accessibility"),
                    value: model.isAccessibilityTrusted ? String(localized: "status.allowed") : String(localized: "status.needsPermission"),
                    systemImage: model.isAccessibilityTrusted ? "checkmark.shield.fill" : "exclamationmark.shield"
                )
            }

            Section("section.controller") {
                if model.devices.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("controller.empty")
                            .foregroundStyle(.secondary)
                        Text("controller.autoReconnect")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(model.devices) { device in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(device.name)
                                .font(.body.weight(.medium))
                            Text("\(device.transport) / \(device.displayProductID)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("section.mouse") {
                Toggle("mouse.leftStick", isOn: $model.isStickMouseEnabled)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("mouse.speed", systemImage: "speedometer")
                        Spacer()
                        Text("\(Int(model.mouseSpeed))")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $model.mouseSpeed, in: Tuning.mouseSpeedRange, step: Tuning.mouseSpeedStep)
                }
            }

            Section("section.app") {
                Toggle("app.mapperEnabled", isOn: $model.isMapperEnabled)
                Toggle("app.launchAtLogin", isOn: Binding(
                    get: { model.isLaunchAtLoginEnabled },
                    set: { model.setLaunchAtLoginEnabled($0) }
                ))
                if let error = model.launchAtLoginError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Button {
                    model.isShowingAbout = true
                } label: {
                    Label("app.about", systemImage: "info.circle")
                }
                if !model.isAccessibilityTrusted {
                    Button {
                        model.requestAccessibilityPermission()
                    } label: {
                        Label("app.allowAccessibility", systemImage: "lock.open")
                    }
                }
                Button {
                    model.reconnect()
                } label: {
                    Label("app.reconnect", systemImage: "arrow.trianglehead.2.clockwise")
                }
            }
        }
        .navigationTitle("app.title")
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            if !model.isOnboardingCompleted {
                onboardingPanel
            }
            profilePanel
            stickPanel
            keyList
        }
        .padding(20)
        .navigationTitle("window.inputMonitor")
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("header.title")
                    .font(.title2.weight(.semibold))
                Text("header.subtitle")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let lastError = model.lastError {
                Label(lastError, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            } else {
                VStack(alignment: .trailing, spacing: 8) {
                    statusBadge
                    Text(String(format: String(localized: "status.assignments.count"), model.profile.assignments.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        isShowingInputLog = true
                    } label: {
                        Label("log.open", systemImage: "list.bullet.rectangle")
                    }
                    .controlSize(.small)
                    .accessibilityIdentifier("inputLogButton")
                }
            }
        }
    }

    private var statusBadge: some View {
        let status = mapperStatus
        return Label {
            Text(status.title)
                .font(.caption.weight(.semibold))
        } icon: {
            Image(systemName: status.systemImage)
        }
        .foregroundStyle(status.tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(status.tint.opacity(0.14), in: Capsule())
    }

    private var mapperStatus: (title: String, systemImage: String, tint: Color) {
        if !model.isMapperEnabled {
            return (String(localized: "status.ready.paused"), "pause.circle.fill", .secondary)
        }

        if !model.isAccessibilityTrusted {
            return (String(localized: "status.ready.needsPermission"), "exclamationmark.shield.fill", .orange)
        }

        if model.devices.isEmpty {
            return (String(localized: "status.ready.noJoycon"), "gamecontroller", .orange)
        }

        return (String(localized: "status.ready.ok"), "checkmark.circle.fill", .green)
    }

    private var onboardingPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("onboarding.title", systemImage: "wand.and.sparkles")
                    .font(.headline)
                Spacer()
                Button("onboarding.done") {
                    model.isOnboardingCompleted = true
                }
                .controlSize(.small)
            }

            Text("onboarding.subtitle")
                .foregroundStyle(.secondary)

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                onboardingRow(
                    isComplete: model.isAccessibilityTrusted,
                    titleKey: "onboarding.accessibility",
                    detailKey: "onboarding.accessibility.detail"
                )
                onboardingRow(
                    isComplete: !model.devices.isEmpty,
                    titleKey: "onboarding.connect",
                    detailKey: "onboarding.connect.detail"
                )
                onboardingRow(
                    isComplete: model.isStickMouseEnabled,
                    titleKey: "onboarding.stick",
                    detailKey: "onboarding.stick.detail"
                )
                onboardingRow(
                    isComplete: !model.profile.assignments.isEmpty,
                    titleKey: "onboarding.mapping",
                    detailKey: "onboarding.mapping.detail"
                )
            }
        }
        .padding(14)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor.opacity(0.22), lineWidth: 1)
        }
    }

    private func onboardingRow(
        isComplete: Bool,
        titleKey: LocalizedStringKey,
        detailKey: LocalizedStringKey
    ) -> some View {
        GridRow {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isComplete ? Color.green : Color.secondary)
            Text(titleKey)
                .font(.body.weight(.medium))
            Text(detailKey)
                .foregroundStyle(.secondary)
        }
    }

    private var profilePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("profile.title", systemImage: "rectangle.3.group")
                    .font(.headline)
                Spacer()
                Text(activeProfileName)
                    .foregroundStyle(.secondary)
            }

            Picker("profile.title", selection: $model.activeProfileID) {
                ForEach(model.profileOptions) { option in
                    Text(profileDisplayName(option)).tag(option.id)
                }
            }
            .pickerStyle(.menu)

            HStack(spacing: 8) {
                Button {
                    profileNameDraft = String(localized: "profile.new.defaultName")
                    isShowingNewProfileDialog = true
                } label: {
                    Label("profile.new", systemImage: "plus")
                }

                Button {
                    model.duplicateActiveProfile()
                } label: {
                    Label("profile.duplicate", systemImage: "plus.square.on.square")
                }

                Button {
                    profileNameDraft = activeProfileName
                    isShowingRenameProfileDialog = true
                } label: {
                    Label("profile.rename", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    isShowingDeleteProfileConfirmation = true
                } label: {
                    Label("profile.delete", systemImage: "trash")
                }
                .disabled(!canDeleteActiveProfile)

                Button {
                    isShowingResetProfileConfirmation = true
                } label: {
                    Label("profile.reset", systemImage: "arrow.counterclockwise")
                }

                Spacer()
            }
            .controlSize(.small)

            Divider()

            HStack(spacing: 8) {
                Button {
                    exportSettings()
                } label: {
                    Label("settings.export", systemImage: "square.and.arrow.up")
                }

                Button {
                    isShowingSettingsImporter = true
                } label: {
                    Label("settings.import", systemImage: "square.and.arrow.down")
                }

                Spacer()
            }
            .controlSize(.small)
        }
        .padding(14)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
    }

    private var activeProfileName: String {
        guard let option = model.profileOptions.first(where: { $0.id == model.activeProfileID }) else {
            return String(localized: "profile.default")
        }
        return profileDisplayName(option)
    }

    private var canDeleteActiveProfile: Bool {
        guard let option = model.profileOptions.first(where: { $0.id == model.activeProfileID }) else {
            return false
        }
        return !option.isBuiltIn && model.profileOptions.count > 1
    }

    private func profileDisplayName(_ option: AppModel.ProfileOption) -> String {
        if let nameKey = option.nameKey {
            return String(localized: String.LocalizationValue(nameKey))
        }
        return option.name
    }

    private var stickPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("stick.title", systemImage: "circle.grid.cross")
                    .font(.headline)
                Spacer()
                Toggle("stick.enabled", isOn: $model.isStickMouseEnabled)
                    .toggleStyle(.switch)
            }

            HStack(alignment: .center, spacing: 18) {
                StickPreview(x: model.visibleStickX, y: model.visibleStickY)
                    .frame(width: 92, height: 92)

                VStack(alignment: .leading, spacing: 10) {
                    sliderRow("mouse.speed", value: $model.mouseSpeed, range: Tuning.mouseSpeedRange, step: Tuning.mouseSpeedStep)
                    sliderRow("mouse.deadzone", value: $model.mouseDeadzone, range: Tuning.mouseDeadzoneRange, step: 0.01)
                    sliderRow("mouse.acceleration", value: $model.mouseAcceleration, range: Tuning.mouseAccelerationRange, step: 0.05)
                    Toggle("mouse.invertY", isOn: $model.isMouseYInverted)
                }
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
    }

    private func sliderRow(
        _ titleKey: LocalizedStringKey,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        HStack {
            Text(titleKey)
                .frame(width: 100, alignment: .leading)
            Slider(value: value, in: range, step: step)
            Text(value.wrappedValue.formatted(.number.precision(.fractionLength(step < 1 ? 2 : 0))))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .trailing)
        }
    }

    private var keyList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("keys.title")
                    .font(.headline)
                Spacer()
                Text("keys.subtitle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Table(joyConLeftTargets) {
                TableColumn(String(localized: "keys.input")) { target in
                    HStack(spacing: 8) {
                        pressedIndicator(for: target)
                        Label(target.displayName, systemImage: target.systemImage)
                        Text(target.triggerID)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                TableColumn(String(localized: "keys.action")) { target in
                    HStack {
                        assignmentMenu(for: target) {
                            Label(actionDisplayName(model.profile.action(forTriggerID: target.triggerID)), systemImage: "slider.horizontal.3")
                        }
                        .menuStyle(.borderlessButton)
                        Spacer()
                        if model.profile.action(forTriggerID: target.triggerID) != .none {
                            Button {
                                model.clearAssignment(for: target.triggerID)
                            } label: {
                                Image(systemName: "xmark.circle")
                            }
                            .buttonStyle(.plain)
                            .help("action.clear")
                        }
                    }
                }
            }
        }
    }

    private func pressedIndicator(for target: MappingTarget) -> some View {
        Circle()
            .fill(model.pressedTriggerIDs.contains(target.triggerID) ? Color.green : Color.secondary.opacity(0.35))
            .frame(width: 8, height: 8)
    }

    private var inputLogSheet: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("log.title")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("log.clear") {
                    model.clearRecentInputs()
                }
                .disabled(model.recentInputs.isEmpty)
                .accessibilityIdentifier("clearInputLogButton")
                Button("log.close") {
                    isShowingInputLog = false
                }
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("closeInputLogButton")
            }

            Table(model.recentInputs, selection: $selectedInputID) {
                TableColumn(String(localized: "log.control")) { input in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(input.triggerDisplayName)
                        Text(input.triggerID)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                TableColumn(String(localized: "log.value")) { input in
                    Text("\(input.value)")
                        .monospacedDigit()
                }
                TableColumn(String(localized: "log.mappedAction")) { input in
                    HStack {
                        assignmentMenu(for: MappingTarget(triggerID: input.triggerID, displayName: input.triggerDisplayName, systemImage: "smallcircle.filled.circle")) {
                            Label(actionDisplayName(model.action(for: input)), systemImage: "slider.horizontal.3")
                        }
                        .menuStyle(.borderlessButton)
                        Spacer()
                        if model.action(for: input) != .none {
                            Button {
                                model.clearAssignment(for: input.triggerID)
                            } label: {
                                Image(systemName: "xmark.circle")
                            }
                            .buttonStyle(.plain)
                            .help("action.clear")
                        }
                    }
                }
                TableColumn(String(localized: "log.device")) { input in
                    Text(input.deviceName)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 780, minHeight: 480)
        .accessibilityIdentifier("inputLogSheet")
    }

    private func assignmentMenu<LabelContent: View>(
        for target: MappingTarget,
        @ViewBuilder label: () -> LabelContent
    ) -> some View {
        Menu {
            Button {
                model.assign(.none, to: target.triggerID)
            } label: {
                Label("action.none", systemImage: "minus.circle")
            }

            Divider()

            Section("action.group.mouse") {
                Button {
                    model.assign(.mouseClick(.left), to: target.triggerID)
                } label: {
                    Label("action.leftClick", systemImage: "cursorarrow.click")
                }

                Button {
                    model.assign(.mouseClick(.right), to: target.triggerID)
                } label: {
                    Label("action.rightClick", systemImage: "contextualmenu.and.cursorarrow")
                }

                Button {
                    model.assign(.mouseHold(.left), to: target.triggerID)
                } label: {
                    Label("action.holdLeftClick", systemImage: "cursorarrow.and.square.on.square.dashed")
                }
            }

            Section("action.group.scroll") {
                Button {
                    model.assign(.scroll(deltaX: 0, deltaY: MappingDefaults.scrollStep), to: target.triggerID)
                } label: {
                    Label("action.scrollUp", systemImage: "arrow.up")
                }

                Button {
                    model.assign(.scroll(deltaX: 0, deltaY: -MappingDefaults.scrollStep), to: target.triggerID)
                } label: {
                    Label("action.scrollDown", systemImage: "arrow.down")
                }

                Button {
                    model.assign(.scroll(deltaX: -MappingDefaults.scrollStep, deltaY: 0), to: target.triggerID)
                } label: {
                    Label("action.scrollLeft", systemImage: "arrow.left")
                }

                Button {
                    model.assign(.scroll(deltaX: MappingDefaults.scrollStep, deltaY: 0), to: target.triggerID)
                } label: {
                    Label("action.scrollRight", systemImage: "arrow.right")
                }
            }

            Section("action.group.modifiers") {
                Button {
                    model.assign(.modifierHold(.command), to: target.triggerID)
                } label: {
                    Label("action.holdCommand", systemImage: "command")
                }

                Button {
                    model.assign(.modifierHold(.option), to: target.triggerID)
                } label: {
                    Label("action.holdOption", systemImage: "option")
                }

                Button {
                    model.assign(.modifierHold(.shift), to: target.triggerID)
                } label: {
                    Label("action.holdShift", systemImage: "shift")
                }

                Button {
                    model.assign(.modifierHold([.option, .command]), to: target.triggerID)
                } label: {
                    Label("action.holdOptionCommand", systemImage: "command")
                }
            }

            Divider()

            Button {
                recordingTarget = target
            } label: {
                Label("action.recordShortcut", systemImage: "keyboard")
            }

            Section("action.group.navigation") {
                Button {
                    model.assign(.keyboardShortcut(.escape), to: target.triggerID)
                } label: {
                    Label("action.escape", systemImage: "escape")
                }

                Button {
                    model.assign(.keyboardShortcut(.return), to: target.triggerID)
                } label: {
                    Label("action.return", systemImage: "return")
                }

                Button {
                    model.assign(.keyboardShortcut(.tab), to: target.triggerID)
                } label: {
                    Label("action.tab", systemImage: "arrow.right.to.line")
                }

                Button {
                    model.assign(.keyboardShortcut(.shiftTab), to: target.triggerID)
                } label: {
                    Label("action.shiftTab", systemImage: "arrow.left.to.line")
                }

                Button {
                    model.assign(.keyboardShortcut(.space), to: target.triggerID)
                } label: {
                    Label("action.space", systemImage: "space")
                }

                Button {
                    model.assign(.keyboardShortcut(.delete), to: target.triggerID)
                } label: {
                    Label("action.delete", systemImage: "delete.left")
                }
            }
        } label: {
            label()
        }
    }

    private func statusRow(title: String, value: String, systemImage: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private func actionDisplayName(_ action: MappingAction) -> String {
        switch action {
        case .none:
            String(localized: "action.none")
        case .keyboardShortcut(let shortcut):
            shortcut.displayName
        case .modifierHold(let modifiers):
            String(format: String(localized: "action.holdModifiers"), modifiers.displayName)
        case .pushToTalk(let shortcut):
            String(format: String(localized: "action.pushToTalk"), shortcut.displayName)
        case .mouseClick(let button):
            switch button {
            case .left:
                String(localized: "action.leftClick")
            case .right:
                String(localized: "action.rightClick")
            }
        case .mouseHold(let button):
            switch button {
            case .left:
                String(localized: "action.holdLeftClick")
            case .right:
                String(localized: "action.holdRightClick")
            }
        case .mouseMove(let deltaX, let deltaY):
            if deltaX == 0, deltaY > 0 { String(localized: "action.mouseUp") }
            else if deltaX == 0, deltaY < 0 { String(localized: "action.mouseDown") }
            else if deltaX < 0, deltaY == 0 { String(localized: "action.mouseLeft") }
            else if deltaX > 0, deltaY == 0 { String(localized: "action.mouseRight") }
            else { String(localized: "action.mouseMove") }
        case .scroll(let deltaX, let deltaY):
            if deltaX == 0, deltaY > 0 { String(localized: "action.scrollUp") }
            else if deltaX == 0, deltaY < 0 { String(localized: "action.scrollDown") }
            else if deltaX < 0, deltaY == 0 { String(localized: "action.scrollLeft") }
            else if deltaX > 0, deltaY == 0 { String(localized: "action.scrollRight") }
            else { String(localized: "action.scroll") }
        }
    }

    private func exportSettings() {
        do {
            settingsExportDocument = SettingsExportDocument(data: try model.exportSettingsData())
            isShowingSettingsExporter = true
        } catch {
            settingsAlertMessage = error.localizedDescription
        }
    }

    private func importSettings(from result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let canAccess = url.startAccessingSecurityScopedResource()
            defer {
                if canAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            try model.importSettingsData(Data(contentsOf: url))
            settingsAlertMessage = String(localized: "settings.import.success")
        } catch {
            settingsAlertMessage = error.localizedDescription
        }
    }
}

#Preview {
    ContentView(model: AppModel())
}
