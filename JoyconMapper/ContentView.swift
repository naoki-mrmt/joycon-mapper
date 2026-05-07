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

private typealias MappingKeyboardShortcut = JoyconMapping.KeyboardShortcut

private struct MappingTarget: Identifiable, Hashable {
    let triggerID: String
    let displayName: String
    let systemImage: String

    var id: String { triggerID }
}

private let joyConLeftTargets: [MappingTarget] = [
    MappingTarget(triggerID: "joycon.zl", displayName: "ZL", systemImage: "button.horizontal.top.press"),
    MappingTarget(triggerID: "joycon.l", displayName: "L", systemImage: "button.horizontal.top.press"),
    MappingTarget(triggerID: "joycon.sl", displayName: "SL", systemImage: "rectangle.leftthird.inset.filled"),
    MappingTarget(triggerID: "joycon.sr", displayName: "SR", systemImage: "rectangle.rightthird.inset.filled"),
    MappingTarget(triggerID: "joycon.minus", displayName: "Minus", systemImage: "minus"),
    MappingTarget(triggerID: "joycon.capture", displayName: "Capture", systemImage: "camera"),
    MappingTarget(triggerID: "joycon.leftStick", displayName: "Stick Press", systemImage: "circle.dotted.circle"),
    MappingTarget(triggerID: "hat.57.up", displayName: "D-pad Up", systemImage: "arrow.up"),
    MappingTarget(triggerID: "hat.57.down", displayName: "D-pad Down", systemImage: "arrow.down"),
    MappingTarget(triggerID: "hat.57.left", displayName: "D-pad Left", systemImage: "arrow.left"),
    MappingTarget(triggerID: "hat.57.right", displayName: "D-pad Right", systemImage: "arrow.right")
]

struct ContentView: View {
    @ObservedObject var model: AppModel
    @State private var isShowingAccessibilityAlert = false
    @State private var selectedInputID: ControllerInput.ID?
    @State private var recordingTarget: MappingTarget?
    @State private var isShowingInputLog = false

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
                    Text("controller.empty")
                        .foregroundStyle(.secondary)
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
                    Slider(value: $model.mouseSpeed, in: 800...7200, step: 100)
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
                    model.stop()
                    model.start()
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
                ForEach(AppModel.profileOptions) { option in
                    Text(String(localized: String.LocalizationValue(option.nameKey))).tag(option.id)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(14)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
    }

    private var activeProfileName: String {
        guard let option = AppModel.profileOptions.first(where: { $0.id == model.activeProfileID }) else {
            return String(localized: "profile.default")
        }
        return String(localized: String.LocalizationValue(option.nameKey))
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
                    sliderRow("mouse.speed", value: $model.mouseSpeed, range: 800...7200, step: 100)
                    sliderRow("mouse.deadzone", value: $model.mouseDeadzone, range: 0.05...0.45, step: 0.01)
                    sliderRow("mouse.acceleration", value: $model.mouseAcceleration, range: 1.0...2.4, step: 0.05)
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
                Button("log.close") {
                    isShowingInputLog = false
                }
                .keyboardShortcut(.cancelAction)
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
        case .mouseMove(let deltaX, let deltaY):
            if deltaX == 0, deltaY > 0 { String(localized: "action.mouseUp") }
            else if deltaX == 0, deltaY < 0 { String(localized: "action.mouseDown") }
            else if deltaX < 0, deltaY == 0 { String(localized: "action.mouseLeft") }
            else if deltaX > 0, deltaY == 0 { String(localized: "action.mouseRight") }
            else { String(localized: "action.mouseMove") }
        }
    }
}

private struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 14) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 68, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {
                    Text("app.title")
                        .font(.title2.weight(.semibold))
                    Text(AppInfo.versionDisplay)
                        .foregroundStyle(.secondary)
                    Link(destination: AppInfo.repositoryURL) {
                        Label("about.github", systemImage: "arrow.up.right.square")
                    }
                    .font(.caption)
                }

                Spacer()
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("about.license.title")
                    .font(.headline)
                ScrollView {
                    Text(AppInfo.licenseText)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(height: 240)
                .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
            }

            HStack {
                Spacer()
                Button("about.close") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 520)
    }
}

private enum AppInfo {
    static let repositoryURL = URL(string: "https://github.com/naoki-mrmt/joycon-mapper")!

    static var versionDisplay: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "0.3.0"
        let build = info?["CFBundleVersion"] as? String

        if let build, !build.isEmpty {
            return String(format: String(localized: "about.version.build"), version, build)
        }

        return String(format: String(localized: "about.version"), version)
    }

    static var licenseText: String {
        if let url = Bundle.main.url(forResource: "LICENSE", withExtension: "txt"),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            return text
        }

        return "MIT License\n\nCopyright (c) 2026 Naoki Muramoto"
    }
}

