import Carbon

/// A system-wide keyboard shortcut. Carbon hot keys need no Accessibility permission.
final class HotKey {
    private static var nextID: UInt32 = 1
    private let id: UInt32
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: () -> Void

    /// Returns nil when another app already owns the shortcut.
    init?(keyCode: Int, modifiers: Int, action: @escaping () -> Void) {
        id = Self.nextID
        Self.nextID += 1
        self.action = action
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        // Every hot key's handler sees every press, so each one checks the ID.
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var pressed = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &pressed)
            let hotKey = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
            guard pressed.id == hotKey.id else { return OSStatus(eventNotHandledErr) }
            hotKey.action()
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard installed == noErr else { return nil }
        let hotKeyID = EventHotKeyID(signature: OSType(0x4350_5354), id: id)  // "CPST"
        guard RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hotKeyID, GetApplicationEventTarget(), 0, &ref) == noErr
        else { return nil }
    }

    convenience init?(_ shortcut: Shortcut, action: @escaping () -> Void) {
        self.init(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers, action: action)
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
        if let handler { RemoveEventHandler(handler) }
    }
}
