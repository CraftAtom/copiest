import AppKit
import Carbon
import Combine
import ServiceManagement
import SwiftUI

@main
enum Main {
    static func main() {
        // `Copiest --selftest` checks the secret filter and exits non-zero on failure.
        if CommandLine.arguments.contains("--selftest") {
            for text in SecretFilter.selftestSecrets where !SecretFilter.looksSecret(text) {
                print("FAIL missed secret: \(text)"); exit(1)
            }
            for text in SecretFilter.selftestKeep where SecretFilter.looksSecret(text) {
                print("FAIL skipped normal text: \(text)"); exit(1)
            }
            print("selftest ok")
            return
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

/// Registers the app as a login item through the modern Service Management API.
/// Fails cleanly on unsigned dev builds, where the toggle shows an alert instead.
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    @discardableResult
    static func set(_ enabled: Bool) -> Bool {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            return true
        } catch {
            return false
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let prefs = Preferences()
    private lazy var store = HistoryStore(prefs: prefs)
    private var statusItem: NSStatusItem!
    private var window: NSWindow?
    private var settingsWindow: NSWindow?
    private var hotKey: HotKey?
    private var pauseHotKey: HotKey?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = Self.menuBarIcon
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        // The sink gets the new values, because @Published publishes before it stores them.
        prefs.$pauseShortcut.combineLatest(prefs.$isRecordingShortcut).sink { [weak self] shortcut, recording in
            self?.registerHotKeys(pauseShortcut: shortcut, recording: recording)
        }.store(in: &cancellables)
        // A dimmed icon shows that recording is paused.
        store.$pause.sink { [weak self] pause in
            self?.statusItem.button?.appearsDisabled = pause != nil
            self?.statusItem.button?.toolTip = pause?.status ?? "Copiest"
        }.store(in: &cancellables)
        if CommandLine.arguments.contains("--show") { showWindow() }
        if CommandLine.arguments.contains("--settings") { showSettings() }
    }

    /// Registers the open and pause shortcuts. While Settings records a shortcut, both
    /// stay released, so the recorder sees every key combination.
    private func registerHotKeys(pauseShortcut: Shortcut?, recording: Bool) {
        hotKey = nil  // Release the old shortcuts before registering new ones.
        pauseHotKey = nil
        guard !recording else { return }
        hotKey = HotKey(keyCode: kVK_ANSI_V, modifiers: cmdKey | shiftKey) { [weak self] in self?.toggleWindow() }
        pauseHotKey = pauseShortcut.flatMap { HotKey($0) { [weak self] in self?.store.togglePause() } }
        prefs.pauseShortcutTaken = pauseShortcut != nil && pauseHotKey == nil
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.flush()
    }

    /// Template version of the logo: a clipboard with two lines of text.
    private static let menuBarIcon: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            NSColor.black.set()
            let board = NSBezierPath(roundedRect: NSRect(x: 3.25, y: 3.25, width: 11.5, height: 13), xRadius: 2, yRadius: 2)
            board.lineWidth = 1.5
            board.stroke()
            NSBezierPath(roundedRect: NSRect(x: 6, y: 1.5, width: 6, height: 3.5), xRadius: 1, yRadius: 1).fill()
            let lines = NSBezierPath()
            lines.lineWidth = 1.4
            lines.lineCapStyle = .round
            lines.move(to: NSPoint(x: 6, y: 9)); lines.line(to: NSPoint(x: 12, y: 9))
            lines.move(to: NSPoint(x: 6, y: 12.5)); lines.line(to: NSPoint(x: 10, y: 12.5))
            lines.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Copiest"
        return image
    }()

    /// Launching the app again (Spotlight, Raycast, Finder) opens the window,
    /// which helps when the menu bar icon is hidden behind the notch.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return false
    }

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            let open = menu.addItem(withTitle: "Open Copiest", action: #selector(showWindow), keyEquivalent: "")
            open.target = self
            if hotKey != nil {
                open.keyEquivalent = "v"
                open.keyEquivalentModifierMask = [.command, .shift]
            } else {
                menu.addItem(withTitle: "⌘⇧V is in use by another app", action: nil, keyEquivalent: "").isEnabled = false
            }
            menu.addItem(.separator())
            if let pause = store.pause {
                menu.addItem(withTitle: pause.status, action: nil, keyEquivalent: "").isEnabled = false
            }
            let pause = NSMenuItem(
                title: store.pause == nil ? "Pause Recording" : "Resume Recording",
                action: #selector(togglePause), keyEquivalent: "")
            pause.target = self
            // Show the shortcut beside the item when the menu can display it.
            if let shortcut = prefs.pauseShortcut, shortcut.key.count == 1,
               shortcut.key.unicodeScalars.allSatisfy(CharacterSet.alphanumerics.contains) {
                pause.keyEquivalent = shortcut.key.lowercased()
                pause.keyEquivalentModifierMask = NSEvent.ModifierFlags(carbon: shortcut.modifiers)
            }
            menu.addItem(pause)
            menu.addItem(withTitle: "Clear History…", action: #selector(confirmClear), keyEquivalent: "").target = self
            menu.addItem(.separator())
            menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",").target = self
            let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLoginItem), keyEquivalent: "")
            login.target = self
            login.state = LoginItem.isEnabled ? .on : .off
            menu.addItem(login)
            menu.addItem(.separator())
            menu.addItem(withTitle: "About Copiest", action: #selector(showAbout), keyEquivalent: "").target = self
            menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil  // Restore left-click behavior.
            return
        }
        toggleWindow()
    }

    @objc private func togglePause() {
        store.togglePause()
    }

    /// The standard About panel, with a short description and a link to CraftAtom.
    @objc private func showAbout() {
        let centered = NSMutableParagraphStyle()
        centered.alignment = .center
        let base: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: centered,
        ]
        let credits = NSMutableAttributedString(
            string: "Clipboard history for the menu bar that keeps passwords and API keys out.\n\nMade by ",
            attributes: base)
        var link = base
        link[.link] = URL(string: "https://craftatom.com")!
        credits.append(NSAttributedString(string: "CraftAtom", attributes: link))
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }

    @objc private func showSettings() {
        if settingsWindow == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
                styleMask: [.titled, .closable],
                backing: .buffered, defer: false)
            w.title = "Copiest Settings"
            w.isReleasedWhenClosed = false
            w.contentViewController = NSHostingController(rootView: SettingsView(prefs: prefs))
            w.center()
            settingsWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func toggleLoginItem() {
        let enable = !LoginItem.isEnabled
        guard !LoginItem.set(enable) else { return }
        let alert = NSAlert()
        alert.messageText = "Couldn't \(enable ? "enable" : "disable") Launch at Login"
        alert.informativeText = "Move Copiest to /Applications and try again."
        alert.runModal()
    }

    @objc private func confirmClear() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Clear clipboard history?"
        alert.informativeText = "Copiest removes every item except pinned ones. You can't undo this."
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true
        if alert.runModal() == .alertFirstButtonReturn { store.clearUnpinned() }
    }

    private func toggleWindow() {
        if let window, window.isVisible, window.isKeyWindow {
            hideWindow()
        } else {
            showWindow()
        }
    }

    /// Closes the picker. The app you were in is still active, ready for Command-V.
    private func hideWindow() {
        window?.orderOut(nil)
        // When Copiest itself is active, for example after you open it from Spotlight,
        // hand focus back, unless Settings is open.
        if NSApp.isActive, settingsWindow?.isVisible != true { NSApp.hide(nil) }
    }

    @objc private func showWindow() {
        if window == nil {
            // A non-activating panel takes key presses without activating Copiest. macOS
            // doesn't let an app take focus on demand, and the app you were in stays
            // active, so Command-V pastes there.
            let w = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 560),
                styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
                backing: .buffered, defer: false)
            w.title = "Copiest"
            w.isReleasedWhenClosed = false
            w.isFloatingPanel = true
            w.hidesOnDeactivate = false
            // Open on the current desktop, including over a full-screen app.
            w.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            w.delegate = self
            w.contentViewController = NSHostingController(rootView: ContentView(
                store: store,
                onPick: { [weak self] clip in
                    self?.store.copy(clip)
                    self?.hideWindow()
                },
                onClose: { [weak self] in self?.hideWindow() },
                onSettings: { [weak self] in self?.showSettings() }))
            w.setFrameAutosaveName("CopiestMain")
            if !w.setFrameUsingName("CopiestMain") { w.center() }
            window = w
        }
        window?.makeKeyAndOrderFront(nil)
        NotificationCenter.default.post(name: .pickerOpened, object: nil)
    }

    /// Behaves like a picker: clicking another app puts the window away.
    func windowDidResignKey(_ notification: Notification) {
        window?.orderOut(nil)
    }
}

