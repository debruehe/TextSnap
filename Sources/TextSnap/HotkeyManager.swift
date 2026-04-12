import Carbon
import Foundation

class HotkeyManager {
    private var hotKeyRefs: [Int: EventHotKeyRef] = [:]
    private var callbacks: [Int: () -> Void] = [:]
    private var eventHandler: EventHandlerRef?

    init() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let mgr = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            var hkID = EventHotKeyID()
            GetEventParameter(
                event, EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID), nil,
                MemoryLayout<EventHotKeyID>.size, nil, &hkID
            )
            if let cb = mgr.callbacks[Int(hkID.id)] {
                DispatchQueue.main.async { cb() }
            }
            return noErr
        }, 1, &spec, selfPtr, &eventHandler)
    }

    func registerHotkey(id: Int, keyCode: UInt32, carbonModifiers: UInt32, callback: @escaping () -> Void) {
        if let old = hotKeyRefs[id] { UnregisterEventHotKey(old) }
        var ref: EventHotKeyRef?
        let hkID = EventHotKeyID(signature: OSType(0x54534E50), id: UInt32(id)) // 'TSNP'
        if RegisterEventHotKey(keyCode, carbonModifiers, hkID, GetApplicationEventTarget(), 0, &ref) == noErr,
           let ref {
            hotKeyRefs[id] = ref
            callbacks[id] = callback
        }
    }

    func unregisterAll() {
        hotKeyRefs.values.forEach { UnregisterEventHotKey($0) }
        hotKeyRefs.removeAll()
        callbacks.removeAll()
    }
}
