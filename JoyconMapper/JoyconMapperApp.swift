//
//  JoyconMapperApp.swift
//  JoyconMapper
//
//  Created by Naoki Muramoto on 2026/05/07.
//

import AppKit
import SwiftUI

@main
struct JoyconMapperApp: App {
    @StateObject private var model: AppModel

    init() {
        let processInfo = ProcessInfo.processInfo
        let isUITesting = processInfo.arguments.contains("--ui-testing")
            || processInfo.environment["JOYCON_MAPPER_TESTING"] == "1"
        _model = StateObject(wrappedValue: AppModel(
            configuration: isUITesting ? .testing(suiteName: "JoyconMapper.UITests") : .live
        ))
    }

    var body: some Scene {
        WindowGroup(String(localized: "app.title"), id: "main") {
            ContentView(model: model)
                .frame(minWidth: 820, minHeight: 560)
                .onAppear {
                    model.start()
                }
        }

        MenuBarExtra(menuBarTitle, systemImage: menuBarSystemImage) {
            MenuBarContentView(model: model)
        }
    }

    private var menuBarTitle: String {
        if model.lastError != nil {
            return String(localized: "menubar.error")
        }

        if !model.isMapperEnabled {
            return String(localized: "menubar.paused")
        }

        if !model.isAccessibilityTrusted {
            return String(localized: "menubar.needsPermission")
        }

        if model.devices.isEmpty {
            return String(localized: "menubar.noJoycon")
        }

        return String(localized: "menubar.ready")
    }

    private var menuBarSystemImage: String {
        if model.lastError != nil {
            return "exclamationmark.triangle.fill"
        }

        if !model.isMapperEnabled {
            return "pause.circle"
        }

        if !model.isAccessibilityTrusted {
            return "exclamationmark.shield"
        }

        return model.devices.isEmpty ? "gamecontroller" : "gamecontroller.fill"
    }
}

struct MenuBarContentView: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Label(menuBarTitle, systemImage: menuBarSystemImage)
        Divider()
        Button("app.openWindow") {
            NSApplication.shared.activate(ignoringOtherApps: true)
            if let mainWindow = NSApp.windows.first(where: { $0.canBecomeMain && $0.styleMask.contains(.titled) }) {
                mainWindow.makeKeyAndOrderFront(nil)
            } else {
                openWindow(id: "main")
            }
        }
        Divider()
        Toggle("app.mapperEnabled", isOn: $model.isMapperEnabled)
        Picker("profile.title", selection: $model.activeProfileID) {
            ForEach(model.profileOptions) { option in
                Text(profileDisplayName(option)).tag(option.id)
            }
        }
        .pickerStyle(.inline)
        Toggle("app.launchAtLogin", isOn: Binding(
            get: { model.isLaunchAtLoginEnabled },
            set: { model.setLaunchAtLoginEnabled($0) }
        ))
        Divider()
        Button("app.about") {
            NSApplication.shared.activate(ignoringOtherApps: true)
            model.isShowingAbout = true
        }
        Divider()
        Button("app.allowAccessibility") {
            model.requestAccessibilityPermission()
        }
        Button("app.reconnect") {
            model.reconnect()
        }
        Divider()
        Button("app.quit") {
            NSApplication.shared.terminate(nil)
        }
    }

    private func profileDisplayName(_ option: AppModel.ProfileOption) -> String {
        if let nameKey = option.nameKey {
            return String(localized: String.LocalizationValue(nameKey))
        }
        return option.name
    }

    private var menuBarTitle: String {
        if model.lastError != nil {
            return String(localized: "menubar.error")
        }

        if !model.isMapperEnabled {
            return String(localized: "menubar.paused")
        }

        if !model.isAccessibilityTrusted {
            return String(localized: "menubar.needsPermission")
        }

        if model.devices.isEmpty {
            return String(localized: "menubar.noJoycon")
        }

        return String(localized: "menubar.ready")
    }

    private var menuBarSystemImage: String {
        if model.lastError != nil {
            return "exclamationmark.triangle.fill"
        }

        if !model.isMapperEnabled {
            return "pause.circle"
        }

        if !model.isAccessibilityTrusted {
            return "exclamationmark.shield"
        }

        return model.devices.isEmpty ? "gamecontroller" : "gamecontroller.fill"
    }
}