extension Notification.Name {
    /// Posted each time the history window opens.
    static let pickerOpened = Notification.Name("CopiestPickerOpened")
}

extension NSEvent.ModifierFlags {
    init(carbon mask: Int) {
        self.init()
        if mask & cmdKey != 0 { insert(.command) }
        if mask & shiftKey != 0 { insert(.shift) }
        if mask & optionKey != 0 { insert(.option) }
        if mask & controlKey != 0 { insert(.control) }
    }
}

struct ContentView: View {
    @ObservedObject var store: HistoryStore
    let onPick: (Clip) -> Void
    let onClose: () -> Void
    let onSettings: () -> Void
    @State private var search = ""
    @State private var selection = Set<UUID>()
    /// The filtered list, computed once per change instead of on every render.
    @State private var rows: [Clip] = []
    @FocusState private var searchFocused: Bool

    /// Search looks at the start of each clip only, so typing stays fast with large clips.
    private static let searchPrefix = 10_000

    /// Pinned clips first, then the rest, newest first.
    private func filteredRows() -> [Clip] {
        let q = search.trimmingCharacters(in: .whitespaces)
        let filtered = q.isEmpty ? store.clips : store.clips.filter {
            $0.text.prefix(Self.searchPrefix).localizedCaseInsensitiveContains(q)
                || ($0.sourceApp?.localizedCaseInsensitiveContains(q) ?? false)
        }
        return filtered.filter(\.pinned) + filtered.filter { !$0.pinned }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            if rows.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .frame(minWidth: 360, minHeight: 300)
        .onExitCommand(perform: onClose)
        // Each time the window opens, start from a clean search with the newest clip selected.
        .onReceive(NotificationCenter.default.publisher(for: .pickerOpened)) { _ in
            search = ""
            rows = filteredRows()
            selectNewest()
            searchFocused = true
        }
        .onAppear { rows = filteredRows() }
        .onChange(of: search) {
            rows = filteredRows()
            selectNewest()
        }
        .onChange(of: store.clips) {
            rows = filteredRows()
            selection.formIntersection(rows.map(\.id))
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search clipboard history", text: $search)
                .textFieldStyle(.plain)
                .font(.title3)
                .focused($searchFocused)
                .onSubmit(pickSelected)
                .onKeyPress(.downArrow) { move(by: 1); return .handled }
                .onKeyPress(.upArrow) { move(by: -1); return .handled }
            Button(action: onSettings) { Image(systemName: "gearshape") }
                .buttonStyle(.borderless)
                .help("Settings")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        // Hidden buttons give Command-P and Command-Delete to the selected clip. Key
        // equivalents run before the search field, which would otherwise take Command-Delete.
        .background {
            Group {
                Button("Pin") { store.togglePin(selection) }.keyboardShortcut("p")
                Button("Delete", action: deleteSelected).keyboardShortcut(.delete)
            }
            .opacity(0)
            .allowsHitTesting(false)
            .disabled(selection.isEmpty)
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            List(rows, selection: $selection) { clip in
                ClipRow(clip: clip).tag(clip.id).id(clip.id)
            }
            .contextMenu(forSelectionType: UUID.self) { ids in
                contextMenu(for: ids)
            } primaryAction: { ids in
                // Double-click or Return copies the clip.
                if let clip = rows.first(where: { ids.contains($0.id) }) { onPick(clip) }
            }
            // Scoped to the list so Delete in the search field only edits text.
            .onDeleteCommand(perform: deleteSelected)
            .onChange(of: selection) {
                if let id = selection.first { proxy.scrollTo(id) }
            }
        }
    }

    private var emptyState: some View {
        Group {
            if search.isEmpty {
                ContentUnavailableView(
                    "Nothing Copied Yet",
                    systemImage: "clipboard",
                    description: Text("Text that you copy in any app appears here."))
            } else {
                ContentUnavailableView.search(text: search)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            if let pause = store.pause {
                Label(pause.status, systemImage: "pause.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                Button("Resume") { store.togglePause() }
                    .controlSize(.small)
            } else {
                Text(selection.count > 1 ? "\(selection.count) selected" : "↩ Copy · ⌘P Pin · ⌘⌫ Delete")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(store.clips.count == 1 ? "1 item" : "\(store.clips.count) items")
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    @ViewBuilder
    private func contextMenu(for ids: Set<UUID>) -> some View {
        let selected = store.clips.filter { ids.contains($0.id) }
        if !selected.isEmpty {
            if selected.count == 1, let clip = selected.first {
                Button("Copy") { onPick(clip) }
                Divider()
            }
            Button(selected.contains { !$0.pinned } ? "Pin" : "Unpin") { store.togglePin(ids) }
            Button(selected.count == 1 ? "Delete" : "Delete \(selected.count) Items", role: .destructive) {
                store.delete(ids)
            }
        }
    }

    private func pickSelected() {
        if let clip = rows.first(where: { selection.contains($0.id) }) ?? rows.first { onPick(clip) }
    }

    /// Selects the most recently copied clip, which can sit below the pinned ones.
    private func selectNewest() {
        selection = rows.max { $0.copiedAt < $1.copiedAt }.map { [$0.id] } ?? []
    }

    /// Deletes the selected clips and selects the row that took their place.
    private func deleteSelected() {
        guard let index = rows.firstIndex(where: { selection.contains($0.id) }) else { return }
        store.delete(selection)
        rows = filteredRows()
        selection = rows.isEmpty ? [] : [rows[min(index, rows.count - 1)].id]
    }

    /// Moves the selection with the arrow keys while focus stays in the search field.
    private func move(by offset: Int) {
        let ids = rows.map(\.id)
        guard !ids.isEmpty else { return }
        let current = ids.firstIndex { selection.contains($0) } ?? -1
        selection = [ids[min(max(current + offset, 0), ids.count - 1)]]
    }
}

struct ClipRow: View {
    let clip: Clip

    /// The first lines of the clip with surrounding whitespace removed. Long clips are
    /// cut short first, because a row shows two lines at most.
    private var preview: String {
        String(clip.text.prefix(600)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var details: String {
        let lines = clip.text.utf8.reduce(1) { $1 == UInt8(ascii: "\n") ? $0 + 1 : $0 }
        return [
            clip.sourceApp,
            clip.copiedAt.formatted(.relative(presentation: .named)),
            lines > 2 ? "\(lines) lines" : nil,
        ].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(preview)
                    .lineLimit(2)
                    .truncationMode(.tail)
                Text(details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if clip.pinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .help("Pinned clips stay at the top and never age out")
            }
        }
        .padding(.vertical, 3)
        .help(String(clip.text.prefix(2000)))
    }
}
