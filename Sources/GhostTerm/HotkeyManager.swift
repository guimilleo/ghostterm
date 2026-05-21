import AppKit
import Carbon

// Thin wrapper around Carbon RegisterEventHotKey for system-wide hotkeys.
// Works whether GhostTerm is focused or not. Doesn't need Accessibility permission.
final class HotkeyManager {
    typealias Handler = () -> Void

    private var handlers: [UInt32: Handler] = [:]
    private var refs: [EventHotKeyRef] = []
    private var nextID: UInt32 = 1
    private var eventHandler: EventHandlerRef?

    init() {
        installHandler()
    }

    deinit {
        for ref in refs { UnregisterEventHotKey(ref) }
        if let eh = eventHandler { RemoveEventHandler(eh) }
    }

    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping Handler) {
        let id = nextID
        nextID += 1
        let hotKeyID = EventHotKeyID(signature: 0x47545458 /* 'GTTX' */, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode, modifiers, hotKeyID,
            GetApplicationEventTarget(), 0, &ref
        )
        guard status == noErr, let ref else {
            NSLog("GhostTerm: RegisterEventHotKey failed: \(status)")
            return
        }
        refs.append(ref)
        handlers[id] = handler
    }

    private func installHandler() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let ctx = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let event, let userData else { return noErr }
                let mgr = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                var id = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &id
                )
                if let h = mgr.handlers[id.id] {
                    DispatchQueue.main.async { h() }
                }
                return noErr
            },
            1, &spec, ctx, &eventHandler
        )
    }
}

// Virtual key codes (from Carbon HIToolbox/Events.h). Pulled here to avoid the import noise.
enum VK {
    static let p: UInt32 = 35  // kVK_ANSI_P
}

// Modifier masks for RegisterEventHotKey (Carbon, not NSEvent).
enum CarbonMods {
    static let cmd: UInt32 = UInt32(cmdKey)
    static let shift: UInt32 = UInt32(shiftKey)
    static let opt: UInt32 = UInt32(optionKey)
    static let ctrl: UInt32 = UInt32(controlKey)
}