private struct ShortcutRecorderSheet: View {
    let target: MappingTarget
    let onRecord: (MappingAction) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var recordedDisplay: String?
    @State private var modifierRecordTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("recorder.title")
                    .font(.title3.weight(.semibold))
                Text(String(format: String(localized: "recorder.subtitle"), target.displayName))
                    .foregroundStyle(.secondary)
            }

            ShortcutCaptureView { shortcut in
                modifierRecordTask?.cancel()
                recordedDisplay = shortcut.displayName
                onRecord(.keyboardShortcut(shortcut))
                dismiss()
            } onModifiersChanged: { modifiers in
                modifierRecordTask?.cancel()
                guard !modifiers.isEmpty else {
                    recordedDisplay = nil
                    return
                }

                recordedDisplay = modifiers.displayName
                modifierRecordTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    guard !Task.isCancelled else { return }
                    onRecord(.modifierHold(modifiers))
                    dismiss()
                }
            }
            .frame(height: 112)
            .background(.quaternary.opacity(0.65), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.separator, lineWidth: 1)
            }
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "keyboard")
                        .font(.title2)
                    Text(recordedDisplay ?? String(localized: "recorder.waiting"))
                        .font(.headline)
                        .monospaced()
                }
            }

            HStack {
                Spacer()
                Button("recorder.cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(22)
        .frame(width: 440)
        .onDisappear {
            modifierRecordTask?.cancel()
        }
    }
}

private struct StickPreview: View {
    let x: Double
    let y: Double

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let radius = size / 2
            let knobSize = max(14, size * 0.18)
            let travel = radius - knobSize / 2 - 6
            let offset = CGSize(width: x * travel, height: -y * travel)

            ZStack {
                Circle()
                    .fill(.background.opacity(0.35))
                Circle()
                    .stroke(.separator, lineWidth: 1)
                Path { path in
                    path.move(to: CGPoint(x: radius, y: 8))
                    path.addLine(to: CGPoint(x: radius, y: size - 8))
                    path.move(to: CGPoint(x: 8, y: radius))
                    path.addLine(to: CGPoint(x: size - 8, y: radius))
                }
                .stroke(.secondary.opacity(0.35), lineWidth: 1)
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: knobSize, height: knobSize)
                    .offset(offset)
                    .shadow(radius: 2)
            }
            .frame(width: size, height: size)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct ShortcutCaptureView: NSViewRepresentable {
    let onShortcut: (MappingKeyboardShortcut) -> Void
    let onModifiersChanged: (MappingKeyboardShortcut.Modifiers) -> Void

    func makeNSView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.onShortcut = onShortcut
        view.onModifiersChanged = onModifiersChanged
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: KeyCaptureView, context: Context) {
        nsView.onShortcut = onShortcut
        nsView.onModifiersChanged = onModifiersChanged
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

private final class KeyCaptureView: NSView {
    var onShortcut: ((MappingKeyboardShortcut) -> Void)?
    var onModifiersChanged: ((MappingKeyboardShortcut.Modifiers) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard let shortcut = MappingKeyboardShortcut(event: event) else {
            return
        }
        onShortcut?(shortcut)
    }

    override func flagsChanged(with event: NSEvent) {
        onModifiersChanged?(MappingKeyboardShortcut.Modifiers(event: event))
    }
}

private extension MappingKeyboardShortcut {
    init?(event: NSEvent) {
        guard let key = ShortcutKeyName.key(for: event) else {
            return nil
        }

        self.init(key: key, modifiers: .init(event: event))
    }
}

private extension MappingKeyboardShortcut.Modifiers {
    init(event: NSEvent) {
        self = []
        if event.modifierFlags.contains(.command) { insert(.command) }
        if event.modifierFlags.contains(.shift) { insert(.shift) }
        if event.modifierFlags.contains(.option) { insert(.option) }
        if event.modifierFlags.contains(.control) { insert(.control) }
    }
}

private enum ShortcutKeyName {
    static func key(for event: NSEvent) -> String? {
        if let namedKey = keysByCode[Int(event.keyCode)] {
            return namedKey
        }

        guard let characters = event.charactersIgnoringModifiers?.lowercased(),
              characters.count == 1,
              let character = characters.first else {
            return nil
        }

        return String(character)
    }

    private static let keysByCode: [Int: String] = [
        36: "return",
        48: "tab",
        49: "space",
        51: "delete",
        53: "escape",
        123: "left",
        124: "right",
        125: "down",
        126: "up"
    ]
}

#Preview {
    ContentView(model: AppModel())
}
