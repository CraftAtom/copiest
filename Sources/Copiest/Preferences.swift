import AppKit
import Carbon

/// A key combination for a global shortcut, in the form Carbon hot keys expect.
struct Shortcut: Codable, Equatable {
    let keyCode: Int
    /// Carbon modifier mask, such as `cmdKey | shiftKey`.
    let modifiers: Int
    /// The key's name, such as "P" or "Space".
    let key: String

    var label: String {
        (modifiers & controlKey != 0 ? "⌃" : "") + (modifiers & optionKey != 0 ? "⌥" : "")
            + (modifiers & shiftKey != 0 ? "⇧" : "") + (modifiers & cmdKey != 0 ? "⌘" : "") + key
    }

    /// Returns nil unless the event has Command, Control, or Option, because a global
    /// shortcut without one would swallow ordinary typing.
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !flags.isDisjoint(with: [.command, .control, .option]) else { return nil }
        var mask = 0
        if flags.contains(.command) { mask |= cmdKey }
        if flags.contains(.shift) { mask |= shiftKey }
        if flags.contains(.option) { mask |= optionKey }
        if flags.contains(.control) { mask |= controlKey }
        keyCode = Int(event.keyCode)
        modifiers = mask
        key = Self.keyNames[keyCode] ?? event.characters(byApplyingModifiers: [])?.uppercased() ?? "?"
    }

    private static let keyNames: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]
}

/// When a pause in recording ends on its own.
enum PauseEnd: String, CaseIterable {
    case nextCopy, oneMinute, fiveMinutes, fifteenMinutes, untilResumed

    var title: String {
        switch self {
        case .nextCopy: "After the Next Copy"
        case .oneMinute: "After 1 Minute"
        case .fiveMinutes: "After 5 Minutes"
        case .fifteenMinutes: "After 15 Minutes"
        case .untilResumed: "When I Resume"
        }
    }

    var pause: Pause {
        switch self {
        case .nextCopy: .nextCopy
        case .oneMinute: .until(Date().addingTimeInterval(60))
        case .fiveMinutes: .until(Date().addingTimeInterval(5 * 60))
        case .fifteenMinutes: .until(Date().addingTimeInterval(15 * 60))
        case .untilResumed: .untilResumed
        }
    }
}

/// A pause in recording that is in effect.
enum Pause: Equatable {
    case nextCopy, until(Date), untilResumed

    var status: String {
        switch self {
        case .nextCopy: "Paused for the next copy"
        case .until(let end): "Paused until \(end.formatted(date: .omitted, time: .shortened))"
        case .untilResumed: "Recording paused"
        }
    }
}

final class Preferences: ObservableObject {
    /// Password managers and other apps whose copies Copiest never records.
    static let defaultIgnoredApps = [
        "com.apple.keychainaccess",
        "com.apple.Passwords",
        "com.1password.1password",
        "com.agilebits.onepassword7",
        "com.bitwarden.desktop",
        "org.keepassxc.keepassxc",
        "com.lastpass.LastPass",
    ]

    private static let defaults = UserDefaults.standard

    @Published var pauseShortcut: Shortcut? = defaults.data(forKey: "pauseShortcut")
        .flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) } {
        didSet { Self.defaults.set(pauseShortcut.flatMap { try? JSONEncoder().encode($0) }, forKey: "pauseShortcut") }
    }
    @Published var pauseEnd = PauseEnd(rawValue: defaults.string(forKey: "pauseEnd") ?? "") ?? .untilResumed {
        didSet { Self.defaults.set(pauseEnd.rawValue, forKey: "pauseEnd") }
    }
    @Published var ignoredApps = defaults.stringArray(forKey: "ignoredApps") ?? defaultIgnoredApps {
        didSet { Self.defaults.set(ignoredApps, forKey: "ignoredApps") }
    }
    @Published var detectSecrets = defaults.object(forKey: "detectSecrets") as? Bool ?? true {
        didSet { Self.defaults.set(detectSecrets, forKey: "detectSecrets") }
    }
    /// True when the pause shortcut is already in use. Not saved.
    @Published var pauseShortcutTaken = false
    /// True while Settings records a shortcut. Copiest releases its own shortcuts
    /// meanwhile, so you can record any combination. Not saved.
    @Published var isRecordingShortcut = false
}
