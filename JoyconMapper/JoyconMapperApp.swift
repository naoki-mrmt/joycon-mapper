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
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .frame(minWidth: 820, minHeight: 560)
                .onAppear {
                    model.start()
                }
        }

        MenuBarExtra(menuBarTitle, systemImage: menuBarSystemImage) {
            Label(menuBarTitle, systemImage: menuBarSystemImage)
            Divider()
            Toggle("app.mapperEnabled", isOn: $model.isMapperEnabled)
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
                model.stop()
                model.start()
            }
            Divider()
            Button("app.quit") {
                NSApplication.shared.terminate(nil)
            }
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
