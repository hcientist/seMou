import Carbon.HIToolbox

/// System-wide hotkeys via Carbon's RegisterEventHotKey (no Accessibility permission required).
final class HotKeys {
    static let shared = HotKeys()

    private static let signature: OSType = 0x534D_4F55 // 'SMOU'

    private var handlers: [UInt32: () -> Void] = [:]
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var nextID: UInt32 = 1

    private init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            guard status == noErr, hotKeyID.signature == HotKeys.signature else { return OSStatus(eventNotHandledErr) }
            DispatchQueue.main.async { HotKeys.shared.handlers[hotKeyID.id]?() }
            return noErr
        }, 1, &spec, nil, nil)
    }

    /// `modifiers` uses Carbon masks (cmdKey, optionKey, controlKey, shiftKey). Returns nil if the
    /// combination is already taken by another app.
    @discardableResult
    func register(keyCode: Int, modifiers: Int, handler: @escaping () -> Void) -> UInt32? {
        let id = nextID
        nextID += 1
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(keyCode), UInt32(modifiers), EventHotKeyID(signature: Self.signature, id: id),
            GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return nil }
        refs[id] = ref
        handlers[id] = handler
        return id
    }

    func unregister(_ id: UInt32) {
        if let ref = refs.removeValue(forKey: id) { UnregisterEventHotKey(ref) }
        handlers[id] = nil
    }
}

extension Direction {
    var keyCode: Int {
        switch self {
        case .left: return kVK_LeftArrow
        case .right: return kVK_RightArrow
        case .up: return kVK_UpArrow
        case .down: return kVK_DownArrow
        }
    }
}
