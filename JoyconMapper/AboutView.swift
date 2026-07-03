import SwiftUI
import AppKit

struct AboutView: View {
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

enum AppInfo {
    static let repositoryURL = URL(string: "https://github.com/naoki-mrmt/joycon-mapper")!

    static var versionDisplay: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
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
