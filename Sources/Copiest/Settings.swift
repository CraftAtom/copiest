import AppKit
import Carbon
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var prefs: Preferences

    var body: some View {
        Form {
            Section {
                LabeledContent("Shortcut") {
                    VStack(alignment: .trailing, spacing: 4) {
                        ShortcutRecorder(shortcut: $prefs.pauseShortcut, isRecording: $prefs.isRecordingShortcut)
                        if prefs.pauseShortcutTaken {
                            Text("This shortcut is already in use. Record a different one.")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
                Picker("Resume recording", selection: $prefs.pauseEnd) {
                    ForEach(PauseEnd.allCases, id: \.self) { Text($0.title) }
                }
            } header: {
                Text("Pause recording")
            } footer: {
                Text("The shortcut pauses recording, and pressing it again resumes. While recording is paused, the menu bar icon is dimmed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Skip text that looks like a password or API key", isOn: $prefs.detectSecrets)
            } header: {
                Text("Secrets")
            } footer: {
                Text("Copiest skips access tokens, API keys, private keys, JSON Web Tokens, Authorization headers, passwords inside URLs, password and token settings in .env, JSON, and YAML files, and command-line flags such as --password. A secret in another format is still recorded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                ForEach(prefs.ignoredApps, id: \.self) { id in
                    IgnoredAppRow(bundleID: id) { prefs.ignoredApps.removeAll { $0 == id } }
                }
                Button("Add App…", action: addApp)
            } header: {
                Text("Ignored apps")
            } footer: {
                Text("Copiest doesn't record anything that you copy in these apps.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let id = Bundle(url: url)?.bundleIdentifier, !prefs.ignoredApps.contains(id) {
                prefs.ignoredApps.append(id)
            }
        }
    }
}

struct IgnoredAppRow: View {
    let bundleID: String
    let onRemove: () -> Void

    private var appURL: URL? { NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) }

    var body: some View {
        HStack(spacing: 8) {
            if let appURL {
                Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                    .resizable()
                    .frame(width: 18, height: 18)
                Text(FileManager.default.displayName(atPath: appURL.path).replacingOccurrences(of: ".app", with: ""))
            } else {
                Image(systemName: "app.dashed").frame(width: 18, height: 18)
                Text(bundleID).foregroundStyle(.secondary)
                    .help("This app isn't installed")
            }
            Spacer()
            Button(action: onRemove) { Image(systemName: "minus.circle") }
                .buttonStyle(.borderless)
                .help("Remove from ignored apps")
        }
    }
}

/// A button that records the next key combination that you press.
struct ShortcutRecorder: View {
    @Binding var shortcut: Shortcut?
    @Binding var isRecording: Bool
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            Button(monitor != nil ? "Type a Shortcut…" : shortcut?.label ?? "Record Shortcut") {
                monitor == nil ? start() : stop()
            }
            .help("Press a key with Command, Control, or Option. Press Escape to cancel.")
            if shortcut != nil, monitor == nil {
                Button { shortcut = nil } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Remove shortcut")
            }
        }
        .onDisappear(perform: stop)
        // The monitor catches every key press in Copiest, so stop as soon as the
        // Settings window closes or loses focus.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in stop() }
    }

    private func start() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if Int(event.keyCode) == kVK_Escape {
                stop()
            } else if let recorded = Shortcut(event: event) {
                shortcut = recorded
                stop()
            } else {
                NSSound.beep()
            }
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if isRecording { isRecording = false }
    }
}
