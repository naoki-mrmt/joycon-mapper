import SwiftUI
import AppKit
import Combine
import JoyconMapping

fileprivate typealias MappingKeyboardShortcut = JoyconMapping.KeyboardShortcut

struct ShortcutRecorderSheet: View {
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
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            modifierRecordTask?.cancel()
            recordedDisplay = nil
        }
    }
}

fileprivate struct ShortcutCaptureView: NSViewRepresentable {
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

fileprivate final class KeyCaptureView: NSView {
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

fileprivate extension MappingKeyboardShortcut {
    init?(event: NSEvent) {
        guard let key = ShortcutKeyName.key(for: event) else {
            return nil
        }

        self.init(key: key, modifiers: .init(event: event), keyCode: Int(event.keyCode))
    }
}

fileprivate extension MappingKeyboardShortcut.Modifiers {
    init(event: NSEvent) {
        self = []
        if event.modifierFlags.contains(.command) { insert(.command) }
        if event.modifierFlags.contains(.shift) { insert(.shift) }
        if event.modifierFlags.contains(.option) { insert(.option) }
        if event.modifierFlags.contains(.control) { insert(.control) }
    }
}

fileprivate enum ShortcutKeyName {
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
